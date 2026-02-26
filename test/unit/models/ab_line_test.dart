import 'package:flutter_test/flutter_test.dart';
import 'package:agrokilar_compass/models/ab_line.dart';

void main() {
  group('AbLine', () {
    test('toMap and fromMap roundtrip', () {
      final line = AbLine(
        id: 1,
        name: 'Тестовая линия',
        createdAt: DateTime(2024, 1, 15, 10, 30, 0),
        latA: 55.75,
        lonA: 37.62,
        latB: 55.752,
        lonB: 37.626,
        widthMeters: 2.5,
        totalAreaHa: 10.5,
      );
      final map = line.toMap();
      final restored = AbLine.fromMap(map);
      expect(restored.id, line.id);
      expect(restored.name, line.name);
      expect(restored.createdAt, line.createdAt);
      expect(restored.latA, line.latA);
      expect(restored.lonA, line.lonA);
      expect(restored.latB, line.latB);
      expect(restored.lonB, line.lonB);
      expect(restored.widthMeters, line.widthMeters);
      expect(restored.totalAreaHa, line.totalAreaHa);
    });

    test('fromMap without id', () {
      final map = {
        'name': 'New',
        'created_at': '2024-01-01T00:00:00.000',
        'lat_a': 55.0,
        'lon_a': 37.0,
        'lat_b': 55.001,
        'lon_b': 37.001,
        'width_meters': 2.0,
      };
      final line = AbLine.fromMap(map);
      expect(line.id, isNull);
      expect(line.totalAreaHa, isNull);
    });

    test('copyWith changes single field', () {
      final line = AbLine(
        id: 1,
        name: 'Original',
        createdAt: DateTime(2024, 1, 1),
        latA: 55.75,
        lonA: 37.62,
        latB: 55.752,
        lonB: 37.626,
        widthMeters: 2.0,
      );
      final updated = line.copyWith(name: 'Updated');
      expect(updated.name, 'Updated');
      expect(updated.id, line.id);
      expect(updated.latA, line.latA);
    });
  });
}
