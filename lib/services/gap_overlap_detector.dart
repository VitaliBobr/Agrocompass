import '../models/track_point.dart';
import '../utils/geo_utils.dart';

/// Результат детекции пропусков и перекрытий (ТЗ 5.7).
enum GapOverlapStatus { ok, gap, overlap }

/// Детектор пропусков и перекрытий между проходами.
/// ТЗ 5.7: пропуск если расстояние > width+0.2 м, перекрытие если < width-0.1 м.
class GapOverlapDetector {
  /// Анализирует текущую позицию относительно трека.
  /// Возвращает gap если расстояние до ближайшей точки предыдущего прохода > width+0.2.
  /// Возвращает overlap если < width-0.1.
  static GapOverlapStatus detect({
    required List<TrackPoint> trackPoints,
    required double lat,
    required double lon,
    required double widthMeters,
    int lastPointsAsCurrentPass = 20,
  }) {
    if (trackPoints.length < lastPointsAsCurrentPass + 10) return GapOverlapStatus.ok;
    final prevPoints = trackPoints.sublist(
      0,
      trackPoints.length - lastPointsAsCurrentPass,
    );
    if (prevPoints.isEmpty) return GapOverlapStatus.ok;

    double minDist = double.infinity;
    for (final p in prevPoints) {
      final d = haversineDistanceMeters(lat, lon, p.lat, p.lon);
      if (d < minDist) minDist = d;
    }
    if (minDist > widthMeters + 0.2) return GapOverlapStatus.gap;
    if (minDist < widthMeters - 0.1 && minDist > 0.5) return GapOverlapStatus.overlap;
    return GapOverlapStatus.ok;
  }
}
