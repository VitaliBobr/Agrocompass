import 'package:flutter_test/flutter_test.dart';
import 'package:agrokilar_compass/utils/format_utils.dart';

void main() {
  group('formatDistanceKm', () {
    test('formats with 2 decimal places', () {
      expect(formatDistanceKm(1.5), '1.50');
      expect(formatDistanceKm(0), '0.00');
      expect(formatDistanceKm(12.345), '12.35');
    });
  });

  group('formatAreaHa', () {
    test('formats with 3 decimal places', () {
      expect(formatAreaHa(1.5), '1.500');
      expect(formatAreaHa(0), '0.000');
      expect(formatAreaHa(0.1234), '0.123');
    });
  });

  group('formatDeviationMeters', () {
    test('formats with 2 decimal places', () {
      expect(formatDeviationMeters(0.15), '0.15');
      expect(formatDeviationMeters(-0.3), '-0.30');
    });
  });

  group('formatDuration', () {
    test('minutes only when < 1 hour', () {
      expect(formatDuration(const Duration(minutes: 30)), '30 мин');
      expect(formatDuration(const Duration(minutes: 0)), '0 мин');
    });

    test('hours and minutes when >= 1 hour', () {
      expect(formatDuration(const Duration(hours: 1, minutes: 30)), '1 ч 30 мин');
      expect(formatDuration(const Duration(hours: 2, minutes: 5)), '2 ч 5 мин');
    });
  });
}
