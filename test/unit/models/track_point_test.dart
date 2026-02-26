import 'package:flutter_test/flutter_test.dart';
import 'package:agrokilar_compass/models/track_point.dart';

void main() {
  group('TrackPoint', () {
    test('toMap and fromMap roundtrip', () {
      final point = TrackPoint(
        id: 1,
        sessionId: 10,
        lat: 55.75,
        lon: 37.62,
        timestamp: DateTime(2024, 1, 15, 10, 30, 0),
        speedKmh: 15.5,
        bearing: 90.0,
        deviationMeters: -0.2,
      );
      final map = point.toMap();
      final restored = TrackPoint.fromMap(map);
      expect(restored.id, point.id);
      expect(restored.sessionId, point.sessionId);
      expect(restored.lat, point.lat);
      expect(restored.lon, point.lon);
      expect(restored.timestamp, point.timestamp);
      expect(restored.speedKmh, point.speedKmh);
      expect(restored.bearing, point.bearing);
      expect(restored.deviationMeters, point.deviationMeters);
    });

    test('fromMap with null optional fields', () {
      final map = {
        'session_id': 1,
        'lat': 55.0,
        'lon': 37.0,
        'timestamp': '2024-01-01T00:00:00.000',
      };
      final point = TrackPoint.fromMap(map);
      expect(point.id, isNull);
      expect(point.speedKmh, isNull);
      expect(point.bearing, isNull);
      expect(point.deviationMeters, isNull);
    });

    test('toMap omits id when null', () {
      final point = TrackPoint(
        sessionId: 1,
        lat: 55.0,
        lon: 37.0,
        timestamp: DateTime(2024, 1, 1),
      );
      final map = point.toMap();
      expect(map.containsKey('id'), isFalse);
    });
  });
}
