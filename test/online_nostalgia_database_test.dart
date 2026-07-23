import 'dart:io';

import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/nostalgia/online_nostalgia_database.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory testDirectory;

  setUpAll(() {
    testDirectory = Directory.systemTemp.createTempSync(
      'online_nostalgia_test_',
    );
    appSupportDirPath = testDirectory.path;
  });

  setUp(() {
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('${OnlineNostalgiaDatabase.path}$suffix');
      if (file.existsSync()) file.deleteSync();
    }
  });

  tearDownAll(() {
    testDirectory.deleteSync(recursive: true);
  });

  test('AV/BV normalize to the same aid', () {
    const aid = 170001;
    final bvid = IdUtils.av2bv(aid);
    expect(OnlineNostalgiaDatabase.normalize('av$aid')?.aid, aid);
    expect(OnlineNostalgiaDatabase.normalize(bvid)?.aid, aid);
    expect(OnlineNostalgiaDatabase.normalize('not-an-id'), isNull);
  });

  test('import is transactional and deduplicates AV/BV aliases', () async {
    const aid = 170001;
    final bvid = IdUtils.av2bv(aid);
    final result = await OnlineNostalgiaDatabase.importText(
      'av$aid\n$bvid\nav2\ninvalid\n',
      sourceName: 'test',
    );

    expect(result.total, 4);
    expect(result.added, 2);
    expect(result.duplicate, 1);
    expect(result.invalid, 1);

    final stats = await OnlineNostalgiaDatabase.stats();
    expect(stats.total, 2);
    expect(stats.unknown, 2);
  });

  test('cold pool uses 75% exploration and cooled 5% recycling', () async {
    final source = [
      for (var aid = 1000; aid < 1100; aid++) 'av$aid',
    ].join('\n');
    await OnlineNostalgiaDatabase.importText(source, sourceName: 'ratio-test');

    for (var aid = 1000; aid < 1020; aid++) {
      await OnlineNostalgiaDatabase.saveAvailable({
        'aid': aid,
        'bvid': IdUtils.av2bv(aid),
        'title': 'test',
        'cover': null,
        'duration': 1,
        'pubdate': 0,
        'cid': aid,
        'owner_mid': 1,
        'owner_name': 'test',
        'owner_face': null,
        'tid': 1,
        'tname': 'test',
        'tags': '',
        'view_count': 1,
        'like_count': 0,
        'danmaku_count': 0,
        'redirect_url': null,
      });
    }
    for (var aid = 1020; aid < 1030; aid++) {
      await OnlineNostalgiaDatabase.saveFailure(
        aid,
        reason: 'test',
        permanent: true,
      );
    }

    var selected = await OnlineNostalgiaDatabase.selectForValidation(
      count: 20,
      excluded: const {},
      sessionId: 1,
    );
    expect(selected.where((aid) => aid >= 1030), hasLength(16));
    expect(selected.where((aid) => aid >= 1000 && aid < 1020), hasLength(4));
    expect(selected.where((aid) => aid >= 1020 && aid < 1030), isEmpty);

    sqlite3.open(OnlineNostalgiaDatabase.path)
      ..execute(
        'UPDATE nostalgia_videos SET retry_at=0 '
        'WHERE aid >= 1020 AND aid < 1030',
      )
      ..close();
    selected = await OnlineNostalgiaDatabase.selectForValidation(
      count: 20,
      excluded: const {},
      sessionId: 2,
    );
    expect(selected.where((aid) => aid >= 1030), hasLength(15));
    expect(selected.where((aid) => aid >= 1000 && aid < 1020), hasLength(4));
    expect(selected.where((aid) => aid >= 1020 && aid < 1030), hasLength(1));
  });

  test('concurrent validation writes are serialized', () async {
    await OnlineNostalgiaDatabase.importText(
      [for (var aid = 2000; aid < 2030; aid++) 'av$aid'].join('\n'),
      sourceName: 'concurrency-test',
    );

    await Future.wait([
      for (var aid = 2000; aid < 2030; aid++)
        OnlineNostalgiaDatabase.saveFailure(
          aid,
          reason: 'concurrent-test',
          permanent: false,
        ),
    ]);

    final stats = await OnlineNostalgiaDatabase.stats();
    expect(stats.unavailable, 30);
  });

  test('bundled allowlist imports without invalid or duplicate IDs', () async {
    final text = await File('av_list.txt').readAsString();
    final result = await OnlineNostalgiaDatabase.importText(
      text,
      sourceName: 'bundled-test',
    );
    expect(result.added, 19163);
    expect(result.duplicate, 0);
    expect(result.invalid, 0);
    expect((await OnlineNostalgiaDatabase.stats()).total, 19163);
  });
}
