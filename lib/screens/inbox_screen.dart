import 'package:flutter/material.dart';

import '../app.dart';
import '../models/idea.dart';
import '../sync/protocol.dart';

class InboxScreen extends StatefulWidget {
  final AppController controller;
  const InboxScreen({super.key, required this.controller});
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final input = TextEditingController();
  String query = '';
  int filter = 0;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void attempt(VoidCallback action) {
    try {
      action();
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  void save() => attempt(() {
    widget.controller.repository.create(input.text);
    input.clear();
  });
  Future<void> edit(Idea idea) async {
    final text = TextEditingController(text: idea.display.text);
    await showDialog<void>(
      context: context,
      builder: (context) {
        var archived = idea.display.archived;
        var deleted = idea.display.deleted;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(idea.conflicted ? '合并冲突版本' : '编辑灵感'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (idea.conflicted) ...[
                      const Text(
                        '两端都修改过这条记录。请阅读所有版本，编辑下方内容并选择最终状态。保存后保留历史并合并全部版本。',
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < idea.heads.length; i++)
                        ExpansionTile(
                          title: Text(
                            '版本 ${i + 1} · ${idea.heads[i].deleted
                                ? "已删除"
                                : idea.heads[i].archived
                                ? "已归档"
                                : "待整理"}',
                          ),
                          subtitle: Text(
                            '设备 ${idea.heads[i].deviceId.substring(0, 8)}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: SelectableText(idea.heads[i].text),
                            ),
                          ],
                        ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: text,
                      minLines: 4,
                      maxLines: 12,
                      maxLength: maxTextLength,
                      decoration: const InputDecoration(labelText: '内容'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('已归档'),
                      value: archived,
                      onChanged: (v) => setDialogState(() => archived = v!),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('放入回收站'),
                      value: deleted,
                      onChanged: (v) => setDialogState(() => deleted = v!),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (text.text.trim().isEmpty) return;
                  try {
                    widget.controller.repository.update(
                      idea,
                      text.text,
                      archived: archived,
                      deleted: deleted,
                    );
                    Navigator.pop(context);
                  } catch (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(friendlyError(error))),
                    );
                  }
                },
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
    );
    // Route animations may still reference the controller; dispose after the route settles.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    text.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ideas = widget.controller.repository.ideas.where((idea) {
      final matchesFilter = idea.conflicted
          ? filter == 0
          : filter == 2
          ? idea.display.deleted
          : !idea.display.deleted &&
                (filter == 1 ? idea.display.archived : !idea.display.archived);
      return matchesFilter &&
          idea.heads.any(
            (r) => r.text.toLowerCase().contains(query.toLowerCase()),
          );
    }).toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: input,
                minLines: 2,
                maxLines: 5,
                maxLength: maxTextLength,
                decoration: const InputDecoration(
                  hintText: '想到什么，就先记下来…',
                  labelText: '新灵感',
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: save,
                  icon: const Icon(Icons.add),
                  label: const Text('保存到本机'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜索所有文字',
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('待整理')),
                    ButtonSegment(value: 1, label: Text('已归档')),
                    ButtonSegment(value: 2, label: Text('回收站')),
                  ],
                  selected: {filter},
                  onSelectionChanged: (v) => setState(() => filter = v.first),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ideas.isEmpty
                    ? const Center(child: Text('这里还没有灵感。记录会先保存在本机。'))
                    : ListView.builder(
                        itemCount: ideas.length,
                        itemBuilder: (context, index) {
                          final idea = ideas[index];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                idea.display.text,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  idea.conflicted
                                      ? '有 ${idea.heads.length} 个冲突版本 · 点击合并'
                                      : idea.display.createdAt
                                            .toLocal()
                                            .toString()
                                            .substring(0, 16),
                                ),
                              ),
                              trailing: Icon(
                                idea.conflicted
                                    ? Icons.merge
                                    : Icons.edit_outlined,
                              ),
                              onTap: () => edit(idea),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
