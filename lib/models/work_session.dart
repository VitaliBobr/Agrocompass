import '../utils/app_logger.dart';
import '../utils/debug_probe.dart';

/// Сессия записи трека (один цикл Старт–Стоп).
class WorkSession {
  final int? id;
  final int? abLineId;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceKm;
  final double areaHa;
  final String? abLineName;
  final double? widthMeters;

  const WorkSession({
    this.id,
    this.abLineId,
    required this.startTime,
    this.endTime,
    this.distanceKm = 0,
    this.areaHa = 0,
    this.abLineName,
    this.widthMeters,
  });

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'ab_line_id': abLineId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'distance_km': distanceKm,
      'area_ha': areaHa,
    };
  }

  static WorkSession fromMap(Map<String, dynamic> map, {String? abLineName, double? widthMeters}) {
    DateTime parseTs(dynamic v) {
      if (v is String && v.isNotEmpty) {
        try {
          return DateTime.parse(v);
        } catch (e, st) {
          debugProbeLog(
            runId: 'run1',
            hypothesisId: 'H3',
            location: 'work_session.dart:46',
            message: 'Failed timestamp parse in WorkSession.fromMap',
            data: {'value': v.toString()},
          );
          AppLogger.warn('work_session.parse.timestamp', 'Failed to parse timestamp', error: e, stackTrace: st, data: {'value': v});
        }
      }
      debugProbeLog(
        runId: 'run1',
        hypothesisId: 'H3',
        location: 'work_session.dart:57',
        message: 'Missing timestamp in WorkSession.fromMap (fallback epoch)',
        data: {'isNull': v == null, 'valueType': v?.runtimeType.toString()},
      );
      AppLogger.warn('work_session.parse.timestamp', 'Missing timestamp, fallback epoch', data: {'row': map});
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return WorkSession(
      id: (map['id'] as num?)?.toInt(),
      abLineId: (map['ab_line_id'] as num?)?.toInt(),
      startTime: parseTs(map['start_time']),
      endTime: map['end_time'] != null ? parseTs(map['end_time']) : null,
      distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0,
      areaHa: (map['area_ha'] as num?)?.toDouble() ?? 0,
      abLineName: abLineName,
      widthMeters: widthMeters,
    );
  }

  WorkSession copyWith({
    int? id,
    int? abLineId,
    DateTime? startTime,
    DateTime? endTime,
    double? distanceKm,
    double? areaHa,
    String? abLineName,
    double? widthMeters,
  }) {
    return WorkSession(
      id: id ?? this.id,
      abLineId: abLineId ?? this.abLineId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distanceKm: distanceKm ?? this.distanceKm,
      areaHa: areaHa ?? this.areaHa,
      abLineName: abLineName ?? this.abLineName,
      widthMeters: widthMeters ?? this.widthMeters,
    );
  }
}
