import '../utils/geo_utils.dart';

/// Расчёт отклонения от AB-линии с учётом направления движения.
class GuidanceCalculator {
  /// Отклонение в метрах: отрицательное — влево, положительное — вправо.
  /// [bearingDeg] — текущий курс в градусах (0–360), для определения направления A->B или B->A.
  static double deviationMeters({
    required double latA,
    required double lonA,
    required double latB,
    required double lonB,
    required double lat,
    required double lon,
    required double bearingDeg,
  }) {
    final directionAtoB = isDirectionAtoB(latA, lonA, latB, lonB, bearingDeg);
    final d = deviationFromAbLineMeters(
      latA: latA,
      lonA: lonA,
      latB: latB,
      lonB: lonB,
      lat: lat,
      lon: lon,
      directionAtoB: directionAtoB,
    );
    return double.parse(d.toStringAsFixed(2));
  }
}
