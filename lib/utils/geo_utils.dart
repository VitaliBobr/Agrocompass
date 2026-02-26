import 'dart:math' as math;

/// Расстояние между двумя точками по формуле Haversine (метры).
double haversineDistanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const R = 6371000.0; // радиус Земли в метрах
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

double _toRad(double deg) => deg * math.pi / 180;

/// Азимут от точки 1 к точке 2 в градусах (0–360).
double bearingDegrees(double lat1, double lon1, double lat2, double lon2) {
  final dLon = _toRad(lon2 - lon1);
  final y = math.sin(dLon) * math.cos(_toRad(lat2));
  final x = math.cos(_toRad(lat1)) * math.sin(_toRad(lat2)) -
      math.sin(_toRad(lat1)) * math.cos(_toRad(lat2)) * math.cos(dLon);
  var b = math.atan2(y, x) * 180 / math.pi;
  if (b < 0) b += 360;
  return b;
}

/// Отклонение от AB-линии в метрах.
/// Отрицательное = влево от направления движения, положительное = вправо.
/// [directionAtoB] true = движение от A к B, false = от B к A.
double deviationFromAbLineMeters({
  required double latA,
  required double lonA,
  required double latB,
  required double lonB,
  required double lat,
  required double lon,
  required bool directionAtoB,
}) {
  // Проекция в локальные метры относительно точки A (достаточно для поля ~км).
  final (dxB, dyB) = _latLonToMeters(latA, lonA, latB, lonB);
  final (dx, dy) = _latLonToMeters(latA, lonA, lat, lon);
  // Вектор AB в метрах
  final ax = dxB;
  final ay = dyB;
  final lenSq = ax * ax + ay * ay;
  if (lenSq < 1e-10) return 0;
  // Проекция точки на прямую: t = (P-A)·(B-A) / |B-A|^2
  final t = (dx * ax + dy * ay) / lenSq;
  final projX = t * ax;
  final projY = t * ay;
  // Перпендикуляр от точки до прямой (вектор от проекции к точке)
  final perpX = dx - projX;
  final perpY = dy - projY;
  // Расстояние до прямой
  final distance = math.sqrt(perpX * perpX + perpY * perpY);
  // Знак: "слева" от направления A->B значит положительный перпендикуляр (поворот налево).
  // В 2D: направление A->B = (ax,ay). Перпендикуляр "влево" = (-ay, ax). Скалярное произведение (perpX, perpY)·(-ay, ax) даёт знак.
  var sign = perpX * (-ay) + perpY * ax;
  if (sign < 0) sign = -1;
  if (sign > 0) sign = 1;
  if (sign == 0) sign = 1;
  var deviation = distance * sign;
  if (!directionAtoB) deviation = -deviation;
  return deviation;
}

/// Преобразование разницы координат в метры (приближённо).
(double, double) _latLonToMeters(double lat0, double lon0, double lat1, double lon1) {
  const R = 6371000.0;
  final dLat = _toRad(lat1 - lat0);
  final dLon = _toRad(lon1 - lon0);
  final y = R * dLat;
  final x = R * math.cos(_toRad(lat0)) * dLon;
  return (x, y);
}

/// Смещение точки по курсу [headingDeg] (0=север, 90=восток) на [meters] метров.
/// Возвращает (lat, lon).
(double, double) moveByHeadingMeters(double lat, double lon, double headingDeg, double meters) {
  const mPerDegLat = 111320.0;
  final h = _toRad(headingDeg);
  final cosLat = math.cos(_toRad(lat)).clamp(0.01, 1.0);
  final northM = math.cos(h) * meters;
  final eastM = math.sin(h) * meters;
  return (
    lat + northM / mPerDegLat,
    lon + eastM / (mPerDegLat * cosLat),
  );
}

/// Определение направления движения: от A к B или от B к A по курсу [bearingDeg].
/// Возвращает true если ближе к направлению A->B.
bool isDirectionAtoB(double latA, double lonA, double latB, double lonB, double bearingDeg) {
  final bearingAtoB = bearingDegrees(latA, lonA, latB, lonB);
  var diff = (bearingDeg - bearingAtoB).abs();
  if (diff > 180) diff = 360 - diff;
  final bearingBtoA = (bearingAtoB + 180) % 360;
  var diffBtoA = (bearingDeg - bearingBtoA).abs();
  if (diffBtoA > 180) diffBtoA = 360 - diffBtoA;
  return diff <= diffBtoA;
}
