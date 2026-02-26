import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'demo_gnss_simulation.dart';
import '../utils/geo_utils.dart';

/// Состояние позиции: координаты, точность, скорость, курс.
class PositionUpdate {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double speedKmh;
  final double? heading; // bearing в градусах
  final DateTime timestamp;

  const PositionUpdate({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.speedKmh,
    this.heading,
    required this.timestamp,
  });

  bool get isAccurate => accuracyMeters <= 5.0;
  bool get isMoving => speedKmh > 0.1;
}

/// Сервис GPS: запрос прав, поток позиций, демо-режим и лог GNSS.
class LocationService {
  static const Duration _outputTick = Duration(milliseconds: 100);
  static const int _antiJitterWindowSize = 5;
  static const double _antiJitterBlendSpeedKmh = 4.0;
  StreamSubscription<Position>? _subscription;
  Timer? _outputTimer;
  final _controller = StreamController<PositionUpdate>.broadcast();
  final ListQueue<PositionUpdate> _antiJitterWindow = ListQueue<PositionUpdate>();
  Position? _lastPosition;
  PositionUpdate? _lastPositionUpdate;
  PositionUpdate? _latestRawUpdate;
  PositionUpdate? _prevRawUpdate;

  bool _demoMode = false;
  final DemoGnssSimulation _demoGnss = DemoGnssSimulation();

  Stream<PositionUpdate> get positionStream => _controller.stream;
  PositionUpdate? get lastPositionUpdate => _lastPositionUpdate;

  bool get demoMode => _demoMode;
  List<GnssLogEntry> get gnssLogEntries => _demoGnss.logEntries;
  Stream<List<GnssLogEntry>> get gnssLogStream => _demoGnss.logStream;

  void setDemoMode(bool value) {
    if (_demoMode == value) return;
    _demoMode = value;
    stopPositionUpdates();
  }

  void setDemoPath(double? latA, double? lonA, double? latB, double? lonB) {
    _demoGnss.setDemoPath(latA, lonA, latB, lonB);
  }

  /// Включить ручное управление трактором клавиатурой (стрелки / WASD).
  void setDemoManualMode(bool enabled) {
    _demoGnss.setManualMode(enabled);
  }

  bool get isDemoManualMode => _demoGnss.isManualMode;

  /// Обновить состояние клавиш для ручного управления.
  void updateDemoKeyState(DemoKeyState keys) {
    _demoGnss.updateKeyState(keys);
  }

