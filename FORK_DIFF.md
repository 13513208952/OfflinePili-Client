# FORK_DIFF — 单机怀旧模式 (OFFLINE-NOSTALGIA-MODE)

本 fork 相对上游 PiliPlus 的全部改动清单。所有对上游既有文件的修改都用
`// === OFFLINE-NOSTALGIA-MODE BEGIN/END ===` 注释包裹，rebase 上游后可用
`grep -r "OFFLINE-NOSTALGIA-MODE" lib/` 找回全部触点并逐一 review。

设计原则：怀旧模式开启时，视频/弹幕/评论/元数据全部来自自建局域网服务端；
点赞/投币/收藏/关注/弹幕/评论/不感兴趣等互动只写本地 Hive，永不上传；
观看行为不向B站/第三方发出任何请求。

## 新增文件（整文件都是 fork 内容，与上游无冲突）

| 文件 | 用途 |
|---|---|
| `lib/utils/offline/offline_config.dart` | 模式开关/服务端地址的 Pref 门面 |
| `lib/utils/offline/local_interactions.dart` | 本地互动存储：点赞/投币/收藏/关注/不感兴趣/观看历史/本地弹幕/本地评论 |
| `lib/utils/offline/recommend_engine.dart` | 本地推荐引擎：Rocchio(1971)+IMDB贝叶斯质量先验+MMR(1998)+关注UP强制名额 |
| `lib/http/video_offline.dart` | playurl 走自建服务端 |
| `lib/http/danmaku_offline.dart` | 弹幕 protobuf 走自建服务端 |
| `lib/http/reply_offline.dart` | 评论列表+楼中楼 走自建服务端 |
| `lib/http/metadata_offline.dart` | 视频详情元数据 走自建服务端 |
| `lib/http/catalog_offline.dart` | 全量目录分页拉取+内存TTL缓存(推荐引擎的候选集) |
| `lib/models/offline/offline_video_item.dart` | 目录项模型，继承 BaseRcmdVideoItemModel 复用推荐卡片UI |
| `lib/pages/offline_server/view.dart` | 怀旧模式设置页(开关/host/port/测试连接) |
| `lib/pages/offline_rcmd/controller.dart` | "怀旧推荐"信息流控制器(继承 CommonListController) |
| `lib/pages/offline_rcmd/view.dart` | "怀旧推荐"页面(克隆 rcmd/view.dart 网格布局) |

## 修改的上游文件（均为"顶部加模式分支"式小改动）

| 文件 | 改动原因 |
|---|---|
| `lib/utils/storage_key.dart` | 新增怀旧模式的 Setting/LocalCache key 常量 |
| `lib/utils/storage_pref.dart` | 新增怀旧模式 Pref 存取器；enableAi/enableOnlineTotal 在怀旧模式下强制关(云端能力闸门) |
| `lib/models/common/setting_type.dart` | 设置页新增"单机怀旧模式"入口枚举 |
| `lib/pages/setting/view.dart` | 设置页路由到 OfflineServerSettingPage |
| `lib/models/common/home_tab_type.dart` | 新增 offlineRcmd("怀旧推荐")tab 枚举(追加在末尾防 tabBarSort 下标错位) |
| `lib/pages/home/controller.dart` | 怀旧模式下"怀旧推荐"tab 强制置顶+默认落点；关闭时剔除该tab |
| `lib/http/video.dart` | videoUrl/videoIntro/replyAdd/relatedVideoList 怀旧分支(前三个转发到 offline http，相关视频留空) |
| `lib/http/danmaku.dart` | shootDanmaku 怀旧分支：发弹幕只写本地 |
| `lib/grpc/dm.dart` | dmSegMobile 怀旧分支：弹幕从服务端取 |
| `lib/http/reply.dart` | replyList/replyReplyList 怀旧分支转发；likeReply/hateReply 不发B站直接返回成功(UI乐观更新) |
| `lib/common/widgets/video_popup_menu.dart` | "不感兴趣"怀旧分支(原因弹窗UI照抄、提交写本地硬排除)；"拉黑"写本地blackMids；隐藏"稍后再看" |
| `lib/pages/common/common_intro_controller.dart` | 投币(onPayCoin)/收藏(showFavBottomSheet)怀旧分支写本地；videoTags 不查B站 |
| `lib/pages/video/introduction/ugc/controller.dart` | 点赞/三连/关注状态查询与操作的怀旧分支(全本地)；UP主粉丝数不查B站 |
| `lib/pages/video/introduction/ugc/widgets/triple_mixin.dart` | 投币入口跳过登录/硬币余额检查(怀旧模式无真实账号) |
| `lib/pages/video/controller.dart` | 播放器初始化跳过 playInfo字幕/弹幕趋势/SponsorBlock(云端+第三方泄露)；投屏提示不支持 |
| `lib/plugin/pl_player/controller.dart` | makeHeartBeat 怀旧分支：进度心跳绝不发B站，改写本地观看历史(推荐画像弱信号) |

## 服务端对接

自建服务端(仓库 `server/` 目录，.NET)只有 GET 资源路由，无任何写入路由。
默认端口 5299(客户端设置页默认值)。接口形状按 PiliPlus 现有解析代码原样对齐，
弹幕用与上游同一份 proto 定义的 protobuf 透传，客户端解析层零改动。
