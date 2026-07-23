import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/online_nostalgia.dart';
import 'package:PiliPlus/models/online_nostalgia/online_nostalgia_video.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/nostalgia/online_nostalgia_database.dart';
import 'package:PiliPlus/utils/nostalgia/online_nostalgia_ranker.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

class OnlineNostalgiaController
    extends
        CommonListController<
          List<OnlineNostalgiaVideo>?,
          OnlineNostalgiaVideo
        > {
  static const pageSize = 20;
  static const _mainTarget = 20;
  static const _reserveTarget = 40;
  static const _validationConcurrency = 3;

  final _main = <OnlineNostalgiaVideo>[];
  final _reserve = <OnlineNostalgiaVideo>[];
  final _sessionSeen = <int>{};
  final _sessionId = DateTime.now().microsecondsSinceEpoch;
  final _inFlight = <int>{};
  Future<void>? _refillFuture;

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  Future<LoadingState<List<OnlineNostalgiaVideo>?>> customGetData() async {
    try {
      await _ensureBundledList();
      await _ensureMain(pageSize);
      if (_main.isEmpty) {
        return const Error('暂时没有验证成功的怀旧视频，请检查网络后重试');
      }
      final take = _main.length < pageSize ? _main.length : pageSize;
      final pageItems = _main.sublist(0, take);
      _main.removeRange(0, take);
      _sessionSeen.addAll(pageItems.map((e) => e.aid!));
      await OnlineNostalgiaDatabase.markRecommended(
        pageItems.map((e) => e.aid!),
        sessionId: _sessionId,
      );
      unawaited(_refill());
      return Success(pageItems);
    } catch (e) {
      return Error('在线怀旧推荐加载失败: $e');
    }
  }

  Future<void> _ensureBundledList() async {
    const sourceName = '内置av_list.txt';
    final text = await rootBundle.loadString('av_list.txt');
    final hash = sha256.convert(utf8.encode(text)).toString();
    if (await OnlineNostalgiaDatabase.hasImportedHash(sourceName, hash)) {
      return;
    }
    await OnlineNostalgiaDatabase.importText(
      text,
      sourceName: sourceName,
      contentHash: hash,
    );
  }

  Future<void> _ensureMain(int minimum) async {
    if (_main.length >= minimum) return;
    await _refill();
    _moveReserveToMain();
  }

  Future<void> _refill() {
    return _refillFuture ??= _doRefill().whenComplete(() {
      _refillFuture = null;
    });
  }

  Future<void> _doRefill() async {
    if (_reserve.length >= _reserveTarget && _main.length >= _mainTarget) {
      return;
    }
    final excluded = {
      ..._inFlight,
      ..._main.map((e) => e.aid!),
      ..._reserve.map((e) => e.aid!),
    };
    // 冷启动先验证一小批，尽快显示首屏；首屏返回后再后台填满备用队列。
    final coldStart = _main.isEmpty && _reserve.isEmpty;
    final need =
        (coldStart
                ? _mainTarget
                : _mainTarget + _reserveTarget - _main.length - _reserve.length)
            .clamp(20, 120)
            .toInt();
    final ids = await OnlineNostalgiaDatabase.selectForValidation(
      count: need,
      excluded: excluded,
      sessionId: _sessionId,
    );
    if (ids.isEmpty) return;

    final cached = await OnlineNostalgiaDatabase.loadVideos(ids);
    final cachedByAid = {for (final item in cached) item.aid!: item};
    // 每次进入主/备用队列前都确认playurl。复用项沿用已缓存元数据，
    // 未知与不可用回收项才重新获取完整元数据和标签。
    for (var i = 0; i < ids.length; i += _validationConcurrency) {
      final end = (i + _validationConcurrency).clamp(0, ids.length).toInt();
      final batch = ids.sublist(i, end);
      _inFlight.addAll(batch);
      await Future.wait(
        batch.map(
          (aid) => OnlineNostalgiaHttp.validate(
            aid,
            cached: cachedByAid[aid],
          ),
        ),
      );
      _inFlight.removeAll(batch);
      if (end < ids.length) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    final validated = await OnlineNostalgiaDatabase.loadVideos(ids);
    final profile = await OnlineNostalgiaDatabase.preferenceProfile();
    final ranked = OnlineNostalgiaRanker.rank(
      validated,
      profile,
    ).where((e) => !excluded.contains(e.aid)).toList();
    _reserve.addAll(ranked);
    _moveReserveToMain();
  }

  void _moveReserveToMain() {
    final count = (_mainTarget - _main.length)
        .clamp(0, _reserve.length)
        .toInt();
    if (count == 0) return;
    _main.addAll(_reserve.take(count));
    _reserve.removeRange(0, count);
  }

  @override
  Future<void> onRefresh() {
    _main.clear();
    _reserve.clear();
    return super.onRefresh();
  }
}
