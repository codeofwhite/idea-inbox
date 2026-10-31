import 'dart:convert';

import '../storage/idea_repository.dart';
import '../sync/protocol.dart';

class BackupService {
  final IdeaRepository repository;
  BackupService(this.repository);
  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'format': 'idea-inbox-backup',
    'version': 1,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'revisions': repository.revisions.map((r) => r.toJson()).toList(),
  });
  int restoreJson(String content) {
    if (utf8.encode(content).length > 64 * 1024 * 1024) {
      throw const FormatException('备份文件超过 64 MiB');
    }
    final data = jsonDecode(content) as Map<String, dynamic>;
    if (data['format'] != 'idea-inbox-backup' || data['version'] != 1) {
      throw const FormatException('备份格式不兼容');
    }
    return repository.ingest(parseRevisions(data['revisions']));
  }

  String exportMarkdown() {
    final out = StringBuffer('# Idea Inbox\n\n');
    for (final idea in repository.ideas) {
      out.writeln('## ${idea.display.createdAt.toLocal()}');
      out.writeln('<!-- idea: ${idea.id} -->\n');
      for (var index = 0; index < idea.heads.length; index++) {
        final revision = idea.heads[index];
        if (idea.conflicted) out.writeln('### 冲突版本 ${index + 1}');
        out.writeln(
          '状态：${revision.deleted
              ? "回收站"
              : revision.archived
              ? "已归档"
              : "待整理"}\n',
        );
        out.writeln(revision.text);
        out.writeln();
      }
    }
    return out.toString();
  }
}
