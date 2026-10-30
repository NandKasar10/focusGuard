import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(docsDir.path, 'focusguard_local.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // Table for daily usage summaries
        await db.execute('''
          CREATE TABLE local_usage (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            app_name TEXT NOT NULL,
            date TEXT NOT NULL,
            total_minutes INTEGER NOT NULL DEFAULT 0,
            session_count INTEGER NOT NULL DEFAULT 0,
            is_synced INTEGER NOT NULL DEFAULT 0,
            UNIQUE(app_name, date)
          )
        ''');

        // Table for offline cached suggestions & replies
        await db.execute('''
          CREATE TABLE local_suggestions (
            id INTEGER PRIMARY KEY,
            app_name TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            suggestion_text TEXT NOT NULL,
            user_reply TEXT,
            action_taken TEXT DEFAULT 'pending'
          )
        ''');

        // Table for scheduled reminders
        await db.execute('''
          CREATE TABLE local_reminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message TEXT NOT NULL,
            scheduled_time TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending'
          )
        ''');
      },
    );
  }

  // --- Usage Record Methods ---

  Future<void> addUsageMinutes({
    required String appName,
    required String dateStr,
    required int minutes,
  }) async {
    final db = await database;
    await db.rawInsert('''
      INSERT INTO local_usage (app_name, date, total_minutes, session_count, is_synced)
      VALUES (?, ?, ?, 1, 0)
      ON CONFLICT(app_name, date) DO UPDATE SET
        total_minutes = total_minutes + excluded.total_minutes,
        is_synced = 0
    ''', [appName, dateStr, minutes]);
  }

  Future<int> getDailyMinutesForApp(String appName, String dateStr) async {
    final db = await database;
    final res = await db.query(
      'local_usage',
      columns: ['total_minutes'],
      where: 'LOWER(app_name) = ? AND date = ?',
      whereArgs: [appName.toLowerCase(), dateStr],
    );
    if (res.isNotEmpty) {
      return (res.first['total_minutes'] as int?) ?? 0;
    }
    return 0;
  }

  Future<int> getCombinedDailyMinutes(String dateStr) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT SUM(total_minutes) as sum_total FROM local_usage WHERE date = ?',
      [dateStr],
    );
    if (res.isNotEmpty && res.first['sum_total'] != null) {
      return (res.first['sum_total'] as num).toInt();
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedUsage() async {
    final db = await database;
    return await db.query('local_usage', where: 'is_synced = 0');
  }

  Future<void> markUsageSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE local_usage SET is_synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  // --- Local Suggestions ---

  Future<void> saveLocalSuggestion({
    required int id,
    required String appName,
    required String timestamp,
    required String suggestionText,
    String? userReply,
    String? actionTaken,
  }) async {
    final db = await database;
    await db.insert(
      'local_suggestions',
      {
        'id': id,
        'app_name': appName,
        'timestamp': timestamp,
        'suggestion_text': suggestionText,
        'user_reply': userReply,
        'action_taken': actionTaken ?? 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSuggestionReply({
    required int id,
    required String userReply,
    required String actionTaken,
  }) async {
    final db = await database;
    await db.update(
      'local_suggestions',
      {'user_reply': userReply, 'action_taken': actionTaken},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getDailySuggestions(String datePrefix) async {
    final db = await database;
    return await db.query(
      'local_suggestions',
      where: 'timestamp LIKE ?',
      whereArgs: ['$datePrefix%'],
      orderBy: 'timestamp DESC',
    );
  }
}
