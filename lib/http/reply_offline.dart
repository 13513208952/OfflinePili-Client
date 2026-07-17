// === OFFLINE-NOSTALGIA-MODE BEGIN ===
// 单机怀旧模式：评论走自建服务端，服务端已经把 BiliDanmuComment_cs 归档的
// comments.7z 重整形成 ReplyData/ReplyItemModel 期望的JSON形状了，这里直接
// fromJson 解析，不用再写一套新的评论模型/渲染逻辑。
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/reply/data.dart';
import 'package:PiliPlus/models_new/reply2reply/data.dart';
import 'package:PiliPlus/utils/offline/offline_config.dart';

abstract final class OfflineReplyHttp {
  static Future<LoadingState<ReplyData>> replyList({
    required int oid,
  }) async {
    try {
      final res = await Request().get(
        OfflineConfig.apiUri('/api/v1/replies/$oid').toString(),
      );
      if (res.data is Map) {
        return Success(ReplyData.fromJson(res.data as Map<String, dynamic>));
      }
      return const Error('单机怀旧模式：服务端返回格式异常');
    } catch (e) {
      return Error('单机怀旧模式评论获取失败: $e');
    }
  }

  // 楼中楼"查看全部回复"页：归档评论的楼中楼在服务端返回的JSON里本来就是
  // 全量内嵌的(replies字段)，这里重新拉一次整页、按rpid找到根评论、在JSON层
  // 组装成 ReplyReplyData 期望的形状(root就是一条评论对象，字段同构)。
  // 归档是一次性快照，没有真分页——第一页给全量，后续页给空表示到底。
  static Future<LoadingState<ReplyReplyData>> replyReplyList({
    required int oid,
    required int root,
    required int pageNum,
  }) async {
    if (pageNum > 1) {
      return Success(ReplyReplyData(replies: []));
    }
    try {
      final res = await Request().get(
        OfflineConfig.apiUri('/api/v1/replies/$oid').toString(),
      );
      if (res.data is! Map) {
        return const Error('单机怀旧模式：服务端返回格式异常');
      }
      final replies = (res.data as Map)['replies'];
      if (replies is List) {
        for (final r in replies) {
          if (r is Map && r['rpid'] == root) {
            final subReplies = r['replies'] is List ? r['replies'] as List : const [];
            return Success(
              ReplyReplyData.fromJson({
                'page': {
                  'num': 1,
                  'size': subReplies.length,
                  'count': subReplies.length,
                },
                'replies': subReplies,
                'root': r,
              }),
            );
          }
        }
      }
      return const Error('单机怀旧模式：归档里找不到这条评论');
    } catch (e) {
      return Error('单机怀旧模式评论获取失败: $e');
    }
  }
}
// === OFFLINE-NOSTALGIA-MODE END ===
