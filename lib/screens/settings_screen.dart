import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../services/backup.dart';

class SettingsScreen extends StatelessWidget {
  final AppController controller;
  const SettingsScreen({super.key, required this.controller});

  Future<void> export(bool markdown) => controller.run(() async {
    final backup = BackupService(controller.repository);
    final content = markdown ? backup.exportMarkdown() : backup.exportJson();
    final bytes = Uint8List.fromList(utf8.encode(content));
    final extension = markdown ? 'md' : 'json';
    final date = DateTime.now().toIso8601String().replaceAll(':', '-');
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出本地数据',
      fileName: 'idea-inbox-$date.$extension',
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );
    if (path == null) return;
    if (Platform.isWindows) await File(path).writeAsBytes(bytes, flush: true);
    controller.status = '已导出${markdown ? " Markdown" : "完整 JSON 备份"}';
  });

  Future<void> restore(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('合并恢复 JSON 备份？'),
        content: const Text('备份将与本机数据合并，重复版本不会重复导入。不同修改会保留为冲突，不会清空本机记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('选择备份'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.run(() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      );
      if (result == null) return;
      final selected = result.files.single;
      if (selected.size > 64 * 1024 * 1024) {
        throw const FormatException('备份文件超过 64 MiB');
      }
      final path = selected.path;
      if (path == null) throw StateError('无法访问所选文件，请先将文件保存到本机');
      final content = await File(path).readAsString();
      final count = BackupService(controller.repository).restoreJson(content);
      controller.status = '恢复完成：合并 $count 个新修订';
    });
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('数据与设置', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const Text('所有记录保存在本机。应用不包含云同步、账号服务或统计上报。\n同步会传播删除状态，独立备份仍然必要。'),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('导出完整 JSON 备份'),
            subtitle: const Text('包含所有历史版本、冲突和回收站，不包含设备密钥或配对凭据。'),
            onTap: controller.busy ? null : () => export(false),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('导出 Markdown'),
            subtitle: const Text('便于阅读与迁移，包含当前版本和未解决冲突；不能作为完整恢复文件。'),
            onTap: controller.busy ? null : () => export(true),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('从 JSON 备份合并恢复'),
            onTap: controller.busy ? null : () => restore(context),
          ),
          const Divider(height: 32),
          const Text('记录库和导出文件未进行应用层加密，请妥善保管设备与备份。配对凭据和电脑证书私钥使用系统安全存储。'),
          const SizedBox(height: 16),
          const Text(
            '第一版限制：纯文字、前台手动同步、IPv4 私有局域网、最多 10000 个修订、单次同步不超过 16 MiB。',
          ),
          const SizedBox(height: 16),
          const Text('Idea Inbox 0.1.0 · Android / Windows'),
        ],
      ),
    ),
  );
}
