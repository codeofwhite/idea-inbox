import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:idea_inbox/models/idea.dart';
import 'package:idea_inbox/storage/database.dart';
import 'package:idea_inbox/storage/idea_repository.dart';
import 'package:idea_inbox/services/backup.dart';

void main() {
  const uuid = Uuid();
  late AppDatabase aDb, bDb;
  late IdeaRepository a, b;
  setUp(() {
    aDb = AppDatabase(':memory:');
    bDb = AppDatabase(':memory:');
    a = IdeaRepository(aDb, uuid.v4());
    b = IdeaRepository(bDb, uuid.v4());
  });
  tearDown(() {
    a.dispose();
    b.dispose();
    aDb.close();
    bDb.close();
  });

  test('ten offline ideas survive repeat ingestion without duplication', () {
    for (var i = 0; i < 10; i++) {
      a.create('公交上的灵感 $i');
    }
    expect(b.ingest(a.revisions), 10);
    expect(b.ingest(a.revisions), 0);
    expect(b.ideas.length, 10);
  });
  test('concurrent edits remain separate until explicitly merged', () {
    a.create('原始想法');
    b.ingest(a.revisions);
    a.update(a.ideas.single, '电脑修改');
    b.update(b.ideas.single, '手机修改');
    a.ingest(b.revisions);
    b.ingest(a.revisions);
    expect(a.ideas.single.heads.map((r) => r.text).toSet(), {'电脑修改', '手机修改'});
    a.update(a.ideas.single, '手动合并电脑和手机修改');
    b.ingest(a.revisions);
    expect(b.ideas.single.conflicted, false);
    expect(b.ideas.single.display.text, '手动合并电脑和手机修改');
    expect(b.revisions.length, 4);
  });
  test('delete versus edit remains a recoverable conflict', () {
    a.create('不能丢失');
    b.ingest(a.revisions);
    a.update(a.ideas.single, '不能丢失', deleted: true);
    b.update(b.ideas.single, '新增重要细节');
    a.ingest(b.revisions);
    expect(a.ideas.single.conflicted, true);
    expect(a.ideas.single.heads.any((r) => r.deleted), true);
    a.update(a.ideas.single, '恢复并保留细节', deleted: false);
    b.ingest(a.revisions);
    expect(b.ideas.single.display.deleted, false);
    expect(b.ideas.single.conflicted, false);
  });
  test('invalid batch rolls back every incoming row', () {
    a.create('已有数据');
    b.create('本来可以导入');
    final orphan = Revision(
      id: uuid.v4(),
      ideaId: uuid.v4(),
      deviceId: b.deviceId,
      parents: [uuid.v4()],
      text: '缺少父版本',
      archived: false,
      deleted: false,
      createdAt: DateTime.utc(2020),
      editedAt: DateTime.utc(2020),
    );
    expect(() => a.ingest([...b.revisions, orphan]), throwsFormatException);
    expect(a.ideas.single.display.text, '已有数据');
  });
  test('same revision ID with different content is rejected', () {
    a.create('正确内容');
    final json = a.revisions.single.toJson()..['text'] = '被篡改';
    expect(() => a.ingest([Revision.fromJson(json)]), throwsFormatException);
    expect(a.ideas.single.display.text, '正确内容');
  });
  test('clock order does not decide which edit wins', () {
    a.create('原始');
    b.ingest(a.revisions);
    final base = b.revisions.single;
    final oldClockEdit = Revision(
      id: uuid.v4(),
      ideaId: base.ideaId,
      deviceId: b.deviceId,
      parents: [base.id],
      text: '手机时钟落后',
      archived: false,
      deleted: false,
      createdAt: base.createdAt,
      editedAt: DateTime.utc(2000),
    );
    b.ingest([oldClockEdit]);
    a.update(a.ideas.single, '电脑当前时间');
    a.ingest(b.revisions);
    expect(a.ideas.single.heads.length, 2);
  });
  test('stale edit cannot silently overwrite a newly received revision', () {
    a.create('原始');
    final stale = a.ideas.single;
    b.ingest(a.revisions);
    b.update(b.ideas.single, '刚刚收到的新版本');
    a.ingest(b.revisions);
    expect(() => a.update(stale, '旧编辑框中的内容'), throwsStateError);
    expect(a.ideas.single.display.text, '刚刚收到的新版本');
  });
  test('backup round trip preserves revisions and excludes credentials', () {
    a.create('备份测试');
    a.update(a.ideas.single, '已归档', archived: true);
    final content = BackupService(a).exportJson();
    expect(content.contains('token'), false);
    expect(BackupService(b).restoreJson(content), 2);
    expect(BackupService(b).restoreJson(content), 0);
    expect(b.ideas.single.display.archived, true);
    expect(BackupService(b).exportMarkdown(), contains('已归档'));
    expect(
      () => BackupService(b).restoreJson('{"version":99}'),
      throwsFormatException,
    );
  });
  test('acknowledgements only count known persisted revisions', () {
    a.create('一');
    a.create('二');
    expect(a.pending(b.deviceId), 2);
    a.acknowledge(b.deviceId, [a.revisions.first.id, uuid.v4()]);
    expect(a.pending(b.deviceId), 1);
  });
  test('file database persists across closing and reopening', () async {
    final temp = await Directory.systemTemp.createTemp('idea-inbox-test-');
    final path = '${temp.path}/ideas.sqlite3';
    try {
      final db = AppDatabase(path);
      final repo = IdeaRepository(db, uuid.v4());
      repo.create('断电前已提交');
      final id = repo.deviceId;
      repo.dispose();
      db.close();
      final reopened = AppDatabase(path);
      final restored = IdeaRepository(reopened, id);
      expect(restored.ideas.single.display.text, '断电前已提交');
      restored.dispose();
      reopened.close();
    } finally {
      await temp.delete(recursive: true);
    }
  });
}
