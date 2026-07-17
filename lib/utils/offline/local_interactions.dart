// === OFFLINE-NOSTALGIA-MODE BEGIN ===
// 单机怀旧模式本地互动记录：点赞/投币/收藏/关注/不感兴趣/观看历史/本地弹幕/本地评论，
// 仿照 Pref.blackMids 的 "Set/Map 存 GStorage.localCache + 每次直接读写 Hive" 模式，
// 不新开 Hive box，复用现成的 localCache。这些数据也是本地推荐引擎
// (recommend_engine.dart) 的画像输入，永不上传。
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

abstract final class OfflineLocalInteractions {
  static Set<String> get likedBvids => (GStorage.localCache.get(
    LocalCacheKey.offlineLikedBvids,
    defaultValue: <String>{},
  )).cast<String>();

  static bool isLiked(String bvid) => likedBvids.contains(bvid);

  static void toggleLike(String bvid) {
    final set = likedBvids;
    if (!set.add(bvid)) set.remove(bvid);
    GStorage.localCache.put(LocalCacheKey.offlineLikedBvids, set);
  }

  static Map<String, List<Map<String, dynamic>>> get _danmakuByCid =>
      (GStorage.localCache.get(
        LocalCacheKey.offlineLocalDanmaku,
        defaultValue: <String, List<Map<String, dynamic>>>{},
      )).cast<String, List<Map<String, dynamic>>>();

  static List<Map<String, dynamic>> localDanmakuFor(int cid) =>
      _danmakuByCid[cid.toString()] ?? const [];

  static void addLocalDanmaku({
    required int cid,
    required String content,
    required int progressMs,
    int mode = 1,
    int color = 16777215,
  }) {
    final all = _danmakuByCid;
    final list = List<Map<String, dynamic>>.from(
      all[cid.toString()] ?? const [],
    );
    list.add({
      'content': content,
      'progress': progressMs,
      'mode': mode,
      'color': color,
      'sentAt': DateTime.now().millisecondsSinceEpoch,
    });
    all[cid.toString()] = list;
    GStorage.localCache.put(LocalCacheKey.offlineLocalDanmaku, all);
  }

  // ---- 投币/收藏：Set<bvid>，和点赞同一个模式 ----

  static Set<String> _bvidSet(String key) =>
      (GStorage.localCache.get(key, defaultValue: <String>{})).cast<String>();

  static Set<String> get coinedBvids =>
      _bvidSet(LocalCacheKey.offlineCoinedBvids);

  static Set<String> get favoritedBvids =>
      _bvidSet(LocalCacheKey.offlineFavoritedBvids);

  static bool isCoined(String bvid) => coinedBvids.contains(bvid);

  static void setCoined(String bvid) {
    final set = coinedBvids..add(bvid);
    GStorage.localCache.put(LocalCacheKey.offlineCoinedBvids, set);
  }

  static bool isFavorited(String bvid) => favoritedBvids.contains(bvid);

  static bool toggleFavorite(String bvid) {
    final set = favoritedBvids;
    final nowFav = set.add(bvid);
    if (!nowFav) set.remove(bvid);
    GStorage.localCache.put(LocalCacheKey.offlineFavoritedBvids, set);
    return nowFav;
  }

  // ---- 关注UP主：Set<mid>。推荐引擎里"关注"不进画像向量，
  //      单独作为强信号定期强制留名额，见 recommend_engine.dart ----

  static Set<int> get followedMids => (GStorage.localCache.get(
    LocalCacheKey.offlineFollowedMids,
    defaultValue: <int>{},
  )).cast<int>();

  static bool isFollowed(int mid) => followedMids.contains(mid);

  static bool toggleFollow(int mid) {
    final set = followedMids;
    final nowFollowed = set.add(mid);
    if (!nowFollowed) set.remove(mid);
    GStorage.localCache.put(LocalCacheKey.offlineFollowedMids, set);
    return nowFollowed;
  }

  // ---- 视频级"不感兴趣"：硬性永久排除出推荐候选，除非手动移除。
  //      Map<bvid, {reason, at}>，reason 用于"已排除列表"里回显 ----

  static Map<String, Map<String, dynamic>> get dislikedVideos =>
      (GStorage.localCache.get(
        LocalCacheKey.offlineDislikedVideos,
        defaultValue: <String, Map<String, dynamic>>{},
      )).cast<String, Map<String, dynamic>>();

  static bool isDisliked(String bvid) => dislikedVideos.containsKey(bvid);

  static void addDislike({required String bvid, required String reason}) {
    final all = dislikedVideos;
    all[bvid] = {
      'reason': reason,
      'at': DateTime.now().millisecondsSinceEpoch,
    };
    GStorage.localCache.put(LocalCacheKey.offlineDislikedVideos, all);
  }

  static void removeDislike(String bvid) {
    final all = dislikedVideos..remove(bvid);
    GStorage.localCache.put(LocalCacheKey.offlineDislikedVideos, all);
  }

  // ---- 观看历史日志：watchProgress 只按 cid 覆盖存"最后位置"，
  //      这里补一份带时间戳的追加日志，供画像的弱隐性信号用
  //      (完成度超过阈值才算兴趣，见 recommend_engine.dart) ----

  static const int _watchHistoryCap = 2000;

  static List<Map<String, dynamic>> get watchHistory =>
      List<Map<String, dynamic>>.from(
        (GStorage.localCache.get(
          LocalCacheKey.offlineWatchHistory,
          defaultValue: const <Map<String, dynamic>>[],
        )).cast<Map<String, dynamic>>(),
      );

  static void recordWatch({
    required String bvid,
    required int cid,
    required int progressMs,
    required int durationMs,
  }) {
    final list = watchHistory;
    // 同一次观看(同bvid+cid的最后一条)只更新进度，不重复追加，
    // 隔了新条目再看才算一次新观看。
    if (list.isNotEmpty &&
        list.last['bvid'] == bvid &&
        list.last['cid'] == cid) {
      list.last['progressMs'] = progressMs;
      list.last['durationMs'] = durationMs;
    } else {
      list.add({
        'bvid': bvid,
        'cid': cid,
        'at': DateTime.now().millisecondsSinceEpoch,
        'progressMs': progressMs,
        'durationMs': durationMs,
      });
      if (list.length > _watchHistoryCap) {
        list.removeRange(0, list.length - _watchHistoryCap);
      }
    }
    GStorage.localCache.put(LocalCacheKey.offlineWatchHistory, list);
  }

  static Map<String, List<Map<String, dynamic>>> get _repliesByAid =>
      (GStorage.localCache.get(
        LocalCacheKey.offlineLocalReplies,
        defaultValue: <String, List<Map<String, dynamic>>>{},
      )).cast<String, List<Map<String, dynamic>>>();

  static List<Map<String, dynamic>> localRepliesFor(int aid) =>
      _repliesByAid[aid.toString()] ?? const [];

  static void addLocalReply({required int aid, required String message}) {
    final all = _repliesByAid;
    final list = List<Map<String, dynamic>>.from(
      all[aid.toString()] ?? const [],
    );
    list.add({
      'message': message,
      'sentAt': DateTime.now().millisecondsSinceEpoch,
    });
    all[aid.toString()] = list;
    GStorage.localCache.put(LocalCacheKey.offlineLocalReplies, all);
  }
}
// === OFFLINE-NOSTALGIA-MODE END ===
