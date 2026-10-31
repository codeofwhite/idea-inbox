import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app.dart';
import '../sync/pairing.dart';
import '../sync/protocol.dart';

class DevicesScreen extends StatefulWidget {
  final AppController controller;
  const DevicesScreen({super.key, required this.controller});
  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<String> addresses = [];
  String? selectedAddress;
  bool discovering = false;
  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) loadAddresses();
  }

  Future<void> loadAddresses() async {
    setState(() => discovering = true);
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      final found =
          interfaces
              .expand((i) => i.addresses)
              .map((a) => a.address)
              .where(isPrivateAddress)
              .toSet()
              .toList()
            ..sort();
      if (!mounted) return;
      setState(() {
        addresses = found;
        if (!found.contains(selectedAddress)) {
          selectedAddress = found.firstOrNull;
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => discovering = false);
    }
  }

  Future<void> showOffer() async {
    final controller = widget.controller;
    final offer = controller.server.offer();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('用手机扫描配对'),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(data: offer.encode(), size: 280),
                ),
                const Text('二维码两分钟内有效，仅使用一次。请勿分享截图。\n扫码后还需在电脑确认。'),
                const SizedBox(height: 12),
                SelectableText(offer.endpoint),
                const SizedBox(height: 8),
                ExpansionTile(
                  title: const Text('无法扫码？复制配对码'),
                  children: [SelectableText(offer.encode())],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    controller.server.cancelOffer();
    if (mounted) setState(() {});
  }

  Future<void> scan() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _ScannerScreen()),
    );
    if (raw != null) await acceptOffer(raw);
  }

  Future<void> acceptOffer(String raw) async {
    await widget.controller.run(() async {
      final offer = PairingOffer.decode(raw);
      widget.controller.setStatus('等待电脑确认配对…');
      await widget.controller.client.pair(offer);
      widget.controller.status = '配对成功，请点击同步';
    });
  }

  Future<void> pasteOffer() async {
    final input = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入配对码'),
        content: TextField(
          controller: input,
          maxLines: 6,
          decoration: const InputDecoration(hintText: '粘贴电脑显示的完整配对码'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('配对'),
          ),
        ],
      ),
    );
    if (raw != null) await acceptOffer(raw);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
  }

  Future<void> changeAddress() async {
    final controller = widget.controller;
    final peer = controller.pairing.peer!;
    final input = TextEditingController(text: peer.endpoint);
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更新电脑地址'),
        content: TextField(
          controller: input,
          decoration: const InputDecoration(
            hintText: 'https://192.168.1.10:47381',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (raw != null) {
      await controller.run(() async {
        final endpoint = checkedEndpoint(raw.trim()).toString();
        await controller.pairing.save(peer.at(endpoint));
        controller.status = '地址已更新，仍校验原电脑证书';
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
  }

  Future<void> revoke() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤销设备配对？'),
        content: const Text('会停止信任对端设备。本机和对端已保存的记录不会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('撤销'),
          ),
        ],
      ),
    );
    if (accepted == true) await widget.controller.revoke();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final windows = Platform.isWindows;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('局域网同步', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('不使用云端。同步时请保持两端应用打开，并接入可互通的局域网。'),
            const SizedBox(height: 24),
            if (windows) ...[
              const Text('电脑作为连接入口，只在你开启时监听所选地址。'),
              const SizedBox(height: 16),
              if (addresses.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedAddress,
                  decoration: const InputDecoration(labelText: '本机局域网地址'),
                  items: addresses
                      .map(
                        (address) => DropdownMenuItem(
                          value: address,
                          child: Text(address),
                        ),
                      )
                      .toList(),
                  onChanged: c.server.running
                      ? null
                      : (value) => setState(() => selectedAddress = value),
                ),
              if (addresses.isEmpty)
                const Text('未找到局域网 IPv4 地址，请连接 Wi-Fi 或有线网络后刷新。'),
              TextButton.icon(
                onPressed: discovering || c.server.running
                    ? null
                    : loadAddresses,
                icon: const Icon(Icons.refresh),
                label: Text(discovering ? '正在刷新…' : '刷新地址'),
              ),
              FilledButton(
                onPressed: c.busy || selectedAddress == null
                    ? null
                    : () => c.run(() async {
                        if (c.server.running) {
                          await c.server.stop();
                          c.status = '局域网服务已关闭';
                        } else {
                          await c.server.start(selectedAddress!);
                        }
                      }),
                child: Text(c.server.running ? '关闭局域网同步' : '开启局域网同步'),
              ),
              if (c.server.running) ...[
                const SizedBox(height: 12),
                SelectableText(c.server.endpoint!),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: c.busy ? null : showOffer,
                  child: const Text('显示配对二维码'),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                '首次连接可能需要允许 Windows 防火墙的“专用网络”访问。请勿关闭防火墙。\n若多个地址可选，请选择与手机处于同一网段的地址。',
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: c.busy ? null : scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('扫描电脑二维码'),
              ),
              TextButton(
                onPressed: c.busy ? null : pasteOffer,
                child: const Text('手动输入配对码'),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: c.busy || c.pairing.peer == null ? null : c.sync,
                icon: const Icon(Icons.sync),
                label: const Text('立即同步'),
              ),
              if (c.pairing.peer != null) ...[
                const SizedBox(height: 12),
                SelectableText('电脑地址：${c.pairing.peer!.endpoint}'),
                TextButton(
                  onPressed: c.busy ? null : changeAddress,
                  child: const Text('电脑 IP 变化？更新地址'),
                ),
              ],
            ],
            const SizedBox(height: 24),
            Text(
              c.pairing.peer == null
                  ? '尚未配对'
                  : '已配对设备：${c.pairing.peer!.id.substring(0, 8)}',
            ),
            if (c.pairing.peer != null)
              TextButton(
                onPressed: c.busy ? null : revoke,
                child: const Text('撤销配对'),
              ),
            const Divider(height: 32),
            Text('本机标识：${c.identity.id}'),
            Text(
              '最近成功：${c.lastSuccess?.toLocal().toString().substring(0, 19) ?? "本次启动后尚未同步"}',
            ),
            const SizedBox(height: 12),
            const Text('待同步数量按修订计数，包含编辑、归档和删除。当前支持一部手机与一台电脑。'),
          ],
        ),
      ),
    );
  }
}

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();
  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  bool completed = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('扫描电脑上的配对二维码')),
    body: MobileScanner(
      onDetect: (capture) {
        if (completed) return;
        for (final code in capture.barcodes) {
          final raw = code.rawValue;
          if (raw != null) {
            completed = true;
            Navigator.pop(context, raw);
            return;
          }
        }
      },
    ),
  );
}
