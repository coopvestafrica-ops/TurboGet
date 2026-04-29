import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'turboget.db');
    return await openDatabase(
      path,
      version: 3,
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          // Add resume_data and metadata columns
          await db.execute('ALTER TABLE downloads ADD COLUMN resume_data TEXT');
          await db.execute('ALTER TABLE downloads ADD COLUMN metadata TEXT');
        }
        if (oldVersion < 3) {
          // Per-user history scoping, integrity hash, queue priority.
          await db.execute('ALTER TABLE downloads ADD COLUMN owner_user_id TEXT');
          await db.execute('ALTER TABLE downloads ADD COLUMN sha256 TEXT');
          await db.execute(
            'ALTER TABLE downloads ADD COLUMN priority INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
      onCreate: (Database db, int version) async {
        // Downloads table
        await db.execute('''
          CREATE TABLE downloads (
            id TEXT PRIMARY KEY,
            url TEXT NOT NULL,
            filename TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            total_size INTEGER,
            downloaded_size INTEGER DEFAULT 0,
            status TEXT NOT NULL,
            progress INTEGER DEFAULT 0,
            download_path TEXT,
            segments JSON,
            error TEXT,
            metadata JSON,
            owner_user_id TEXT,
            sha256 TEXT,
            priority INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Download segments table for resumable downloads
        await db.execute('''
          CREATE TABLE download_segments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            download_id TEXT NOT NULL,
            start_byte INTEGER NOT NULL,
            end_byte INTEGER NOT NULL,
            downloaded_bytes INTEGER DEFAULT 0,
            status TEXT NOT NULL,
            FOREIGN KEY (download_id) REFERENCES downloads (id)
          )
        ''');

        // Settings table
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // Download operations
  Future<void> insertDownload(Map<String, dynamic> download) async {
    final db = await database;
    await db.insert('downloads', download,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateDownload(String id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update(
      'downloads',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getDownload(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'downloads',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<List<Map<String, dynamic>>> getAllDownloads() async {
    final db = await database;
    return await db.query('downloads', orderBy: 'created_at DESC');
  }

  // Segment operations
  Future<void> insertSegment(Map<String, dynamic> segment) async {
    final db = await database;
    await db.insert('download_segments', segment);
  }

  Future<void> updateSegment(int id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update(
      'download_segments',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getDownloadSegments(String downloadId) async {
    final db = await database;
    return await db.query(
      'download_segments',
      where: 'download_id = ?',
      whereArgs: [downloadId],
      orderBy: 'start_byte ASC',
    );
  }

  // Settings operations
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  // Download queue management
  Future<List<Map<String, dynamic>>> getQueuedDownloads() async {
    final db = await database;
    return await db.query(
      'downloads',
      where: 'status = ?',
      whereArgs: ['queued'],
      orderBy: 'priority ASC, created_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getActiveDownloads() async {
    final db = await database;
    return await db.query(
      'downloads',
      where: 'status IN (?, ?, ?)',
      whereArgs: ['queued', 'downloading', 'paused'],
      orderBy: 'priority ASC, created_at ASC',
    );
  }

  // History operations - returns completed, failed, and cancelled downloads.
  // If [ownerUserId] is provided, scopes results to that user.
  Future<List<Map<String, dynamic>>> getDownloadHistory({
    String? ownerUserId,
  }) async {
    final db = await database;
    if (ownerUserId == null) {
      return await db.query(
        'downloads',
        where: 'status IN (?, ?, ?)',
        whereArgs: ['completed', 'failed', 'cancelled'],
        orderBy: 'created_at DESC',
      );
    }
    return await db.query(
      'downloads',
      where: 'status IN (?, ?, ?) AND (owner_user_id = ? OR owner_user_id IS NULL)',
      whereArgs: ['completed', 'failed', 'cancelled', ownerUserId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteDownloadHistory(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete segments first due to foreign key constraint
      await txn.delete(
        'download_segments',
        where: 'download_id = ?',
        whereArgs: [id],
      );
      // Then delete the download
      await txn.delete(
        'downloads',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> deleteDownload(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete segments first due to foreign key constraint
      await txn.delete(
        'download_segments',
        where: 'download_id = ?',
        whereArgs: [id],
      );
      // Then delete the download
      await txn.delete(
        'downloads',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> clearAllDownloads() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('download_segments');
      await txn.delete('downloads');
    });
  }
}
