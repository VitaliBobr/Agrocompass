import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/ab_line.dart';
import '../models/work_session.dart';
import '../models/track_point.dart';

const int _version = 1;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  static Database? _db;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'agrokilar_compass.db');
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ab_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        lat_a REAL NOT NULL,
        lon_a REAL NOT NULL,
        lat_b REAL NOT NULL,
        lon_b REAL NOT NULL,
        width_meters REAL NOT NULL,
        total_area_ha REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE work_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ab_line_id INTEGER,
        start_time TEXT NOT NULL,
        end_time TEXT,
        distance_km REAL DEFAULT 0,
        area_ha REAL DEFAULT 0,
        FOREIGN KEY (ab_line_id) REFERENCES ab_lines(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE track_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        timestamp TEXT NOT NULL,
        speed_kmh REAL,
        bearing REAL,
        deviation_meters REAL,
        FOREIGN KEY (session_id) REFERENCES work_sessions(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_track_points_session ON track_points(session_id)');
    await db.execute('CREATE INDEX idx_track_points_timestamp ON track_points(timestamp)');
  }

  Future<int> insertAbLine(AbLine line) async {
    final db = await database;
    return db.insert('ab_lines', line.toMap());
  }

  Future<List<AbLine>> getAllAbLines() async {
    final db = await database;
    final maps = await db.query('ab_lines', orderBy: 'created_at DESC');
    return maps.map((m) => AbLine.fromMap(m)).toList();
  }

  Future<AbLine?> getAbLineById(int id) async {
    final db = await database;
    final maps = await db.query('ab_lines', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return AbLine.fromMap(maps.first);
  }

  Future<int> updateAbLine(AbLine line) async {
    if (line.id == null) return 0;
    final db = await database;
    return db.update(
      'ab_lines',
      line.toMap(),
      where: 'id = ?',
      whereArgs: [line.id],
    );
  }

  Future<int> deleteAbLine(int id) async {
    final db = await database;
    await db.delete('work_sessions', where: 'ab_line_id = ?', whereArgs: [id]);
    return db.delete('ab_lines', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertWorkSession(WorkSession session) async {
    final db = await database;
    return db.insert('work_sessions', session.toMap());
  }

  Future<int> updateWorkSession(WorkSession session) async {
    if (session.id == null) return 0;
    final db = await database;
    return db.update(
      'work_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<List<WorkSession>> getAllWorkSessions() async {
    final db = await database;
    final maps = await db.query('work_sessions', orderBy: 'start_time DESC');
    final list = <WorkSession>[];
    for (final m in maps) {
      final abLineId = m['ab_line_id'] as int?;
      String? name;
      double? width;
      if (abLineId != null) {
        final ab = await getAbLineById(abLineId);
        name = ab?.name;
        width = ab?.widthMeters;
      }
      list.add(WorkSession.fromMap(m, abLineName: name, widthMeters: width));
    }
    return list;
  }

  Future<WorkSession?> getWorkSessionById(int id) async {
    final db = await database;
    final maps = await db.query('work_sessions', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final m = maps.first;
    final abLineId = m['ab_line_id'] as int?;
    String? name;
    double? width;
    if (abLineId != null) {
      final ab = await getAbLineById(abLineId);
      name = ab?.name;
      width = ab?.widthMeters;
    }
    return WorkSession.fromMap(m, abLineName: name, widthMeters: width);
  }

  Future<int> deleteWorkSession(int id) async {
    final db = await database;
    await db.delete('track_points', where: 'session_id = ?', whereArgs: [id]);
    return db.delete('work_sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertTrackPoints(List<TrackPoint> points) async {
    if (points.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final p in points) {
      batch.insert('track_points', p.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<TrackPoint>> getTrackPointsBySessionId(int sessionId) async {
    final db = await database;
    final maps = await db.query(
      'track_points',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => TrackPoint.fromMap(m)).toList();
  }

  Future<int> getTrackPointsCount(int sessionId) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) as c FROM track_points WHERE session_id = ?',
      [sessionId],
    );
    return (r.first['c'] as int?) ?? 0;
  }
}
