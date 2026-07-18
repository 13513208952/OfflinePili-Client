// === OFFLINE-NOSTALGIA-MODE BEGIN ===
// 单机怀旧模式配置页，照抄 lib/pages/webdav/view.dart 的结构。
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/utils/offline/offline_config.dart';
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
  final _hostBackupCtr =
      TextEditingController(text: Pref.offlineServerHostBackup);
  final _portCtr =
      TextEditingController(text: Pref.offlineServerPort.toString());
  late bool _enabled = Pref.offlineModeEnabled;
  late int _usbMode = Pref.offlineUsbLinkMode;
  bool _testing = false;

  @override
  void dispose() {
    _hostCtr.dispose();
    _hostBackupCtr.dispose();
    _portCtr.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final port = int.tryParse(_portCtr.text) ?? Pref.offlineServerPort;
    await GStorage.setting.putAll({
      SettingBoxKey.offlineModeEnabled: _enabled,
      SettingBoxKey.offlineServerHost: _hostCtr.text.trim(),
      SettingBoxKey.offlineServerHostBackup: _hostBackupCtr.text.trim(),
      SettingBoxKey.offlineServerPort: port,
      SettingBoxKey.offlineUsbLinkMode: _usbMode,
    });
    OfflineConfig.invalidate(); // 配置变了，下次请求重新探测
  }

  // 逐个探测所有候选地址，报告每一路的连通情况
  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final port = int.tryParse(_portCtr.text) ?? Pref.offlineServerPort;
    final candidates = <String, String>{
      if (_usbMode != 0) 'USB直连': '127.0.0.1',
      if (_hostCtr.text.trim().isNotEmpty) '主地址': _hostCtr.text.trim(),
      if (_hostBackupCtr.text.trim().isNotEmpty)
        '备用地址': _hostBackupCtr.text.trim(),
    };
    if (candidates.isEmpty) {
      SmartDialog.showToast('先填至少一个地址(或启用USB直连)');
      setState(() => _testing = false);
      return;
    }
    final results = <String>[];
    for (final e in candidates.entries) {
      try {
        final res = await Request().get(
          'http://${e.value}:$port/health',
          options: Options(
            sendTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 3),
          ),
        );
        results.add(res.data is Map && res.data['status'] == 'ok'
            ? '${e.key} ✓'
            : '${e.key} ✗(响应异常)');
      } catch (_) {
        results.add('${e.key} ✗');
      }
    }
    SmartDialog.showToast(results.join('  '));
    if (mounted) setState(() => _testing = false);
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
                  labelText: '主地址(内网IP或公网IP/域名)',
                  hintText: '例如 192.168.1.10',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _hostBackupCtr,
                decoration: const InputDecoration(
                  labelText: '备用地址(选填)',
                  hintText: '主地址连不上时自动尝试，如公网IP',
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
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'USB直连(需服务端电脑有adb且手机开USB调试)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _usbMode,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('禁用')),
                      DropdownMenuItem(
                          value: 1, child: Text('启用(优先USB，插线即连)')),
                      DropdownMenuItem(
                          value: 2, child: Text('启用(优先网络，USB作后备)')),
                    ],
                    onChanged: (v) => setState(() => _usbMode = v ?? 0),
                  ),
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
                child: Text(_testing ? '测试中...' : '测试连接(逐路探测)'),
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
