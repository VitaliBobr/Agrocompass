import '../utils/app_logger.dart';
import '../utils/debug_probe.dart';

/// Точка трека с временной меткой и опциональной скоростью/курсом.
class TrackPoint {
  final int? id;
  final int sessionId;
  final double lat;
  final double lon;
  final DateTime timestamp;
  final double? speedKmh;
  final double? bearing;
  final double? deviationMeters;

  const TrackPoint({
    this.id,
    required this.sessionId,
    required this.lat,
    required this.lon,
    required this.timestamp,
    this.speedKmh,
    this.bearing,
    this.deviationMeters,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'lat': lat,
      'lon': lon,
      'timestamp': timestamp.toIso8601String(),
      'speed_kmh': speedKmh,
      'bearing': bearing,
      'deviation_meters': deviationMeters,
    };
  }

  static TrackPoint fromMap(Map<String, dynamic> map) {
    double? asDouble(dynamic v, String field, {bool required = false}) {
      if (v is num) return v.toDouble();
      if (v == null && !required) return null;
      debugProbeLog(
        runId: 'run1',
        hypothesisId: 'H1',
        location: 'track_point.dart:40',
        message: 'Invalid numeric field in TrackPoint.fromMap',
        data: {
          'field': field,
          'valueType': v?.runtimeType.toString(),
          'isNull': v == null,
        },
      );
      if (v != null) {
        AppLogger.warn('track_point.parse.$field', 'Expected number, got ${v.runtimeType}', data: {'value': v});
      } else {
        AppLogger.warn('track_point.parse.$field', 'Null numeric field', data: {'row': map});
      }
      return null;
    }
    DateTime parseTs(dynamic v) {
      if (v is String && v.isNotEmpty) {
        try {
          return DateTime.parse(v);
        } catch (e, st) {
          debugProbeLog(
            runId: 'run1',
            hypothesisId: 'H1',
            location: 'track_point.dart:62',
            message: 'Failed timestamp parse in TrackPoint.fromMap',
            data: {'value': v.toString()},
          );
          AppLogger.warn('track_point.parse.timestamp', 'Failed to parse timestamp', error: e, stackTrace: st, data: {'value': v});
        }
      }
      AppLogger.warn('track_point.parse.timestamp', 'Missing timestamp, fallback epoch', data: {'row': map});
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return TrackPoint(
      id: (map['id'] as num?)?.toInt(),
      sessionId: (map['session_id'] as num?)?.toInt() ?? -1,
      lat: asDouble(map['lat'], 'lat', required: true) ?? double.nan,
      lon: asDouble(map['lon'], 'lon', required: true) ?? double.nan,
      timestamp: parseTs(map['timestamp']),
      speedKmh: asDouble(map['speed_kmh'], 'speed_kmh'),
      bearing: asDouble(map['bearing'], 'bearing'),
      deviationMeters: asDouble(map['deviation_meters'], 'deviation_meters'),
    );
  }
}
