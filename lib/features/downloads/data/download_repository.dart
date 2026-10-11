import 'package:sqflite/sqflite.dart';

import '../domain/download_status.dart';
import '../domain/download_task.dart';
import 'download_database.dart';

class DownloadRepository {
  DownloadRepository(this._db);
  final DownloadDatabase _db;

  Future<void> upsert(DownloadTask t) async {
    await _db.database.insert(
      'download_tasks',
      t.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DownloadTask?> findById(String id) async {
    final rows = await _db.database.query(
      'download_tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DownloadTask.fromMap(rows.first);
  }

  Future<List<DownloadTask>> all() async {
    final rows = await _db.database.query(
      'download_tasks',
      orderBy: 'created_at DESC',
    );
    return rows.map(DownloadTask.fromMap).toList();
  }

  Future<List<DownloadTask>> active() async {
    final rows = await _db.database.query(
      'download_tasks',
      where: 'status IN (?, ?, ?, ?)',
      whereArgs: [
        DownloadStatus.queued.name,
        DownloadStatus.analyzing.name,
        DownloadStatus.downloading.name,
        DownloadStatus.paused.name,
      ],
      orderBy: 'created_at DESC',
    );
    return rows.map(DownloadTask.fromMap).toList();
  }

  Future<List<DownloadTask>> completed() async {
    final rows = await _db.database.query(
      'download_tasks',
      where: 'status = ?',
      whereArgs: [DownloadStatus.completed.name],
      orderBy: 'finished_at DESC',
    );
    return rows.map(DownloadTask.fromMap).toList();
  }

  Future<void> deleteById(String id) async {
    await _db.database.delete('download_tasks', where: 'id = ?', whereArgs: [id]);
  }
}
