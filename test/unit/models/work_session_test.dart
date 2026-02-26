import 'package:flutter_test/flutter_test.dart';
import 'package:agrokilar_compass/models/work_session.dart';

void main() {
  group('WorkSession', () {
    test('toMap and fromMap roundtrip', () {
      final session = WorkSession(
        id: 1,
        abLineId: 5,
        startTime: DateTime(2024, 1, 15, 9, 0, 0),
        endTime: DateTime(2024, 1, 15, 11, 30, 0),
        distanceKm: 25.5,
        areaHa: 5.1,
        abLineName: 'Поле 1',
        widthMeters: 2.0,
      );
      final map = session.toMap();
      final restored = WorkSession.fromMap(map, abLineName: session.abLineName, widthMeters: session.widthMeters);
      expect(restored.id, session.id);
      expect(restored.abLineId, session.abLineId);
      expect(restored.startTime, session.startTime);
      expect(restored.endTime, session.endTime);
      expect(restored.distanceKm, session.distanceKm);
      expect(restored.areaHa, session.areaHa);
    });

    test('fromMap with null endTime', () {
      final map = {
        'id': 1,
        'ab_line_id': 2,
        'start_time': '2024-01-01T08:00:00.000',
        'end_time': null,
        'distance_km': 0,
        'area_ha': 0,
      };
      final session = WorkSession.fromMap(map);
      expect(session.endTime, isNull);
      expect(session.distanceKm, 0);
      expect(session.areaHa, 0);
    });

    test('copyWith changes single field', () {
      final session = WorkSession(
        id: 1,
        startTime: DateTime(2024, 1, 1),
        distanceKm: 10,
        areaHa: 2,
      );
      final updated = session.copyWith(distanceKm: 15);
      expect(updated.distanceKm, 15);
      expect(updated.areaHa, session.areaHa);
    });

    test('duration with endTime', () {
      final start = DateTime(2024, 1, 1, 10, 0, 0);
      final end = DateTime(2024, 1, 1, 12, 30, 0);
      final session = WorkSession(
        startTime: start,
        endTime: end,
      );
      expect(session.duration, const Duration(hours: 2, minutes: 30));
    });
  });
}
