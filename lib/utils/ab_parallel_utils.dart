import 'dart:math' as math;

/// Возвращает AB-отрезок, смещённый перпендикулярно на [offsetMeters] (в метрах).
/// Положительное смещение = влево относительно направления A->B.
({double latA, double lonA, double latB, double lonB}) offsetAbSegment({
  required double latA,
  required double lonA,
  required double latB,
  required double lonB,
  required double offsetMeters,
}) {
  const R = 6371000.0;
  final lat0 = (latA + latB) / 2;
  final cosLat0 = math.cos(lat0 * math.pi / 180).clamp(0.01, 1.0);
  final dLat = (latB - latA) * math.pi / 180;
  final dLon = (lonB - lonA) * math.pi / 180;
  final x = R * cosLat0 * dLon;
  final y = R * dLat;
  final len = math.sqrt(x * x + y * y).clamp(1e-6, double.infinity);
  final ux = x / len;
  final uy = y / len;
  // Перпендикуляр влево
  final px = -uy;
  final py = ux;
  final ox = px * offsetMeters;
  final oy = py * offsetMeters;

  final dLatOff = (oy / R) * 180 / math.pi;
  final dLonOff = (ox / (R * cosLat0)) * 180 / math.pi;

  return (
    latA: latA + dLatOff,
    lonA: lonA + dLonOff,
    latB: latB + dLatOff,
    lonB: lonB + dLonOff,
  );
}

/// Генерирует параллельные линии (по обе стороны) вокруг AB.
/// Возвращает список пар точек (A',B') для линий.
List<({double latA, double lonA, double latB, double lonB})> generateParallels({
  required double latA,
  required double lonA,
  required double latB,
  required double lonB,
  required double widthMeters,
  int countEachSide = 5,
}) {
  final out = <({double latA, double lonA, double latB, double lonB})>[];
  for (int i = -countEachSide; i <= countEachSide; i++) {
    final off = i * widthMeters;
    out.add(offsetAbSegment(
      latA: latA,
      lonA: lonA,
      latB: latB,
      lonB: lonB,
      offsetMeters: off,
    ));
  }
  return out;
}

