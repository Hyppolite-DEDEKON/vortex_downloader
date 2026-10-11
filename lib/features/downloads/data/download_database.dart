import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DownloadDatabase {
  DownloadDatabase._(this._db);
  final Database _db;
  static DownloadDatabase? _instance;

  static Future<DownloadDatabase> open() async {
    if (_instance != null) return _instance!;
    final path = p.join(await getDatabasesPath(), 'vortex_downloads.db');
    final db = await openDatabase(
      path,
      version: 4,
      onCreate: (d, _) async {
        await d.execute('''
          CREATE TABLE download_tasks (
            id TEXT PRIMARY KEY,
            source_url TEXT NOT NULL,
            download_url TEXT,
            file_name TEXT NOT NULL,
            local_path TEXT,
            mime_type TEXT,
            total_bytes INTEGER,
            received_bytes INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            finished_at INTEGER,
            last_error TEXT,
            supports_resume INTEGER NOT NULL DEFAULT 0,
            download_headers TEXT,
            thumbnail_url TEXT,
            output_profile TEXT NOT NULL DEFAULT 'hd'
          )
        ''');
      },
      onUpgrade: (d, from, to) async {
        if (from < 2) {
          await d.execute(
            'ALTER TABLE download_tasks ADD COLUMN download_headers TEXT',
          );
        }
        if (from < 3) {
          await d.execute(
            'ALTER TABLE download_tasks ADD COLUMN thumbnail_url TEXT',
          );
        }
        if (from < 4) {
          await d.execute(
            "ALTER TABLE download_tasks ADD COLUMN output_profile TEXT NOT NULL DEFAULT 'hd'",
          );
        }
      },
    );
    return _instance = DownloadDatabase._(db);
  }

  Database get database => _db;

  Future<void> close() async {
    await _db.close();
    _instance = null;
  }
}