  Future<bool> checkAndRequestPermission() async {
    if (_demoMode) return true;
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<bool> openAppSettings() async {
    if (kIsWeb) return false;
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  void startPositionUpdates() {
    if (_demoMode) {
      _outputTimer?.cancel();
      _demoGnss.startDemo((pos) {
        _lastPositionUpdate = pos;
        _controller.add(pos);
      });
      return;
    }
    if (_subscription != null) return;
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen((Position position) {
      final now = DateTime.now();
      final accuracy = position.accuracy;
      if (accuracy > 5.0) return;
      _lastPosition = position;
      final speedKmh = (position.speed >= 0 ? position.speed * 3.6 : 0.0);
      final raw = PositionUpdate(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: accuracy,
        speedKmh: speedKmh,
        heading: position.heading >= 0 ? position.heading : null,
        timestamp: now,
      );
      final filtered = _applyAntiJitter(raw);
      _prevRawUpdate = _latestRawUpdate;
      _latestRawUpdate = filtered;
      _emitRealOutputTick();
      _outputTimer ??= Timer.periodic(_outputTick, (_) => _emitRealOutputTick());
    }, onError: (e) {
      if (e != null) _controller.addError(e);
    });
  }

  PositionUpdate _applyAntiJitter(PositionUpdate raw) {
    _antiJitterWindow.addLast(raw);
    while (_antiJitterWindow.length > _antiJitterWindowSize) {
      _antiJitterWindow.removeFirst();
    }
    if (_antiJitterWindow.length < 3) return raw;

    final latValues = _antiJitterWindow.map((p) => p.latitude).toList()..sort();
    final lonValues = _antiJitterWindow.map((p) => p.longitude).toList()..sort();
    final medLat = latValues[latValues.length ~/ 2];
    final medLon = lonValues[lonValues.length ~/ 2];

    // На рабочей скорости уменьшаем задержку: смешиваем raw + median.
    final blend = (raw.speedKmh / _antiJitterBlendSpeedKmh).clamp(0.0, 1.0);
    final filteredLat = medLat + (raw.latitude - medLat) * blend;
    final filteredLon = medLon + (raw.longitude - medLon) * blend;

    final prevHeading = _latestRawUpdate?.heading;
    final heading = (raw.heading != null && raw.heading!.isFinite)
        ? raw.heading
        : (prevHeading != null && prevHeading.isFinite ? prevHeading : null);

    return PositionUpdate(
      latitude: filteredLat,
      longitude: filteredLon,
      accuracyMeters: raw.accuracyMeters,
      speedKmh: raw.speedKmh,
      heading: heading,
      timestamp: raw.timestamp,
    );
  }

  void _emitRealOutputTick() {
    final latest = _latestRawUpdate;
    if (latest == null) return;
    final now = DateTime.now();
    final pos = _predictPosition(latest, _prevRawUpdate, now);
    _lastPositionUpdate = pos;
    _demoGnss.addToLog(pos, isDemo: false);
    _controller.add(pos);
  }

  PositionUpdate _predictPosition(
    PositionUpdate latest,
    PositionUpdate? previous,
    DateTime now,
  ) {
    if (previous == null) {
      return PositionUpdate(
        latitude: latest.latitude,
        longitude: latest.longitude,
        accuracyMeters: latest.accuracyMeters,
        speedKmh: latest.speedKmh,
        heading: latest.heading,
        timestamp: now,
      );
    }

    final rawDtSec = latest.timestamp
        .difference(previous.timestamp)
        .inMilliseconds / 1000.0;
    if (rawDtSec <= 0) {
      return PositionUpdate(
        latitude: latest.latitude,
        longitude: latest.longitude,
        accuracyMeters: latest.accuracyMeters,
        speedKmh: latest.speedKmh,
        heading: latest.heading,
        timestamp: now,
      );
    }

    final dtFromLatestSec =
        now.difference(latest.timestamp).inMilliseconds / 1000.0;
    final predictSec = dtFromLatestSec.clamp(0.0, 1.5);
    final latPerSec = (latest.latitude - previous.latitude) / rawDtSec;
    final lonPerSec = (latest.longitude - previous.longitude) / rawDtSec;
    final lat = latest.latitude + latPerSec * predictSec;
    final lon = latest.longitude + lonPerSec * predictSec;
    final heading = latest.heading ??
        bearingDegrees(
          previous.latitude,
          previous.longitude,
          latest.latitude,
          latest.longitude,
        );
    final speedKmh = latest.speedKmh > 0
        ? latest.speedKmh
        : (haversineDistanceMeters(
                previous.latitude,
                previous.longitude,
                latest.latitude,
                latest.longitude,
              ) /
              rawDtSec) *
            3.6;

    return PositionUpdate(
      latitude: lat,
      longitude: lon,
      accuracyMeters: latest.accuracyMeters,
      speedKmh: speedKmh,
      heading: heading,
      timestamp: now,
    );
  }

  void stopPositionUpdates() {
    _demoGnss.stopDemo();
    _outputTimer?.cancel();
    _outputTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _antiJitterWindow.clear();
    _latestRawUpdate = null;
    _prevRawUpdate = null;
  }

  Position? get lastPosition => _lastPosition;

  void dispose() {
    stopPositionUpdates();
    _controller.close();
    _demoGnss.dispose();
  }
}
