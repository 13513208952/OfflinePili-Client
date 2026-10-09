import 'dart:io';

import 'package:PiliPlus/pages/offline_server/view.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory directory;

  setUpAll(() async {
    directory = Directory.systemTemp.createTempSync('nostalgia_dropdown_test_');
    appSupportDirPath = directory.path;
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
    await GStorage.setting.put(SettingBoxKey.nostalgiaMode, 1);
  });

  tearDownAll(() async {
    await Hive.close();
    directory.deleteSync(recursive: true);
  });

  testWidgets('mode popup opens and switches without saving preferences', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(450, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        locale: Locale('zh', 'CN'),
        supportedLocales: [Locale('zh', 'CN')],
        home: OfflineServerSettingPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('在线怀旧').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('离线归档（OfflinePili 服务端）').last, findsOneWidget);
    await tester.tap(find.text('离线归档（OfflinePili 服务端）').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('主地址(内网IP或公网IP/域名)'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>).first)
          .value,
      2,
    );

    await tester.ensureVisible(find.text('禁用').first);
    await tester.tap(find.text('禁用').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('启用(优先USB，插线即连)').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>).last)
          .value,
      1,
    );

    await tester.ensureVisible(find.byType(DropdownButton<int>).first);
    await tester.tap(find.byType(DropdownButton<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭（PiliPlus 原版）').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .value,
      0,
    );

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('在线怀旧（自定义推荐，B站资源与互动）').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('在线怀旧视频库'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .value,
      1,
    );
    expect(GStorage.setting.get(SettingBoxKey.nostalgiaMode), 1);
    expect(GStorage.setting.get(SettingBoxKey.offlineUsbLinkMode), isNull);
  });
}
