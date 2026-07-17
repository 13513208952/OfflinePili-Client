// === OFFLINE-NOSTALGIA-MODE BEGIN ===
import 'package:PiliPlus/utils/storage_pref.dart';

// 单机怀旧模式的配置小门面，包一层 Pref，避免各处散落拼 baseUrl 的逻辑。
abstract final class OfflineConfig {
  static bool get enabled => Pref.offlineModeEnabled;

  static String get baseUrl =>
      'http://${Pref.offlineServerHost}:${Pref.offlineServerPort}';

  static Uri apiUri(String path, [Map<String, dynamic>? queryParameters]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }
}
// === OFFLINE-NOSTALGIA-MODE END ===
