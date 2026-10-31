import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/idea.dart';
import 'database.dart';

class IdeaRepository extends ChangeNotifier {
  final AppDatabase database;
  final String deviceId;
  IdeaRepository(this.database, this.deviceId);
  static const _uuid = Uuid();
  List<Revision> get revisions => database.connection
      .select('SELECT payload FROM revisions ORDER BY id')
      .map(
        (r) => Revision.fromJson(
          jsonDecode(r['payload'] as String) as Map<String, dynamic>,
        ),
      )
      .toList();
  Set<String> get ids => database.connection
      .select('SELECT id FROM revisions')
      .map((r) => r['id'] as String)
      .toSet();
  List<Idea> get ideas {
    final all = revisions;
    final superseded = all.expand((r) => r.parents).toSet();
    final groups = <String, List<Revision>>{};
    for (final r in all.where((r) => !superseded.contains(r.id))) {
      groups.putIfAbsent(r.ideaId, () => []).add(r);
    }
    final result = groups.entries.map((e) {
      e.value.sort((a, b) => a.id.compareTo(b.id));
      return Idea(e.key, e.value);
    }).toList();
    result.sort((a, b) => b.display.createdAt.compareTo(a.display.createdAt));
    return result;
  }

  Revision create(String text) => _save(null, text, false, false);
  Revision update(Idea idea, String text, {bool? archived, bool? deleted}) =>
      _save(
        idea,
        text,
        archived ?? idea.display.archived,
        deleted ?? idea.display.deleted,
      );
  Revision _save(Idea? idea, String text, bool archived, bool deleted) {
    text = text.trim();
    if (text.isEmpty || text.length > maxTextLength) {
      throw const FormatException('请输入 1–32000 个字符');
    }
    if (idea != null) {
      final current = ideas.where((i) => i.id == idea.id).firstOrNull;
      if (current == null ||
          !setEquals(
            current.heads.map((r) => r.id).toSet(),
            idea.heads.map((r) => r.id).toSet(),
          )) {
        throw StateError('记录已收到新版本，请重新打开后保存');
      }
    }
    final now = DateTime.now().toUtc();
    final revision = Revision(
      id: _uuid.v4(),
      ideaId: idea?.id ?? _uuid.v4(),
      deviceId: deviceId,
      parents: idea?.heads.map((r) => r.id).toList() ?? [],
      text: text,
      archived: archived,
      deleted: deleted,
      createdAt: idea?.display.createdAt ?? now,
      editedAt: now,
    );
    ingest([revision]);
    return revision;
  }

  /// Validate the complete merged graph before inserting any rows.
  int ingest(List<Revision> incoming) {
    final existing = {for (final r in revisions) r.id: r};
    final merged = {...existing};
    for (final candidate in incoming) {
      final r = Revision.fromJson(candidate.toJson());
      final previous = merged[r.id];
      if (previous != null && previous.canonical != r.canonical) {
        throw const FormatException('同一修订 ID 的内容不一致，已拒绝导入');
      }
      merged[r.id] = r;
    }
    if (merged.length > maxRevisionCount) {
      throw const FormatException('此版本最多保存 10000 个修订，请先导出备份');
    }
    final roots = <String, String>{};
    final remaining = <String, int>{};
    final children = <String, List<String>>{};
    for (final r in merged.values) {
      if (r.parents.isEmpty) {
        if (roots.containsKey(r.ideaId)) {
          throw const FormatException('一条记录存在多个根版本');
        }
        roots[r.ideaId] = r.id;
      }
      remaining[r.id] = r.parents.length;
      for (final parentId in r.parents) {
        final parent = merged[parentId];
        if (parent == null ||
            parent.ideaId != r.ideaId ||
            parent.createdAt != r.createdAt) {
          throw const FormatException('修订缺少父版本或归属不一致');
        }
        children.putIfAbsent(parentId, () => []).add(r.id);
      }
    }
    final queue = remaining.keys.where((id) => remaining[id] == 0).toList();
    var visited = 0;
    for (var index = 0; index < queue.length; index++) {
      visited++;
      for (final child in children[queue[index]] ?? <String>[]) {
        remaining[child] = remaining[child]! - 1;
        if (remaining[child] == 0) queue.add(child);
      }
    }
    if (visited != merged.length) throw const FormatException('版本关系中存在循环');
    final added = merged.values
        .where((r) => !existing.containsKey(r.id))
        .toList();
    database.transaction(() {
      for (final r in added) {
        database.connection.execute(
          'INSERT INTO revisions(id, idea_id, payload) VALUES (?, ?, ?)',
          [r.id, r.ideaId, r.canonical],
        );
      }
    });
    if (added.isNotEmpty) notifyListeners();
    return added.length;
  }

  void acknowledge(String peerId, Iterable<String> revisionIds) {
    final known = ids;
    database.transaction(() {
      for (final id in revisionIds.toSet().intersection(known)) {
        database.connection.execute(
          'INSERT OR IGNORE INTO acknowledgements(peer_id, revision_id) VALUES (?, ?)',
          [peerId, id],
        );
      }
    });
    notifyListeners();
  }

  int pending(String? peerId) {
    if (peerId == null) return ids.length;
    return database.connection
            .select(
              '''
      SELECT COUNT(*) AS n FROM revisions r WHERE NOT EXISTS (
        SELECT 1 FROM acknowledgements a WHERE a.revision_id = r.id AND a.peer_id = ?
      )
    ''',
              [peerId],
            )
            .first['n']
        as int;
  }
}
