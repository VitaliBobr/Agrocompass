import 'dart:async';
import '../database/database_helper.dart';
import '../models/ab_line.dart';
import '../models/work_session.dart';
import '../models/track_point.dart';
import '../utils/geo_utils.dart';
import 'guidance_calculator.dart';
import 'location_service.dart';

/// Состояние записи трека: путь (км), площадь (га).
class TrackRecordingState {
  final bool isRecording;
  final double distanceKm;
  final double areaHa;
  final int? currentSessionId;
  final WorkSession? currentSession;

  const TrackRecordingState({
    this.isRecording = false,
    this.distanceKm = 0,
    this.areaHa = 0,
    this.currentSessionId,
    this.currentSession,
  });
}

/// Сервис записи трека: старт/стоп сессии, накопление точек с фильтром скорости > 0.5 км/ч,
/// расчёт пути и площади, сохранение в БД порциями.
/// Использует переданный [LocationService] (тот же, что на главном экране/демо), иначе запись не получит позиции.
class TrackRecorderService {
  LocationService? _location;
  final DatabaseHelper _db = DatabaseHelper();

  void setLocationService(LocationService location) {
    _location = location;
  }
  StreamSubscription<PositionUpdate>? _sub;
  WorkSession? _currentSession;
  final _buffer = <TrackPoint>[];
  static const int _bufferSize = 50;
  static const double _boomBackOffsetMeters = 2.0;
  static const double _maxPointJumpMeters = 80.0;
  double _distanceKm = 0;
  double _lastLat = 0, _lastLon = 0;
  bool _hasLast = false;
  AbLine? _currentAbLine;
  double _widthMeters = 0;
  bool _hasExplicitWidth = false;

  final _stateController = StreamController<TrackRecordingState>.broadcast();
  Stream<TrackRecordingState> get stateStream => _stateController.stream;
  TrackRecordingState get state => TrackRecordingState(
        isRecording: _currentSession != null,
        distanceKm: _distanceKm,
        areaHa: _areaHa,
        currentSessionId: _currentSession?.id,
        currentSession: _currentSession,
      );

  double get _areaHa => _widthMeters > 0 ? (_distanceKm * 1000 * _widthMeters) / 10000 : 0;

  static const double _defaultWidthMeters = 2.0;

  /// Установить текущую AB-линию (для ширины захвата и при сохранении сессии).
  void setAbLine(AbLine? line) {
    _currentAbLine = line;
    if (!_hasExplicitWidth) {
      _widthMeters = line?.widthMeters ?? _defaultWidthMeters;
    }
  }

  /// Установить рабочую ширину захвата (до старта или во время работы).
  void setWorkingWidthMeters(double widthMeters) {
    if (!widthMeters.isFinite || widthMeters <= 0) return;
    _widthMeters = widthMeters;
    _hasExplicitWidth = true;
    _emitState();
  }

  double get workingWidthMeters => _widthMeters;

  bool get hasWorkingWidth => _widthMeters > 0;

  /// Сбросить ручную ширину к ширине выбранной AB-линии (или дефолту).
  void resetWorkingWidthToLine() {
    _hasExplicitWidth = false;
    _widthMeters = _currentAbLine?.widthMeters ?? _defaultWidthMeters;
    _emitState();
  }

  /// Начать запись. Создаётся новая сессия.
  Future<void> startRecording() async {
    if (_currentSession != null) return;
    if (_location == null) return;
    final session = WorkSession(
      abLineId: _currentAbLine?.id,
      startTime: DateTime.now(),
      distanceKm: 0,
      areaHa: 0,
    );
    final id = await _db.insertWorkSession(session);
    _currentSession = session.copyWith(id: id);
    _distanceKm = 0;
    _hasLast = false;
    _buffer.clear();
    _sub = _location!.positionStream.listen(_onPosition);
    _emitState();
  }

