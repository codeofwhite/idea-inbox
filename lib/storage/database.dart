import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  final Database connection;
  AppDatabase(String path) : connection = sqlite3.open(path) {
    connection.execute('PRAGMA foreign_keys = ON');
    connection.execute('PRAGMA journal_mode = WAL');
    connection.execute('PRAGMA synchronous = FULL');
    final version =
        connection.select('PRAGMA user_version').first.values.first as int;
    if (version > 1) {
      connection.close();
      throw StateError('数据库来自更新版本，请升级应用后再打开');
    }
    connection.execute('''
      CREATE TABLE IF NOT EXISTS revisions (
        id TEXT PRIMARY KEY, idea_id TEXT NOT NULL, payload TEXT NOT NULL
      )
    ''');
    connection.execute('''
      CREATE TABLE IF NOT EXISTS acknowledgements (
        peer_id TEXT NOT NULL,
        revision_id TEXT NOT NULL REFERENCES revisions(id),
        PRIMARY KEY(peer_id, revision_id)
      )
    ''');
    connection.execute(
      'CREATE INDEX IF NOT EXISTS revisions_idea ON revisions(idea_id)',
    );
    connection.execute('PRAGMA user_version = 1');
  }
  T transaction<T>(T Function() operation) {
    connection.execute('BEGIN IMMEDIATE');
    try {
      final result = operation();
      connection.execute('COMMIT');
      return result;
    } catch (_) {
      connection.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => connection.close();
}
