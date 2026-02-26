import '../database/database_helper.dart';
import '../models/ab_line.dart';
import '../models/work_session.dart';
import '../models/track_point.dart';

class AppRepository {
  final _db = DatabaseHelper();

  Future<List<AbLine>> getAllAbLines() => _db.getAllAbLines();
  Future<AbLine?> getAbLineById(int id) => _db.getAbLineById(id);
  Future<int> insertAbLine(AbLine line) => _db.insertAbLine(line);
  Future<int> updateAbLine(AbLine line) => _db.updateAbLine(line);
  Future<int> deleteAbLine(int id) => _db.deleteAbLine(id);

  Future<List<WorkSession>> getAllWorkSessions() => _db.getAllWorkSessions();
  Future<WorkSession?> getWorkSessionById(int id) => _db.getWorkSessionById(id);
  Future<int> insertWorkSession(WorkSession session) => _db.insertWorkSession(session);
  Future<int> updateWorkSession(WorkSession session) => _db.updateWorkSession(session);
  Future<int> deleteWorkSession(int id) => _db.deleteWorkSession(id);

  Future<List<TrackPoint>> getTrackPointsBySessionId(int sessionId) =>
      _db.getTrackPointsBySessionId(sessionId);
  Future<int> getTrackPointsCount(int sessionId) => _db.getTrackPointsCount(sessionId);
  Future<void> insertTrackPoints(List<TrackPoint> points) => _db.insertTrackPoints(points);
}