  void _onPosition(PositionUpdate pos) {
    if (_currentSession == null) return;
    if (!_isValidLatLon(pos.latitude, pos.longitude)) return;
    // По ТЗ: расстояние считать только при скорости > 0.5 км/ч
    final speed = pos.speedKmh;
    final bearing = pos.heading;
    var trackLat = pos.latitude;
    var trackLon = pos.longitude;
    if (bearing != null && bearing.isFinite) {
      final shifted = moveByHeadingMeters(
        pos.latitude,
        pos.longitude,
        (bearing + 180.0) % 360.0,
        _boomBackOffsetMeters,
      );
      trackLat = shifted.$1;
      trackLon = shifted.$2;
      if (!_isValidLatLon(trackLat, trackLon)) {
        trackLat = pos.latitude;
        trackLon = pos.longitude;
      }
    }
    double? deviation;
    if (_currentAbLine != null && bearing != null) {
      deviation = GuidanceCalculator.deviationMeters(
        latA: _currentAbLine!.latA,
        lonA: _currentAbLine!.lonA,
        latB: _currentAbLine!.latB,
        lonB: _currentAbLine!.lonB,
        lat: trackLat,
        lon: trackLon,
        bearingDeg: bearing,
      );
    }
    final point = TrackPoint(
      sessionId: _currentSession!.id!,
      lat: trackLat,
      lon: trackLon,
      timestamp: pos.timestamp,
      speedKmh: speed,
      bearing: bearing,
      deviationMeters: deviation,
    );
    if (_hasLast) {
      final jump = haversineDistanceMeters(_lastLat, _lastLon, trackLat, trackLon);
      if (jump > _maxPointJumpMeters) {
        _lastLat = trackLat;
        _lastLon = trackLon;
        _buffer.add(point);
        if (_buffer.length >= _bufferSize) _flushBuffer();
        _emitState();
        return;
      }
      if (speed > 0.5) {
        _distanceKm += jump / 1000;
      }
    }
    _lastLat = trackLat;
    _lastLon = trackLon;
    _hasLast = true;
    _buffer.add(point);
    if (_buffer.length >= _bufferSize) _flushBuffer();
    _emitState();
  }

  bool _isValidLatLon(double lat, double lon) {
    return lat.isFinite &&
        lon.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lon >= -180 &&
        lon <= 180;
  }

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty) return;
    await _db.insertTrackPoints(List.from(_buffer));
    _buffer.clear();
  }

  void _emitState() {
    if (_currentSession != null) {
      _stateController.add(TrackRecordingState(
        isRecording: true,
        distanceKm: _distanceKm,
        areaHa: _areaHa,
        currentSessionId: _currentSession!.id,
        currentSession: _currentSession!.copyWith(
          distanceKm: _distanceKm,
          areaHa: _areaHa,
        ),
      ));
    } else {
      _stateController.add(TrackRecordingState(
        isRecording: false,
        distanceKm: _distanceKm,
        areaHa: _areaHa,
      ));
    }
  }

  /// Остановить запись и сохранить сессию.
  Future<void> stopRecording() async {
    await _sub?.cancel();
    _sub = null;
    await _flushBuffer();
    if (_currentSession != null) {
      await _db.updateWorkSession(_currentSession!.copyWith(
        endTime: DateTime.now(),
        distanceKm: _distanceKm,
        areaHa: _areaHa,
      ));
      _currentSession = null;
    }
    _hasLast = false;
    _emitState();
  }

  /// Текущие точки трека в памяти + загрузить из БД для текущей сессии (для отрисовки карты).
  Future<List<TrackPoint>> getCurrentTrackPoints() async {
    if (_currentSession == null) return [];
    final fromDb = await _db.getTrackPointsBySessionId(_currentSession!.id!);
    if (_buffer.isEmpty) return fromDb;
    return [...fromDb, ..._buffer];
  }

  /// Видимый трек на карте:
  /// - все завершённые/текущие сессии независимо от выбранной AB-линии
  /// - плюс точки текущего буфера записи
  ///
  /// Это позволяет не терять отрисованный трек после повторного нажатия "СТАРТ".
  Future<List<TrackPoint>> getVisibleTrackPoints() async {
    final sessions = await _db.getAllWorkSessions();
    if (sessions.isEmpty) {
      if (_buffer.isEmpty) return [];
      return List<TrackPoint>.from(_buffer);
    }

    final result = <TrackPoint>[];
    for (final session in sessions) {
      final sid = session.id;
      if (sid == null) continue;
      final points = await _db.getTrackPointsBySessionId(sid);
      result.addAll(points);
      if (_currentSession?.id == sid && _buffer.isNotEmpty) {
        result.addAll(_buffer);
      }
    }
    return result;
  }

  /// Сегменты видимого трека для отрисовки без "склейки" между сессиями.
  ///
  /// Каждый элемент списка — отдельная непрерывная полилиния одной сессии.
  Future<List<List<TrackPoint>>> getVisibleTrackSegments() async {
    final sessions = await _db.getAllWorkSessions();
    if (sessions.isEmpty) {
      if (_buffer.isEmpty) return [];
      return [List<TrackPoint>.from(_buffer)];
    }

    // Для корректной геометрии рисуем в хронологическом порядке.
    sessions.sort((a, b) => a.startTime.compareTo(b.startTime));

    final segments = <List<TrackPoint>>[];
    for (final session in sessions) {
      final sid = session.id;
      if (sid == null) continue;
      final points = await _db.getTrackPointsBySessionId(sid);
      final segment = <TrackPoint>[...points];
      if (_currentSession?.id == sid && _buffer.isNotEmpty) {
        segment.addAll(_buffer);
      }
      if (segment.isNotEmpty) {
        segments.add(segment);
      }
    }
    return segments;
  }

  void dispose() {
    _sub?.cancel();
    _stateController.close();
  }
}
