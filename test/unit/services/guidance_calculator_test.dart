import 'package:flutter_test/flutter_test.dart';
import 'package:agrokilar_compass/utils/geo_utils.dart';
import 'package:agrokilar_compass/services/guidance_calculator.dart';

void main() {
  const latA = 55.75;
  const lonA = 37.62;
  const latB = 55.752;
  const lonB = 37.626;

  group('GuidanceCalculator.deviationMeters', () {
    test('point on line A→B with bearing toward B gives ~0', () {
      final lat = (latA + latB) / 2;
      final lon = (lonA + lonB) / 2;
      final bearing = bearingDegrees(latA, lonA, latB, lonB);
      final d = GuidanceCalculator.deviationMeters(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        lat: lat,
        lon: lon,
        bearingDeg: bearing,
      );
      expect(d.abs(), lessThan(0.5));
    });

    test('point left of line (A→B bearing) gives positive deviation', () {
      final midLat = (latA + latB) / 2;
      final midLon = (lonA + lonB) / 2;
      final bearingAtoB = bearingDegrees(latA, lonA, latB, lonB);
      final (lat, lon) = moveByHeadingMeters(
        midLat,
        midLon,
        bearingAtoB - 90,
        5,
      );
      final d = GuidanceCalculator.deviationMeters(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        lat: lat,
        lon: lon,
        bearingDeg: bearingAtoB,
      );
      expect(d, greaterThan(0));
    });

    test('point right of line (A→B bearing) gives negative deviation', () {
      final midLat = (latA + latB) / 2;
      final midLon = (lonA + lonB) / 2;
      final bearingAtoB = bearingDegrees(latA, lonA, latB, lonB);
      final (lat, lon) = moveByHeadingMeters(
        midLat,
        midLon,
        bearingAtoB + 90,
        5,
      );
      final d = GuidanceCalculator.deviationMeters(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        lat: lat,
        lon: lon,
        bearingDeg: bearingAtoB,
      );
      expect(d, lessThan(0));
    });

    test('result is rounded to 2 decimal places', () {
      final d = GuidanceCalculator.deviationMeters(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        lat: (latA + latB) / 2,
        lon: (lonA + lonB) / 2 + 0.0001,
        bearingDeg: bearingDegrees(latA, lonA, latB, lonB),
      );
      final str = d.toString();
      final dot = str.indexOf('.');
      if (dot >= 0 && dot + 3 <= str.length) {
        expect(str.substring(dot + 1).length, lessThanOrEqualTo(2));
      }
    });
  });
}
