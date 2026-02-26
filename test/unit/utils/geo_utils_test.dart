import 'package:flutter_test/flutter_test.dart';
import 'package:agrokilar_compass/utils/geo_utils.dart';

void main() {
  group('haversineDistanceMeters', () {
    test('returns 0 for same point', () {
      expect(
        haversineDistanceMeters(55.75, 37.62, 55.75, 37.62),
        closeTo(0, 0.001),
      );
    });

    test('returns known distance for Moscow–nearby (~222m north)', () {
      // ~1 аркадная минута широты ≈ 1852 м. 222м ≈ 2 угловых секунды.
      final d = haversineDistanceMeters(55.75, 37.62, 55.752, 37.62);
      expect(d, greaterThan(200));
      expect(d, lessThan(250));
    });

    test('returns symmetric distance', () {
      final d1 = haversineDistanceMeters(55.75, 37.62, 55.752, 37.626);
      final d2 = haversineDistanceMeters(55.752, 37.626, 55.75, 37.62);
      expect(d1, closeTo(d2, 0.001));
    });

    test('equator: 1 degree lat ≈ 111 km', () {
      final d = haversineDistanceMeters(0, 0, 1, 0);
      expect(d, closeTo(111320, 1000));
    });
  });

  group('bearingDegrees', () {
    test('north to north = 0', () {
      expect(bearingDegrees(55, 37, 56, 37), closeTo(0, 1));
    });

    test('north to east ≈ 90', () {
      expect(bearingDegrees(55, 37, 55, 38), closeTo(90, 5));
    });

    test('returns 0–360', () {
      final b = bearingDegrees(55.75, 37.62, 55.752, 37.626);
      expect(b, greaterThanOrEqualTo(0));
      expect(b, lessThan(360));
    });
  });

  group('deviationFromAbLineMeters', () {
    test('point on line A→B gives ~0 deviation', () {
      const latA = 55.75;
      const lonA = 37.62;
      const latB = 55.752;
      const lonB = 37.626;
      // Точка на середине отрезка
      final lat = (latA + latB) / 2;
      final lon = (lonA + lonB) / 2;
      final d = deviationFromAbLineMeters(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        lat: lat,
        lon: lon,
        directionAtoB: true,
      );
      expect(d.abs(), lessThan(0.5));
    });

    test('symmetry: point left for A→B is right for B→A', () {
      const latA = 55.75;
      const lonA = 37.62;
      const latB = 55.752;
      const lonB = 37.626;
      // Точка слегка слева от линии
      final (lat, lon) = moveByHeadingMeters(
        (latA + latB) / 2,
        (lonA + lonB) / 2,
        bearingDegrees(latA, lonA, latB, lonB) - 90,
        10,
      );
      final dAtoB = deviationFromAbLineMeters(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        lat: lat,
        lon: lon,
        directionAtoB: true,
      );
      final dBtoA = deviationFromAbLineMeters(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        lat: lat,
        lon: lon,
        directionAtoB: false,
      );
      expect(dAtoB, closeTo(-dBtoA, 0.01));
    });

    test('degenerate A=B returns 0', () {
      final d = deviationFromAbLineMeters(
        latA: 55.75,
        lonA: 37.62,
        latB: 55.75,
        lonB: 37.62,
        lat: 55.76,
        lon: 37.63,
        directionAtoB: true,
      );
      expect(d, 0);
    });
  });

  group('moveByHeadingMeters', () {
    test('north: lat increases', () {
      final (lat, lon) = moveByHeadingMeters(55, 37, 0, 100);
      expect(lat, greaterThan(55));
      expect(lon, closeTo(37, 0.001));
    });

    test('east: lon increases', () {
      final (lat, lon) = moveByHeadingMeters(55, 37, 90, 100);
      expect(lat, closeTo(55, 0.001));
      expect(lon, greaterThan(37));
    });

    test('distance matches haversine', () {
      const lat = 55.75;
      const lon = 37.62;
      const heading = 45.0;
      const meters = 500.0;
      final (lat2, lon2) = moveByHeadingMeters(lat, lon, heading, meters);
      final d = haversineDistanceMeters(lat, lon, lat2, lon2);
      expect(d, closeTo(meters, 5));
    });
  });

  group('isDirectionAtoB', () {
    test('bearing toward B returns true', () {
      const latA = 55.75;
      const lonA = 37.62;
      const latB = 55.752;
      const lonB = 37.626;
      final bearingAtoB = bearingDegrees(latA, lonA, latB, lonB);
      expect(
        isDirectionAtoB(latA, lonA, latB, lonB, bearingAtoB),
        isTrue,
      );
    });

    test('bearing toward A returns false', () {
      const latA = 55.75;
      const lonA = 37.62;
      const latB = 55.752;
      const lonB = 37.626;
      final bearingBtoA = (bearingDegrees(latA, lonA, latB, lonB) + 180) % 360;
      expect(
        isDirectionAtoB(latA, lonA, latB, lonB, bearingBtoA),
        isFalse,
      );
    });
  });
}
