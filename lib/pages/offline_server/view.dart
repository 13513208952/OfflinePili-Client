// === OFFLINE-NOSTALGIA-MODE BEGIN ===
// 单机怀旧模式配置页，照抄 lib/pages/webdav/view.dart 的结构。
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:dio/dio.dart' show Options;
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class OfflineServerSettingPage extends StatefulWidget {
  const OfflineServerSettingPage({
    super.key,
    this.showAppBar = true,
  });

  final bool showAppBar;

  @override
  State<OfflineServerSettingPage> createState() =>
      _OfflineServerSettingPageState();
}

class _OfflineServerSettingPageState extends State<OfflineServerSettingPage> {
  final _hostCtr = TextEditingController(text: Pref.offlineServerHost);
  final _portCtr =
      TextEditingController(text: Pref.offlineServerPort.toString());
  late bool _enabled = Pref.offlineModeEnabled;
  bool _testing = false;

  @override
  void dispose() {
    _hostCtr.dispose();
    _portCtr.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final port = int.tryParse(_portCtr.text) ?? Pref.offlineServerPort;
    await GStorage.setting.putAll({
      SettingBoxKey.offlineModeEnabled: _enabled,
      SettingBoxKey.offlineServerHost: _hostCtr.text.trim(),
      SettingBoxKey.offlineServerPort: port,
    });
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    try {
      final host = _hostCtr.text.trim();
      final port = int.tryParse(_portCtr.text) ?? Pref.offlineServerPort;
      final res = await Request().get(
        'http://$host:$port/health',
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      if (res.data is Map && res.data['status'] == 'ok') {
        SmartDialog.showToast('连接成功');
      } else {
        SmartDialog.showToast('服务端响应异常');
      }
    } catch (e) {
      SmartDialog.showToast('连接失败: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAppBar = widget.showAppBar;
    final padding = MediaQuery.viewPaddingOf(context);
    return Scaffold(
      appBar: showAppBar ? AppBar(title: const Text('单机怀旧模式')) : null,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          ListView(
            padding: padding.copyWith(
              top: 20,
              left: 20 + (showAppBar ? padding.left : 0),
              right: 20 + (showAppBar ? padding.right : 0),
              bottom: padding.bottom + 100,
            ),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用单机怀旧模式'),
                subtitle: const Text('开启后数据源切换为自建局域网服务端，AI字幕/大会员/充电解锁等云端专属入口将被隐藏'),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _hostCtr,
                decoration: const InputDecoration(
                  labelText: '服务端局域网 IP',
                  hintText: '例如 192.168.1.10',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _portCtr,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '端口',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  shape: const RoundedRectangleBorder(
                    borderRadius: Style.mdRadius,
                  ),
                ),
                onPressed: _testing ? null : _testConnection,
                child: Text(_testing ? '测试中...' : '测试连接'),
              ),
            ],
          ),
          Positioned(
            right:
                kFloatingActionButtonMargin + (showAppBar ? padding.right : 0),
            bottom: kFloatingActionButtonMargin + padding.bottom,
            child: FloatingActionButton(
              child: const Icon(Icons.save),
              onPressed: () async {
                await _save();
                SmartDialog.showToast('已保存');
              },
            ),
          ),
        ],
      ),
    );
  }
}
// === OFFLINE-NOSTALGIA-MODE END ===
