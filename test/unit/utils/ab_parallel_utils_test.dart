import 'package:flutter_test/flutter_test.dart';
import 'package:agrokilar_compass/utils/ab_parallel_utils.dart';

void main() {
  const latA = 55.75;
  const lonA = 37.62;
  const latB = 55.752;
  const lonB = 37.626;

  group('offsetAbSegment', () {
    test('offset 0 returns same segment', () {
      final r = offsetAbSegment(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        offsetMeters: 0,
      );
      expect(r.latA, closeTo(latA, 1e-6));
      expect(r.lonA, closeTo(lonA, 1e-6));
      expect(r.latB, closeTo(latB, 1e-6));
      expect(r.lonB, closeTo(lonB, 1e-6));
    });

    test('positive offset moves segment left (perpendicular)', () {
      final r = offsetAbSegment(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        offsetMeters: 10,
      );
      // Смещённый отрезок не совпадает с исходным
      expect(r.latA != latA || r.lonA != lonA, isTrue);
      expect(r.latB != latB || r.lonB != lonB, isTrue);
    });

    test('negative offset moves opposite direction', () {
      final rPos = offsetAbSegment(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        offsetMeters: 10,
      );
      final rNeg = offsetAbSegment(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        offsetMeters: -10,
      );
      // Симметрично относительно исходной линии
      expect(rPos.latA, isNot(closeTo(rNeg.latA, 1e-8)));
    });
  });

  group('generateParallels', () {
    test('returns 2*countEachSide + 1 lines', () {
      final lines = generateParallels(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        widthMeters: 2.0,
        countEachSide: 5,
      );
      expect(lines.length, 11);
    });

    test('countEachSide 0 returns single center line', () {
      final lines = generateParallels(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        widthMeters: 2.0,
        countEachSide: 0,
      );
      expect(lines.length, 1);
    });

    test('center line (i=0) matches offset 0', () {
      final lines = generateParallels(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        widthMeters: 2.0,
        countEachSide: 2,
      );
      final center = lines[2];
      final expected = offsetAbSegment(
        latA: latA,
        lonA: lonA,
        latB: latB,
        lonB: lonB,
        offsetMeters: 0,
      );
      expect(center.latA, closeTo(expected.latA, 1e-9));
      expect(center.latB, closeTo(expected.latB, 1e-9));
    });
  });
}
