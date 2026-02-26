import 'dart:async';
import 'location_service.dart';
import '../utils/geo_utils.dart';

/// Управление клавиатурой в ручном режиме демо.
class DemoKeyState {
  bool forward = false;
  bool back = false;
  bool left = false;
  bool right = false;
}

/// Запись лога GNSS (реальная или демо).
class GnssLogEntry {
  final DateTime time;
  final double lat;
  final double lon;
  final double accuracyMeters;
  final double speedKmh;
  final double? heading;
  final bool isDemo;

  const GnssLogEntry({
    required this.time,
    required this.lat,
    required this.lon,
    required this.accuracyMeters,
    required this.speedKmh,
    this.heading,
    this.isDemo = false,
  });

  String toNmeaStyle() {
    // Упрощённая строка в стиле NMEA: время, координаты, точность, скорость, курс
    final t = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lon >= 0 ? 'E' : 'W';
    return 'DEMO,$t,${lat.abs().toStringAsFixed(6)}$ns,${lon.abs().toStringAsFixed(6)}$ew,${accuracyMeters.toStringAsFixed(1)}m,${speedKmh.toStringAsFixed(1)}km/h,${heading?.toStringAsFixed(0) ?? "—"}°';
  }
}

/// Демо-симуляция движения и лог GNSS.
class DemoGnssSimulation {
  Timer? _timer;
  final _log = <GnssLogEntry>[];
  static const int _maxLogEntries = 1000;
  static const int _hz = 10;
  static const Duration _tick = Duration(milliseconds: 100);
  final _logController = StreamController<List<GnssLogEntry>>.broadcast();

  double _simLat = 55.75;
  double _simLon = 37.62;
  double _simHeading = 45.0;
  double _simSpeedKmh = 5.0;
  int _simTicks = 0;
  double? _demoLatA;
  double? _demoLonA;
  double? _demoLatB;
  double? _demoLonB;

  bool _manualMode = false;
  final DemoKeyState _keyState = DemoKeyState();

  Stream<List<GnssLogEntry>> get logStream => _logController.stream;

  /// Включить ручное управление клавиатурой (стрелки / WASD).
  void setManualMode(bool enabled) {
    _manualMode = enabled;
    if (!enabled) {
      _keyState.forward = _keyState.back = _keyState.left = _keyState.right = false;
    }
  }

  bool get isManualMode => _manualMode;

  /// Обновить состояние клавиш (вызывать при нажатии/отпускании).
  void updateKeyState(DemoKeyState keys) {
    _keyState.forward = keys.forward;
    _keyState.back = keys.back;
    _keyState.left = keys.left;
    _keyState.right = keys.right;
  }
  List<GnssLogEntry> get logEntries => List.unmodifiable(_log);

  /// Задать маршрут демо (по умолчанию отрезок A→B→A).
  void setDemoPath(double? latA, double? lonA, double? latB, double? lonB) {
    _demoLatA = latA;
    _demoLonA = lonA;
    _demoLatB = latB;
    _demoLonB = lonB;
    if (latA != null && lonA != null) {
      _simLat = latA;
      _simLon = lonA;
    }
  }

  /// Добавить запись в лог (из реального GPS или демо).
  void addToLog(PositionUpdate pos, {bool isDemo = false}) {
    _log.insert(0, GnssLogEntry(
      time: pos.timestamp,
      lat: pos.latitude,
      lon: pos.longitude,
      accuracyMeters: pos.accuracyMeters,
      speedKmh: pos.speedKmh,
      heading: pos.heading,
      isDemo: isDemo,
    ));
    while (_log.length > _maxLogEntries) {
      _log.removeLast();
    }
    _logController.add(logEntries);
  }

  /// Запуск демо-симуляции: эмитит PositionUpdate с частотой 10 Гц в [sink].
  void startDemo(void Function(PositionUpdate) sink) {
    stopDemo();
    final latA = _demoLatA ?? 55.75;
    final lonA = _demoLonA ?? 37.62;
    final latB = _demoLatB ?? 55.752;
    final lonB = _demoLonB ?? 37.626;
    _simLat = latA;
    _simLon = lonA;
    _simTicks = 0;

    _timer = Timer.periodic(_tick, (_) {
      const tickSec = 1.0 / _hz;
      const turnDegPerSec = 45.0;
      const moveMeterPerSec = 5.0; // ~18 км/ч

      if (_manualMode) {
        // Ручное управление клавиатурой
        if (_keyState.left) _simHeading = (_simHeading - turnDegPerSec * tickSec + 360) % 360;
        if (_keyState.right) _simHeading = (_simHeading + turnDegPerSec * tickSec) % 360;
        double moveM = 0;
        if (_keyState.forward) moveM = moveMeterPerSec * tickSec;
        if (_keyState.back) moveM -= moveMeterPerSec * tickSec;
        if (moveM != 0) {
          final moved = moveByHeadingMeters(_simLat, _simLon, _simHeading, moveM);
          _simLat = moved.$1;
          _simLon = moved.$2;
        }
        _simSpeedKmh = (_keyState.forward || _keyState.back)
            ? moveMeterPerSec * 3.6
            : 0.0;
      } else {
        // Автоматический маршрут A→B→A
        const totalTicks = 120 * _hz;
        final t = _simTicks % totalTicks;
        double fraction;
        if (t < 60 * _hz) {
          fraction = t / (60 * _hz);
          _simHeading = bearingDegrees(latA, lonA, latB, lonB);
        } else {
          fraction = (120 * _hz - t) / (60 * _hz);
          _simHeading = (bearingDegrees(latA, lonA, latB, lonB) + 180) % 360;
        }
        _simLat = latA + fraction * (latB - latA);
        _simLon = lonA + fraction * (lonB - lonA);
        _simTicks++;
      }

      final pos = PositionUpdate(
        latitude: _simLat,
        longitude: _simLon,
        accuracyMeters: 1.5,
        speedKmh: _simSpeedKmh,
        heading: _simHeading,
        timestamp: DateTime.now(),
      );
      addToLog(pos, isDemo: true);
      sink(pos);
    });
  }

  void stopDemo() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stopDemo();
    _logController.close();
  }
}
