import '../utils/app_logger.dart';
import '../utils/debug_probe.dart';

/// Модель AB-линии для параллельного вождения.
class AbLine {
  final int? id;
  final String name;
  final DateTime createdAt;
  final double latA;
  final double lonA;
  final double latB;
  final double lonB;
  final double widthMeters;
  /// Общая площадь поля в га (опционально, для % выполнения).
  final double? totalAreaHa;

  const AbLine({
    this.id,
    required this.name,
    required this.createdAt,
    required this.latA,
    required this.lonA,
    required this.latB,
    required this.lonB,
    required this.widthMeters,
    this.totalAreaHa,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'lat_a': latA,
      'lon_a': lonA,
      'lat_b': latB,
      'lon_b': lonB,
      'width_meters': widthMeters,
      'total_area_ha': totalAreaHa,
    };
  }

  static AbLine fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic v, double fallback, String field) {
      if (v is num) return v.toDouble();
      debugProbeLog(
        runId: 'run1',
        hypothesisId: 'H2',
        location: 'ab_line.dart:46',
        message: 'Invalid numeric field in AbLine.fromMap',
        data: {'field': field, 'valueType': v?.runtimeType.toString(), 'isNull': v == null},
      );
      AppLogger.warn('ab_line.parse.$field', 'Missing numeric field, fallback used', data: {'value': v, 'fallback': fallback});
      return fallback;
    }

    String asString(dynamic v, String fallback) {
      if (v is String && v.trim().isNotEmpty) return v;
      debugProbeLog(
        runId: 'run1',
        hypothesisId: 'H2',
        location: 'ab_line.dart:58',
        message: 'Invalid string field in AbLine.fromMap',
        data: {'field': 'name', 'valueType': v?.runtimeType.toString(), 'isNull': v == null},
      );
      AppLogger.warn('ab_line.parse.name', 'Missing name, fallback used', data: {'value': v});
      return fallback;
    }

    DateTime parseTs(dynamic v) {
      if (v is String && v.isNotEmpty) {
        try {
          return DateTime.parse(v);
        } catch (e, st) {
          AppLogger.warn('ab_line.parse.created_at', 'Failed to parse created_at', error: e, stackTrace: st, data: {'value': v});
        }
      }
      AppLogger.warn('ab_line.parse.created_at', 'Missing created_at, fallback epoch', data: {'row': map});
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return AbLine(
      id: (map['id'] as num?)?.toInt(),
      name: asString(map['name'], 'Без названия'),
      createdAt: parseTs(map['created_at']),
      latA: asDouble(map['lat_a'], 0, 'lat_a'),
      lonA: asDouble(map['lon_a'], 0, 'lon_a'),
      latB: asDouble(map['lat_b'], 0, 'lat_b'),
      lonB: asDouble(map['lon_b'], 0, 'lon_b'),
      widthMeters: asDouble(map['width_meters'], 2.0, 'width_meters'),
      totalAreaHa: map['total_area_ha'] is num ? (map['total_area_ha'] as num).toDouble() : null,
    );
  }

  AbLine copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    double? latA,
    double? lonA,
    double? latB,
    double? lonB,
    double? widthMeters,
    double? totalAreaHa,
  }) {
    return AbLine(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      latA: latA ?? this.latA,
      lonA: lonA ?? this.lonA,
      latB: latB ?? this.latB,
      lonB: lonB ?? this.lonB,
      widthMeters: widthMeters ?? this.widthMeters,
      totalAreaHa: totalAreaHa ?? this.totalAreaHa,
    );
  }
}
