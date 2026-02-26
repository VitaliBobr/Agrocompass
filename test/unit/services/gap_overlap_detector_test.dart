import 'package:flutter_test/flutter_test.dart';
import 'package:agrokilar_compass/models/track_point.dart';
import 'package:agrokilar_compass/services/gap_overlap_detector.dart';
import 'package:agrokilar_compass/utils/geo_utils.dart';

void main() {
  group('GapOverlapDetector', () {
    test('returns ok when track has few points', () {
      final points = List.generate(
        15,
        (i) => TrackPoint(
          sessionId: 1,
          lat: 55.75 + i * 0.0001,
          lon: 37.62,
          timestamp: DateTime(2024, 1, 1, 10, 0, i),
        ),
      );
      final status = GapOverlapDetector.detect(
        trackPoints: points,
        lat: 55.755,
        lon: 37.62,
        widthMeters: 2.0,
      );
      expect(status, GapOverlapStatus.ok);
    });

    test('returns gap when current position far from previous pass', () {
      final baseLat = 55.75;
      final baseLon = 37.62;
      // Предыдущий проход: 30 точек вдоль линии
      final prevPoints = List.generate(
        30,
        (i) => TrackPoint(
          sessionId: 1,
          lat: baseLat + i * 0.0001,
          lon: baseLon,
          timestamp: DateTime(2024, 1, 1, 10, 0, i),
        ),
      );
      // Текущий проход: 25 точек (считаются текущими)
      final currentPoints = List.generate(
        25,
        (i) => TrackPoint(
          sessionId: 1,
          lat: baseLat + 0.01 + i * 0.0001,
          lon: baseLon,
          timestamp: DateTime(2024, 1, 1, 10, 5, i),
        ),
      );
      final allPoints = [...prevPoints, ...currentPoints];
      final (farLat, farLon) = moveByHeadingMeters(
        baseLat + 0.01,
        baseLon,
        90,
        50,
      );
      final status = GapOverlapDetector.detect(
        trackPoints: allPoints,
        lat: farLat,
        lon: farLon,
        widthMeters: 2.0,
        lastPointsAsCurrentPass: 20,
      );
      expect(status, GapOverlapStatus.gap);
    });

    test('returns overlap when distance to prev pass is 0.5–1.9 m', () {
      final baseLat = 55.75;
      final baseLon = 37.62;
      // Одна точка предыдущего прохода в baseLat; текущая позиция 1.0 м севернее
      final offsetDeg = 1.0 / 111320; // ~0.000009
      final prevPoint = TrackPoint(
        sessionId: 1,
        lat: baseLat,
        lon: baseLon,
        timestamp: DateTime(2024, 1, 1, 10, 0, 0),
      );
      final morePrev = List.generate(
        34,
        (i) => TrackPoint(
          sessionId: 1,
          lat: baseLat + 10 + i, // далеко, чтобы не влиять
          lon: baseLon,
          timestamp: DateTime(2024, 1, 1, 10, 0, i + 1),
        ),
      );
      final currentPoints = List.generate(
        20,
        (i) => TrackPoint(
          sessionId: 1,
          lat: baseLat + offsetDeg + i * 0.001,
          lon: baseLon,
          timestamp: DateTime(2024, 1, 1, 10, 5, i),
        ),
      );
      final allPoints = [prevPoint, ...morePrev, ...currentPoints];
      final minDist = haversineDistanceMeters(baseLat, baseLon, baseLat + offsetDeg, baseLon);
      expect(minDist, greaterThan(0.5));
      expect(minDist, lessThan(1.9));
      final status = GapOverlapDetector.detect(
        trackPoints: allPoints,
        lat: baseLat + offsetDeg,
        lon: baseLon,
        widthMeters: 2.0,
        lastPointsAsCurrentPass: 20,
      );
      expect(status, GapOverlapStatus.overlap);
    });

    test('returns ok when distance is within width±tolerance', () {
      final baseLat = 55.75;
      final baseLon = 37.62;
      // 0.000018 deg ≈ 2.0 м — в допустимом диапазоне (1.9–2.2 м)
      final prevPoints = List.generate(
        30,
        (i) => TrackPoint(
          sessionId: 1,
          lat: baseLat + i * 0.0001,
          lon: baseLon,
          timestamp: DateTime(2024, 1, 1, 10, 0, i),
        ),
      );
      final currentPoints = List.generate(
        25,
        (i) => TrackPoint(
          sessionId: 1,
          lat: baseLat + 0.000018 + i * 0.0001,
          lon: baseLon,
          timestamp: DateTime(2024, 1, 1, 10, 5, i),
        ),
      );
      final allPoints = [...prevPoints, ...currentPoints];
      final dist = haversineDistanceMeters(
        baseLat,
        baseLon,
        baseLat + 0.000018,
        baseLon,
      );
      expect(dist, greaterThan(2.0 - 0.1));
      expect(dist, lessThan(2.0 + 0.2));
      final status = GapOverlapDetector.detect(
        trackPoints: allPoints,
        lat: baseLat + 0.000018,
        lon: baseLon,
        widthMeters: 2.0,
        lastPointsAsCurrentPass: 20,
      );
      expect(status, GapOverlapStatus.ok);
    });
  });
}
