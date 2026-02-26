import '../models/ab_line.dart';
import '../models/work_session.dart';
import '../models/track_point.dart';

/// In-memory implementation for web (sqflite is not supported in browser).
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  factory DatabaseHelper() => _instance;

  DatabaseHelper._();

  final List<Map<String, dynamic>> _abLines = [];
  final List<Map<String, dynamic>> _workSessions = [];
  final List<Map<String, dynamic>> _trackPoints = [];
  int _abLineId = 0;
  int _sessionId = 0;
  int _trackPointId = 0;

  Future<int> insertAbLine(AbLine line) async {
    _abLineId++;
    final m = line.toMap();
    m['id'] = _abLineId;
    _abLines.add(m);
    return _abLineId;
  }

  Future<List<AbLine>> getAllAbLines() async {
    _abLines.sort((a, b) => ((b['created_at'] as String?) ?? '').compareTo((a['created_at'] as String?) ?? ''));
    return _abLines.map((m) => AbLine.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  Future<AbLine?> getAbLineById(int id) async {
    try {
      final m = _abLines.firstWhere((e) => e['id'] == id);
      return AbLine.fromMap(Map<String, dynamic>.from(m));
    } catch (_) {
      return null;
    }
  }

  Future<int> updateAbLine(AbLine line) async {
    if (line.id == null) return 0;
    final i = _abLines.indexWhere((e) => e['id'] == line.id);
    if (i < 0) return 0;
    _abLines[i] = line.toMap()..['id'] = line.id;
    return 1;
  }

  Future<int> deleteAbLine(int id) async {
    final sessionIds = _workSessions
        .where((s) => s['ab_line_id'] == id)
        .map((s) => s['id'])
        .whereType<int>()
        .toSet();
    _trackPoints.removeWhere((p) => sessionIds.contains(p['session_id']));
    _workSessions.removeWhere((e) => e['ab_line_id'] == id);
    final before = _abLines.length;
    _abLines.removeWhere((e) => e['id'] == id);
    return before - _abLines.length;
  }

  Future<int> insertWorkSession(WorkSession session) async {
    _sessionId++;
    final m = session.toMap();
    m['id'] = _sessionId;
    _workSessions.add(m);
    return _sessionId;
  }

  Future<int> updateWorkSession(WorkSession session) async {
    if (session.id == null) return 0;
    final i = _workSessions.indexWhere((e) => e['id'] == session.id);
    if (i < 0) return 0;
    _workSessions[i] = session.toMap()..['id'] = session.id;
    return 1;
  }

  Future<List<WorkSession>> getAllWorkSessions() async {
    _workSessions.sort((a, b) => ((b['start_time'] as String?) ?? '').compareTo((a['start_time'] as String?) ?? ''));
    final list = <WorkSession>[];
    for (final m in _workSessions) {
      final abLineId = m['ab_line_id'] as int?;
      String? name;
      double? width;
      if (abLineId != null) {
        final ab = await getAbLineById(abLineId);
        name = ab?.name;
        width = ab?.widthMeters;
      }
      list.add(WorkSession.fromMap(Map<String, dynamic>.from(m), abLineName: name, widthMeters: width));
    }
    return list;
  }

  Future<WorkSession?> getWorkSessionById(int id) async {
    try {
      final m = _workSessions.firstWhere((e) => e['id'] == id);
      final abLineId = m['ab_line_id'] as int?;
      String? name;
      double? width;
      if (abLineId != null) {
        final ab = await getAbLineById(abLineId);
        name = ab?.name;
        width = ab?.widthMeters;
      }
      return WorkSession.fromMap(Map<String, dynamic>.from(m), abLineName: name, widthMeters: width);
    } catch (_) {
      return null;
    }
  }

  Future<int> deleteWorkSession(int id) async {
    _trackPoints.removeWhere((e) => e['session_id'] == id);
    final before = _workSessions.length;
    _workSessions.removeWhere((e) => e['id'] == id);
    return before - _workSessions.length;
  }

  Future<void> insertTrackPoints(List<TrackPoint> points) async {
    for (final p in points) {
      _trackPointId++;
      final m = p.toMap();
      m['id'] = _trackPointId;
      _trackPoints.add(m);
    }
  }

  Future<List<TrackPoint>> getTrackPointsBySessionId(int sessionId) async {
    final list = _trackPoints.where((e) => e['session_id'] == sessionId).toList();
    list.sort((a, b) => ((a['timestamp'] as String?) ?? '').compareTo((b['timestamp'] as String?) ?? ''));
    return list.map((m) => TrackPoint.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  Future<int> getTrackPointsCount(int sessionId) async {
    return _trackPoints.where((e) => e['session_id'] == sessionId).length;
  }
}
