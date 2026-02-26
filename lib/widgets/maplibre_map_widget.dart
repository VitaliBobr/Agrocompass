import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/ab_line.dart';
import '../models/equipment_profile.dart';
import '../models/track_point.dart';
import '../services/gap_overlap_detector.dart';
import '../services/location_service.dart';
import '../services/track_recorder_service.dart';
import '../utils/ab_parallel_utils.dart';
import '../utils/app_logger.dart';
import '../utils/debug_probe.dart';
import '../utils/geo_utils.dart';

class MapLibreMapWidget extends StatefulWidget {
  final bool hasGpsSignal;
  final AbLine? abLine;
  final TrackRecorderService trackRecorder;
  final LocationService locationService;
  final double headingDegrees;
  final double speedKmh;
  final bool is3D;
  final bool follow;
  /// Текущий проход (смещение параллели): 0 = AB, 1 = +1 ширина, -1 = -1 ширина.
  final int passIndex;
  /// ТЗ 11: Для просмотра старого трека — сегменты для отображения (без записи).
  final List<List<TrackPoint>>? staticTrackSegments;
  /// Ширина полосы (м) при просмотре без AB-линии.
  final double? staticTrackWidthMeters;
  /// P1: Подсветка пропусков/перекрытий на карте (красный/жёлтый).
  final GapOverlapStatus gapOverlapStatus;
  /// GlobalKey для RepaintBoundary — экспорт снимка карты.
  final GlobalKey? repaintBoundaryKey;
  /// Профиль техники (трактор/агрегат) для отрисовки силуэта на карте.
  final EquipmentProfile? equipmentProfile;
  /// Включённость секций штанги по отдельности (по порядку слева направо). Если null — все включены.
  final List<bool>? sectionEnabled;
  /// Рисовать ли трек (заливку обработанной площади) на карте. false — трек не отображается.
  final bool showTrack;

  const MapLibreMapWidget({
    super.key,
    required this.hasGpsSignal,
    required this.abLine,
    required this.trackRecorder,
    required this.locationService,
    required this.headingDegrees,
    required this.speedKmh,
    required this.is3D,
    required this.follow,
    required this.passIndex,
    this.staticTrackSegments,
    this.staticTrackWidthMeters,
    this.gapOverlapStatus = GapOverlapStatus.ok,
    this.repaintBoundaryKey,
    this.equipmentProfile,
    this.sectionEnabled,
    this.showTrack = true,
  });

  @override
  State<MapLibreMapWidget> createState() => _MapLibreMapWidgetState();
}

class _MapLibreMapWidgetState extends State<MapLibreMapWidget> {
  static const String _styleUrl = 'https://demotiles.maplibre.org/style.json';
  static const String _trackFillSourceId = 'agrokilar-track-fill';
  static const String _trackFillLayerId = 'agrokilar-track-fill-layer';
  static const String _trackCenterSourceId = 'agrokilar-track-center';
  static const String _trackCenterLayerId = 'agrokilar-track-center-layer';
  /// ТЗ 1.3.9: Минимальный офлайн-стиль (без тайлов) — тёмный фон, AB-линия и трек рисуются поверх.
  static const String _offlineStyle = '''
{"version":8,"sources":{},"layers":[{"id":"background","type":"background","paint":{"background-color":"#1a1a2e"}}]}
''';
  static const CameraPosition _fallbackCamera =
      CameraPosition(target: LatLng(55.75, 37.62), zoom: 16);

  final _controllerCompleter = Completer<MapLibreMapController>();
  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  bool _useOfflineStyle = false;

  StreamSubscription<PositionUpdate>? _posSub;
  StreamSubscription<TrackRecordingState>? _trackSub;
  LatLng? _current;
  LatLng? _smoothedCurrent;
  PositionUpdate? _lastFix;
  LatLng? _prevFix;
  Timer? _renderTimer;
  bool _renderBusy = false;
  int _lastCameraUpdateMs = 0;
  bool _userInteracting = false;
  bool _programmaticCameraMove = false;
  double? _cameraZoom;
  int _suspendFollowUntilMs = 0;

  Fill? _tractorFill;
  Fill? _tractorHoodFill;
  Fill? _tractorCabFill;
  Fill? _rearLeftWheelFill;
  Fill? _rearRightWheelFill;
  Fill? _frontLeftWheelFill;
  Fill? _frontRightWheelFill;
  Fill? _rearLeftHubFill;
  Fill? _rearRightHubFill;
  Fill? _frontLeftHubFill;
  Fill? _frontRightHubFill;
  Line? _tractorBodyBorder;
  Line? _tractorHoodBorder;
  Line? _tractorCabBorder;
  Line? _headingLine;
  Line? _boom;
  final List<Line> _nozzles = [];
  Line? _abLine;
  final List<Line> _parallelLines = [];
  bool _trackCenterLayerAdded = false;
  final List<Line> _trackBorders = [];
  Timer? _trackSyncTimer;
  bool _trackSyncRunning = false;
  bool _trackSyncQueued = false;
  String? _lastTrackFingerprint;
  int _tractorRenderTicks = 0;
  int _suspectStyleUpdateTicks = 0;
  /// P1: Подсветка пропуска (красный) / перекрытия (жёлтый) на карте.
  Fill? _gapOverlapFill;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  double get _effectiveWidthMeters =>
      widget.staticTrackWidthMeters ?? widget.abLine?.widthMeters ?? 2.0;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then((result) {
      final offline = result.length == 1 && result.first == ConnectivityResult.none;
      if (mounted && offline) {
        setState(() => _useOfflineStyle = true);
      }
    });
    // P0: Слушаем изменения сети — переключаемся на офлайн-стиль при потере сети.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      final offline = result.length == 1 && result.first == ConnectivityResult.none;
      if (mounted && _useOfflineStyle != offline) {
        setState(() => _useOfflineStyle = offline);
      }
    });
    if (widget.staticTrackSegments == null) {
      _posSub = widget.locationService.positionStream.listen((p) {
        _prevFix = _lastFix != null ? LatLng(_lastFix!.latitude, _lastFix!.longitude) : null;
        _current = LatLng(p.latitude, p.longitude);
        _lastFix = p;
        if (_styleLoaded) {
          _syncTractorAndBoom();
        }
        if (widget.follow) {
          _updateCamera();
        }
      });
    }

    if (widget.staticTrackSegments == null) {
      _trackSub = widget.trackRecorder.stateStream.listen((_) {
        if (_styleLoaded) {
          _scheduleTrackSync();
        }
      });
    }

    // Претензия 5: 10 Гц обновление + сглаживание позиции (Lerp) для плавности (только при live-режиме)
    if (widget.staticTrackSegments == null) {
      _renderTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!_styleLoaded) return;
        final fix = _lastFix;
        if (fix == null) return;
        final cur = LatLng(fix.latitude, fix.longitude);
        if (!_isValidLatLng(cur)) return;
        // LocationService уже выдаёт интерполированные тики.
        // Дополнительная предикция тут вызывала рывки.
        _current = cur;
        _smoothedCurrent = _lerpLatLng(_smoothedCurrent ?? cur, cur, 0.25);
        _syncTractorAndBoom();
        if (widget.follow) {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (nowMs - _lastCameraUpdateMs >= 200) {
            _lastCameraUpdateMs = nowMs;
            _updateCamera();
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant MapLibreMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.follow != widget.follow ||
        oldWidget.is3D != widget.is3D ||
        oldWidget.headingDegrees != widget.headingDegrees) {
      if (widget.follow) {
        _updateCamera();
      }
      if (_styleLoaded) {
        _syncTractorAndBoom();
      }
    }

    if (oldWidget.abLine?.id != widget.abLine?.id && _styleLoaded) {
      _syncAbAndParallels();
      _scheduleTrackSync();
    } else if (oldWidget.abLine?.widthMeters != widget.abLine?.widthMeters && _styleLoaded) {
      _scheduleTrackSync();
    }
    if (oldWidget.passIndex != widget.passIndex && _styleLoaded) {
      // При авто-переключении проходов пауза follow вызывала "лок" камеры.
      // Обновляем только направляющие, без длительной блокировки слежения.
      _syncAbAndParallels();
    }
    if (oldWidget.equipmentProfile?.id != widget.equipmentProfile?.id && _styleLoaded) {
      _syncTractorAndBoom();
    }
    if (_styleLoaded && _sectionEnabledChanged(oldWidget.sectionEnabled, widget.sectionEnabled)) {
      _scheduleTrackSync();
    }
    if (oldWidget.showTrack != widget.showTrack && _styleLoaded) {
      _scheduleTrackSync();
    }
    if (oldWidget.gapOverlapStatus != widget.gapOverlapStatus && _styleLoaded) {
      _syncGapOverlapFill();
    }
  }

  LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  bool _isValidLatLng(LatLng p) {
    return p.latitude.isFinite &&
        p.longitude.isFinite &&
        p.latitude >= -90 &&
        p.latitude <= 90 &&
        p.longitude >= -180 &&
        p.longitude <= 180;
  }

  bool _sectionEnabledChanged(List<bool>? a, List<bool>? b) {
    if (a == b) return false;
    if (a == null || b == null) return true;
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) if (a[i] != b[i]) return true;
    return false;
  }

  Future<void> _updateCamera() async {
    if (!_styleLoaded) return;
    if (DateTime.now().millisecondsSinceEpoch < _suspendFollowUntilMs) return;
    if (_userInteracting) return;
    final c = _controller ?? await _controllerCompleter.future;
    final target = (_smoothedCurrent ?? _current) ??
        (widget.abLine != null
            ? LatLng(
                (widget.abLine!.latA + widget.abLine!.latB) / 2,
                (widget.abLine!.lonA + widget.abLine!.lonB) / 2,
              )
            : _fallbackCamera.target);

    final pitch = widget.is3D ? 60.0 : 0.0;
    // ТЗ 5.8: Угол камеры задаётся статически по GNSS каждый тик обновления
    final bearing = widget.follow ? (_lastFix?.heading ?? widget.headingDegrees) : 0.0;

    final zoom = _cameraZoom ?? (widget.is3D ? 17.0 : 16.0);
    _programmaticCameraMove = true;
    try {
      // Претензия 5: animateCamera для плавности вместо moveCamera
      await c.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: zoom,
            bearing: bearing,
            tilt: pitch,
          ),
        ),
        duration: const Duration(milliseconds: 150),
      );
    } finally {
      // Дадим onCameraMove шанс отработать.
      Future.microtask(() => _programmaticCameraMove = false);
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    if (!_controllerCompleter.isCompleted) {
      _controllerCompleter.complete(controller);
    }
  }

  Future<void> _syncAll() async {
    await _syncAbAndParallels();
    await _syncTractorAndBoom();
    await _syncTrackNow();
  }

  void _scheduleTrackSync() {
    // Throttle: не чаще 300 мс, чтобы не перегружать web-плагин карты.
    if (_trackSyncTimer?.isActive ?? false) {
      _trackSyncQueued = true;
      return;
    }
    _trackSyncTimer = Timer(const Duration(milliseconds: 300), () async {
      _trackSyncTimer = null;
      await _syncTrackNow();
      if (_trackSyncQueued) {
        _trackSyncQueued = false;
        _scheduleTrackSync();
      }
    });
  }

  Future<void> _syncTrackNow() async {
    if (_trackSyncRunning) {
      _trackSyncQueued = true;
      return;
    }
    _trackSyncRunning = true;
    try {
      await _syncTrack();
    } finally {
      _trackSyncRunning = false;
      if (_trackSyncQueued) {
        _trackSyncQueued = false;
        _scheduleTrackSync();
      }
    }
  }

  /// Вспомогательная точка в локальной системе техники:
  /// forwardM > 0 - вперед по курсу, leftM > 0 - влево от курса.
  LatLng _offsetByHeadingAxes(
    LatLng center,
    double headingDeg, {
    required double forwardM,
    required double leftM,
  }) {
    const mPerDegLat = 111320.0;
    final h = headingDeg * math.pi / 180;
    final cosLat = math.cos(center.latitude * math.pi / 180).clamp(0.01, 1.0);
    final north = math.cos(h);
    final east = math.sin(h);
    final leftNorth = math.sin(h);
    final leftEast = -math.cos(h);
    final dn = north * forwardM + leftNorth * leftM;
    final de = east * forwardM + leftEast * leftM;
    return LatLng(
      center.latitude + dn / mPerDegLat,
      center.longitude + de / (mPerDegLat * cosLat),
    );
  }

  List<LatLng> _wheelRect(
    LatLng tractorCenter,
    double headingDeg, {
    required double axleForwardM,
    required double sideOffsetM,
    required double lengthM,
    required double widthM,
  }) {
    final wheelCenter = _offsetByHeadingAxes(
      tractorCenter,
      headingDeg,
      forwardM: axleForwardM,
      leftM: sideOffsetM,
    );
    return _rotatedRectPoints(
      wheelCenter,
      headingDeg,
      lengthM: lengthM,
      widthM: widthM,
    );
  }

  /// Прямоугольник в локальной системе техники:
  /// [forwardOffsetM] > 0 смещает центр прямоугольника к носу.
  List<LatLng> _rotatedRectPoints(
    LatLng center,
    double headingDeg, {
    required double lengthM,
    required double widthM,
    double forwardOffsetM = 0.0,
  }) {
    const mPerDegLat = 111320.0;
    final h = headingDeg * math.pi / 180;
    final cosLat = math.cos(center.latitude * math.pi / 180).clamp(0.01, 1.0);
    final north = math.cos(h);
    final east = math.sin(h);
    final leftNorth = math.sin(h);
    final leftEast = -math.cos(h);

    final halfL = lengthM / 2;
    final halfW = widthM / 2;

    LatLng _pt(double fwdM, double leftM) {
      final n = north * fwdM + leftNorth * leftM;
      final e = east * fwdM + leftEast * leftM;
      return LatLng(
        center.latitude + n / mPerDegLat,
        center.longitude + e / (mPerDegLat * cosLat),
      );
    }

    final f = halfL + forwardOffsetM;
    final b = -halfL + forwardOffsetM;
    return [
      _pt(f, halfW),
      _pt(f, -halfW),
      _pt(b, -halfW),
      _pt(b, halfW),
      _pt(f, halfW),
    ];
  }

  /// Штанга как поперечная балка полной ширины агрегата.
  /// Центр штанги расположен немного позади трактора, чтобы ширина была
  /// визуально читаемой на карте.
  List<LatLng>? _boomBarPoints(LatLng center, double headingDeg, double widthMeters) {
    if (widthMeters <= 0) return null;
    const mPerDegLat = 111320.0;
    final h = headingDeg * math.pi / 180;
    final cosLat = math.cos(center.latitude * math.pi / 180).clamp(0.01, 1.0);

    // Смещаем центр штанги назад на 2 м вдоль направления движения.
    const backOffsetM = 2.0;
    final backNorth = -math.cos(h) * backOffsetM;
    final backEast = -math.sin(h) * backOffsetM;
    final boomCenter = LatLng(
      center.latitude + backNorth / mPerDegLat,
      center.longitude + backEast / (mPerDegLat * cosLat),
    );

    // Левый/правый край: перпендикуляр к курсу.
    final half = widthMeters / 2;
    final leftNorth = math.sin(h) * half;
    final leftEast = -math.cos(h) * half;
    final left = LatLng(
      boomCenter.latitude + leftNorth / mPerDegLat,
      boomCenter.longitude + leftEast / (mPerDegLat * cosLat),
    );
    final right = LatLng(
      boomCenter.latitude - leftNorth / mPerDegLat,
      boomCenter.longitude - leftEast / (mPerDegLat * cosLat),
    );
    return [left, right];
  }

  List<LatLng> _headingLinePoints(LatLng center, double headingDeg, double lengthMeters) {
    const mPerDegLat = 111320.0;
    final h = headingDeg * math.pi / 180;
    final cosLat = math.cos(center.latitude * math.pi / 180).clamp(0.01, 1.0);
    final northM = math.cos(h) * lengthMeters;
    final eastM = math.sin(h) * lengthMeters;
    final endLat = center.latitude + northM / mPerDegLat;
    final endLon = center.longitude + eastM / (mPerDegLat * cosLat);
    return [center, LatLng(endLat, endLon)];
  }

  Future<void> _syncTractorAndBoom() async {
    if (_renderBusy) return;
    _renderBusy = true;
    try {
    final c = _controller ?? await _controllerCompleter.future;
    final center = _smoothedCurrent ?? _current;
    if (center == null) return;
      _tractorRenderTicks++;
      if (_tractorRenderTicks % 25 == 0) {
        debugProbeLog(
          runId: 'run3',
          hypothesisId: 'H7',
          location: 'maplibre_map_widget.dart:syncTractorAndBoom',
          message: 'Frequent map updates tick',
          data: {
            'tick': _tractorRenderTicks,
            'hasHeadingLine': _headingLine != null,
            'hasBoom': _boom != null,
            'nozzlesCount': _nozzles.length,
          },
        );
      }

    // Плоский силуэт "как трактор": корпус + капот + кабина + колеса (из профиля техники).
    final profile = widget.equipmentProfile ?? EquipmentProfile.farmer();
    double heading = _lastFix?.heading ?? widget.headingDegrees;
    if (_prevFix != null && (heading == 0 || heading == widget.headingDegrees)) {
      final bearing = bearingDegrees(
        _prevFix!.latitude, _prevFix!.longitude,
        center.latitude, center.longitude,
      );
      if (bearing.isFinite) heading = bearing;
    }
    final body = _rotatedRectPoints(
      center,
      heading,
      lengthM: profile.bodyLengthM,
      widthM: profile.bodyWidthM,
      forwardOffsetM: profile.bodyForwardOffsetM,
    );
    final cab = _rotatedRectPoints(
      center,
      heading,
      lengthM: profile.cabLengthM,
      widthM: profile.cabWidthM,
      forwardOffsetM: profile.cabForwardOffsetM,
    );
    final hood = _rotatedRectPoints(
      center,
      heading,
      lengthM: profile.hoodLengthM,
      widthM: profile.hoodWidthM,
      forwardOffsetM: profile.hoodForwardOffsetM,
    );
    final rearLeftWheel = _wheelRect(
      center,
      heading,
      axleForwardM: profile.rearLeftWheel.axleForwardM,
      sideOffsetM: profile.rearLeftWheel.sideOffsetM,
      lengthM: profile.rearLeftWheel.lengthM,
      widthM: profile.rearLeftWheel.widthM,
    );
    final rearRightWheel = _wheelRect(
      center,
      heading,
      axleForwardM: profile.rearRightWheel.axleForwardM,
      sideOffsetM: profile.rearRightWheel.sideOffsetM,
      lengthM: profile.rearRightWheel.lengthM,
      widthM: profile.rearRightWheel.widthM,
    );
    final frontLeftWheel = _wheelRect(
      center,
      heading,
      axleForwardM: profile.frontLeftWheel.axleForwardM,
      sideOffsetM: profile.frontLeftWheel.sideOffsetM,
      lengthM: profile.frontLeftWheel.lengthM,
      widthM: profile.frontLeftWheel.widthM,
    );
    final frontRightWheel = _wheelRect(
      center,
      heading,
      axleForwardM: profile.frontRightWheel.axleForwardM,
      sideOffsetM: profile.frontRightWheel.sideOffsetM,
      lengthM: profile.frontRightWheel.lengthM,
      widthM: profile.frontRightWheel.widthM,
    );
    final rearLeftHub = _wheelRect(
      center,
      heading,
      axleForwardM: profile.rearLeftHub.axleForwardM,
      sideOffsetM: profile.rearLeftHub.sideOffsetM,
      lengthM: profile.rearLeftHub.lengthM,
      widthM: profile.rearLeftHub.widthM,
    );
    final rearRightHub = _wheelRect(
      center,
      heading,
      axleForwardM: profile.rearRightHub.axleForwardM,
      sideOffsetM: profile.rearRightHub.sideOffsetM,
      lengthM: profile.rearRightHub.lengthM,
      widthM: profile.rearRightHub.widthM,
    );
    final frontLeftHub = _wheelRect(
      center,
      heading,
      axleForwardM: profile.frontLeftHub.axleForwardM,
      sideOffsetM: profile.frontLeftHub.sideOffsetM,
      lengthM: profile.frontLeftHub.lengthM,
      widthM: profile.frontLeftHub.widthM,
    );
    final frontRightHub = _wheelRect(
      center,
      heading,
      axleForwardM: profile.frontRightHub.axleForwardM,
      sideOffsetM: profile.frontRightHub.sideOffsetM,
      lengthM: profile.frontRightHub.lengthM,
      widthM: profile.frontRightHub.widthM,
    );
    if (_tractorFill == null) {
      _tractorFill = await c.addFill(
        FillOptions(
          geometry: [body],
          fillColor: profile.bodyColor,
          fillOpacity: 1.0,
        ),
      );
    } else {
      _suspectStyleUpdateTicks++;
      if (_suspectStyleUpdateTicks % 20 == 0) {
        debugProbeLog(
          runId: 'run4',
          hypothesisId: 'H8',
          location: 'maplibre_map_widget.dart:updateFill.tractor',
          message: 'Updating tractor fill with geometry-only options',
          data: {
            'tick': _suspectStyleUpdateTicks,
            'bodyPoints': body.length,
          },
        );
      }
      await c.updateFill(
        _tractorFill!,
        FillOptions(
          geometry: [body],
          fillColor: profile.bodyColor,
          fillOpacity: 1.0,
        ),
      );
    }
    if (_tractorBodyBorder == null) {
      _tractorBodyBorder = await c.addLine(
        LineOptions(
          geometry: body,
          lineColor: profile.borderColor,
          lineWidth: 1.8,
        ),
      );
    } else {
      await c.updateLine(
        _tractorBodyBorder!,
        LineOptions(
          geometry: body,
          lineColor: profile.borderColor,
          lineWidth: 1.8,
        ),
      );
    }
    if (_tractorHoodFill == null) {
      _tractorHoodFill = await c.addFill(
        FillOptions(
          geometry: [hood],
          fillColor: profile.hoodColor,
          fillOpacity: 1.0,
        ),
      );
    } else {
      await c.updateFill(
        _tractorHoodFill!,
        FillOptions(
          geometry: [hood],
          fillColor: profile.hoodColor,
          fillOpacity: 1.0,
        ),
      );
    }
    if (_tractorHoodBorder == null) {
      _tractorHoodBorder = await c.addLine(
        LineOptions(
          geometry: hood,
          lineColor: profile.borderColor,
          lineWidth: 1.4,
        ),
      );
    } else {
      await c.updateLine(
        _tractorHoodBorder!,
        LineOptions(
          geometry: hood,
          lineColor: profile.borderColor,
          lineWidth: 1.4,
        ),
      );
    }
    if (_tractorCabFill == null) {
      _tractorCabFill = await c.addFill(
        FillOptions(
          geometry: [cab],
          fillColor: profile.cabColor,
          fillOpacity: 1.0,
        ),
      );
    } else {
      await c.updateFill(
        _tractorCabFill!,
        FillOptions(
          geometry: [cab],
          fillColor: profile.cabColor,
          fillOpacity: 1.0,
        ),
      );
    }
    if (_tractorCabBorder == null) {
      _tractorCabBorder = await c.addLine(
        LineOptions(
          geometry: cab,
          lineColor: profile.cabBorderColor,
          lineWidth: 2.0,
        ),
      );
    } else {
      await c.updateLine(
        _tractorCabBorder!,
        LineOptions(
          geometry: cab,
          lineColor: profile.cabBorderColor,
          lineWidth: 2.0,
        ),
      );
    }
    Future<void> upsertWheel(
      Fill? wheel,
      List<LatLng> geom,
      String color,
      void Function(Fill) assign,
    ) async {
      if (wheel == null) {
        final created = await c.addFill(
          FillOptions(
            geometry: [geom],
            fillColor: color,
            fillOpacity: 1.0,
          ),
        );
        assign(created);
      } else {
        await c.updateFill(
          wheel,
          FillOptions(
            geometry: [geom],
            fillColor: color,
            fillOpacity: 1.0,
          ),
        );
      }
    }

    await upsertWheel(_rearLeftWheelFill, rearLeftWheel, profile.tireColor, (v) => _rearLeftWheelFill = v);
    await upsertWheel(_rearRightWheelFill, rearRightWheel, profile.tireColor, (v) => _rearRightWheelFill = v);
    await upsertWheel(_frontLeftWheelFill, frontLeftWheel, profile.tireColor, (v) => _frontLeftWheelFill = v);
    await upsertWheel(_frontRightWheelFill, frontRightWheel, profile.tireColor, (v) => _frontRightWheelFill = v);
    await upsertWheel(_rearLeftHubFill, rearLeftHub, profile.hubColor, (v) => _rearLeftHubFill = v);
    await upsertWheel(_rearRightHubFill, rearRightHub, profile.hubColor, (v) => _rearRightHubFill = v);
    await upsertWheel(_frontLeftHubFill, frontLeftHub, profile.hubColor, (v) => _frontLeftHubFill = v);
    await upsertWheel(_frontRightHubFill, frontRightHub, profile.hubColor, (v) => _frontRightHubFill = v);

    // Направление движения (красная линия от трактора вперёд)
    final dir = _headingLinePoints(center, heading, 6.0);
    if (_headingLine == null) {
      _headingLine = await c.addLine(
        LineOptions(
          geometry: dir,
          lineColor: '#E53935',
          lineWidth: 3,
        ),
      );
    } else {
      _suspectStyleUpdateTicks++;
      if (_suspectStyleUpdateTicks % 20 == 0) {
        debugProbeLog(
          runId: 'run4',
          hypothesisId: 'H8',
          location: 'maplibre_map_widget.dart:updateLine.heading',
          message: 'Updating heading line with geometry-only options',
          data: {
            'tick': _suspectStyleUpdateTicks,
            'dirPoints': dir.length,
          },
        );
      }
      await c.updateLine(
        _headingLine!,
        LineOptions(
          geometry: dir,
          lineColor: '#E53935',
          lineWidth: 3,
        ),
      );
    }

    // Штанга + сопла
    final width = _effectiveWidthMeters;
    final boomPts = _boomBarPoints(center, heading, width);
    if (boomPts == null) return;

    if (_boom == null) {
      _boom = await c.addLine(
        LineOptions(
          geometry: boomPts,
          lineColor: '#FFFFFF',
          lineWidth: 6,
        ),
      );
    } else {
        _suspectStyleUpdateTicks++;
        if (_suspectStyleUpdateTicks % 20 == 0) {
          debugProbeLog(
            runId: 'run4',
            hypothesisId: 'H8',
            location: 'maplibre_map_widget.dart:updateLine.boom',
            message: 'Updating boom line with geometry-only options',
            data: {
              'tick': _suspectStyleUpdateTicks,
              'boomPoints': boomPts.length,
            },
          );
        }
        await c.updateLine(
          _boom!,
          LineOptions(
            geometry: boomPts,
            lineColor: '#FFFFFF',
            lineWidth: 6,
          ),
        );
    }

    // P1: Обновляем подсветку пропуска/перекрытия при движении
    if (widget.gapOverlapStatus != GapOverlapStatus.ok) {
      _syncGapOverlapFill();
    }

    // Сопла (секции): короткие сегменты перпендикулярно штанге; цвет по включённости секции.
    final sectionOn = widget.sectionEnabled;
    final h = heading * math.pi / 180;
    const mPerDegLat = 111320.0;
    final cosLat = math.cos(center.latitude * math.pi / 180).clamp(0.01, 1.0);
    const nozzleLenM = 0.5;
    final nozzleLat = nozzleLenM / mPerDegLat;
    final nozzleLon = nozzleLenM / (mPerDegLat * cosLat);
    for (var i = 1; i <= 5; i++) {
      final enabled = sectionOn == null || (sectionOn.length >= i && sectionOn[i - 1]);
      final lineColor = enabled ? '#4CAF50' : '#757575';
      final t = i / 6;
      final cx = boomPts[0].latitude + (boomPts[1].latitude - boomPts[0].latitude) * t;
      final cy = boomPts[0].longitude + (boomPts[1].longitude - boomPts[0].longitude) * t;
      // Короткий штрих по направлению движения (перпендикуляр к штанге).
      final nLat = math.cos(h) * nozzleLat;
      final nLon = math.sin(h) * nozzleLon;
      final geom = [LatLng(cx - nLat, cy - nLon), LatLng(cx + nLat, cy + nLon)];
      if (_nozzles.length < 5) {
        _nozzles.add(await c.addLine(
          LineOptions(
            geometry: geom,
            lineColor: lineColor,
            lineWidth: 3,
          ),
        ));
      } else {
        _suspectStyleUpdateTicks++;
        if (_suspectStyleUpdateTicks % 20 == 0 && i == 1) {
          debugProbeLog(
            runId: 'run4',
            hypothesisId: 'H8',
            location: 'maplibre_map_widget.dart:updateLine.nozzles',
            message: 'Updating nozzle lines with geometry-only options',
            data: {
              'tick': _suspectStyleUpdateTicks,
              'nozzlesCount': _nozzles.length,
            },
          );
        }
        await c.updateLine(
          _nozzles[i - 1],
          LineOptions(
            geometry: geom,
            lineColor: lineColor,
            lineWidth: 3,
          ),
        );
      }
    }
    } finally {
      _renderBusy = false;
    }
  }

  Future<void> _syncAbAndParallels() async {
    final c = _controller ?? await _controllerCompleter.future;

    // очистка
    if (_abLine != null) {
      await c.removeLine(_abLine!);
      _abLine = null;
    }
    for (final l in _parallelLines) {
      await c.removeLine(l);
    }
    _parallelLines.clear();

    final ab = widget.abLine;
    if (ab == null) return;

    final abIsActive = widget.passIndex == 0;
    // ТЗ 5.3: AB-линия — жирная жёлтая линия от А до Б
    _abLine = await c.addLine(
      LineOptions(
        geometry: [LatLng(ab.latA, ab.lonA), LatLng(ab.latB, ab.lonB)],
        lineColor: abIsActive ? '#FDD835' : '#F9A825', // активная — ярко жёлтая
        lineWidth: 6,
      ),
    );

    // "Бесконечные" направляющие:
    // рисуем фиксированное окно линий вокруг текущего прохода.
    // При смене passIndex окно сдвигается, поэтому крайняя линия с одной
    // стороны исчезает, а с другой появляется новая.
    const countEachSide = 5;
    final start = widget.passIndex - countEachSide;
    final end = widget.passIndex + countEachSide;
    for (int i = start; i <= end; i++) {
      if (i == 0) continue; // AB рисуется отдельно
      final p = offsetAbSegment(
        latA: ab.latA,
        lonA: ab.lonA,
        latB: ab.latB,
        lonB: ab.lonB,
        offsetMeters: i * ab.widthMeters,
      );
      final isActive = i == widget.passIndex;
      _parallelLines.add(await c.addLine(
        LineOptions(
          geometry: [LatLng(p.latA, p.lonA), LatLng(p.latB, p.lonB)],
          lineColor: isActive ? '#FDD835' : '#0D47A1', // активная параллель — жёлтая
          lineWidth: isActive ? 4 : 2,
        ),
      ));
    }
  }

  List<LatLng> _buildStripPolygon(List<LatLng> points, double widthMeters) {
    if (points.isEmpty || widthMeters <= 0) return [];
    if (points.length == 1) return _buildSinglePointPolygon(points.first, widthMeters);
    // Удаляем подряд идущие одинаковые точки, чтобы не ломать нормали.
    final clean = <LatLng>[];
    for (final p in points) {
      if (clean.isEmpty) {
        clean.add(p);
        continue;
      }
      final prev = clean.last;
      final d = haversineDistanceMeters(
        prev.latitude,
        prev.longitude,
        p.latitude,
        p.longitude,
      );
      if (d > 0.05) clean.add(p); // 5 см
    }
    if (clean.length < 2) return _buildSinglePointPolygon(clean.first, widthMeters);

    const mPerDegLat = 111320.0;
    final half = widthMeters / 2;
    final miterLimit = half * 2.0;
    final origin = clean.first;
    final cos0 = math.cos(origin.latitude * math.pi / 180).clamp(0.01, 1.0);

    // Перевод в локальные метры ENU относительно первой точки.
    final local = clean.map((p) {
      final x = (p.longitude - origin.longitude) * mPerDegLat * cos0; // east
      final y = (p.latitude - origin.latitude) * mPerDegLat; // north
      return (x, y);
    }).toList();

    (double, double) _norm((double, double) v) {
      final len = math.sqrt(v.$1 * v.$1 + v.$2 * v.$2);
      if (len < 1e-9) return (0.0, 0.0);
      return (v.$1 / len, v.$2 / len);
    }

    (double, double) _normalLeft((double, double) dir) => (-dir.$2, dir.$1);

    final leftLocal = <(double, double)>[];
    final rightLocal = <(double, double)>[];

    for (int i = 0; i < local.length; i++) {
      final p = local[i];
      (double, double) n;
      double off = half;

      if (i == 0) {
        final d = _norm((local[1].$1 - p.$1, local[1].$2 - p.$2));
        n = _normalLeft(d);
      } else if (i == local.length - 1) {
        final d = _norm((p.$1 - local[i - 1].$1, p.$2 - local[i - 1].$2));
        n = _normalLeft(d);
      } else {
        final dPrev = _norm((p.$1 - local[i - 1].$1, p.$2 - local[i - 1].$2));
        final dNext = _norm((local[i + 1].$1 - p.$1, local[i + 1].$2 - p.$2));
        final nPrev = _normalLeft(dPrev);
        final nNext = _normalLeft(dNext);
        final miter = _norm((nPrev.$1 + nNext.$1, nPrev.$2 + nNext.$2));
        if (miter.$1 == 0 && miter.$2 == 0) {
          n = nNext;
        } else {
          n = miter;
          final denom = (n.$1 * nNext.$1 + n.$2 * nNext.$2).abs();
          if (denom > 1e-6) {
            off = (half / denom).clamp(half, miterLimit);
          }
        }
      }

      leftLocal.add((p.$1 + n.$1 * off, p.$2 + n.$2 * off));
      rightLocal.add((p.$1 - n.$1 * off, p.$2 - n.$2 * off));
    }

    LatLng _toLatLng((double, double) enu) {
      final lat = origin.latitude + enu.$2 / mPerDegLat;
      final lon = origin.longitude + enu.$1 / (mPerDegLat * cos0);
      return LatLng(lat, lon);
    }

    final left = leftLocal.map(_toLatLng).toList();
    final right = rightLocal.map(_toLatLng).toList();
    return [...left, ...right.reversed];
  }

  /// P1: Синхронизация подсветки пропуска (красный) / перекрытия (жёлтый) на карте.
  Future<void> _syncGapOverlapFill() async {
    final c = _controller ?? await _controllerCompleter.future;
    if (widget.gapOverlapStatus == GapOverlapStatus.ok) {
      if (_gapOverlapFill != null) {
        await c.removeFill(_gapOverlapFill!);
        _gapOverlapFill = null;
      }
      return;
    }
    final center = _smoothedCurrent ?? _current;
    if (center == null) return;
    const radiusM = 4.0;
    final poly = _buildSinglePointPolygon(center, radiusM * 2);
    final color = widget.gapOverlapStatus == GapOverlapStatus.gap ? '#E53935' : '#FDD835';
    if (_gapOverlapFill == null) {
      _gapOverlapFill = await c.addFill(
        FillOptions(
          geometry: [poly],
          fillColor: color,
          fillOpacity: 0.5,
        ),
      );
    } else {
      await c.updateFill(_gapOverlapFill!, FillOptions(
        geometry: [poly],
        fillColor: color,
        fillOpacity: 0.5,
      ));
    }
  }

  List<LatLng> _buildSinglePointPolygon(LatLng center, double widthMeters) {
    const mPerDegLat = 111320.0;
    final half = widthMeters / 2;
    final cosLat = math.cos(center.latitude * math.pi / 180).clamp(0.01, 1.0);
    final dLat = half / mPerDegLat;
    final dLon = half / (mPerDegLat * cosLat);
    return [
      LatLng(center.latitude - dLat, center.longitude - dLon),
      LatLng(center.latitude - dLat, center.longitude + dLon),
      LatLng(center.latitude + dLat, center.longitude + dLon),
      LatLng(center.latitude + dLat, center.longitude - dLon),
    ];
  }

  /// Прямоугольник полосы для отрезка (a,b) между двумя перпендикулярными смещениями (метры).
  List<LatLng>? _buildSegmentBand(LatLng a, LatLng b, double offset1M, double offset2M) {
    if (!_isValidLatLng(a) || !_isValidLatLng(b)) return null;
    const mPerDegLat = 111320.0;
    final midLat = (a.latitude + b.latitude) / 2.0;
    final cosLat = math.cos(midLat * math.pi / 180).clamp(0.01, 1.0);
    final dx = (b.longitude - a.longitude) * mPerDegLat * cosLat;
    final dy = (b.latitude - a.latitude) * mPerDegLat;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1e-9) return null;
    final nx = -dy / len;
    final ny = dx / len;
    final dLon1 = (nx * offset1M) / (mPerDegLat * cosLat);
    final dLat1 = (ny * offset1M) / mPerDegLat;
    final dLon2 = (nx * offset2M) / (mPerDegLat * cosLat);
    final dLat2 = (ny * offset2M) / mPerDegLat;
    return [
      LatLng(a.latitude + dLat1, a.longitude + dLon1),
      LatLng(a.latitude + dLat2, a.longitude + dLon2),
      LatLng(b.latitude + dLat2, b.longitude + dLon2),
      LatLng(b.latitude + dLat1, b.longitude + dLon1),
      LatLng(a.latitude + dLat1, a.longitude + dLon1),
    ];
  }

  static const int _trackSectionCount = 5;

  /// Устойчивый к самопересечениям вариант: строим полосу как набор
  /// коротких прямоугольников между соседними точками.
  /// Если [sectionEnabled] задан, рисуем только включённые секции (полоса разбита на 5 частей по ширине).
  List<List<LatLng>> _buildStripPolygonsByPairs(List<LatLng> points, double widthMeters, {List<bool>? sectionEnabled}) {
    if (points.length < 2 || widthMeters <= 0) return const [];
    final polys = <List<LatLng>>[];
    final half = widthMeters / 2;
    const mPerDegLat = 111320.0;
    final useSections = sectionEnabled != null && sectionEnabled.length >= _trackSectionCount;

    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (!_isValidLatLng(a) || !_isValidLatLng(b)) continue;

      final d = haversineDistanceMeters(a.latitude, a.longitude, b.latitude, b.longitude);
      if (d < 0.05) continue;
      if (d > 40) continue;

      if (useSections) {
        final bandWidth = widthMeters / _trackSectionCount;
        for (int s = 0; s < _trackSectionCount; s++) {
          if (!sectionEnabled[s]) continue;
          final o1 = -half + s * bandWidth;
          final o2 = -half + (s + 1) * bandWidth;
          final band = _buildSegmentBand(a, b, o1, o2);
          if (band != null) polys.add(band);
        }
      } else {
        final midLat = (a.latitude + b.latitude) / 2.0;
        final cosLat = math.cos(midLat * math.pi / 180).clamp(0.01, 1.0);
        final dx = (b.longitude - a.longitude) * mPerDegLat * cosLat;
        final dy = (b.latitude - a.latitude) * mPerDegLat;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len < 1e-9) continue;
        final nx = -dy / len;
        final ny = dx / len;
        final dLon = (nx * half) / (mPerDegLat * cosLat);
        final dLat = (ny * half) / mPerDegLat;
        final p1 = LatLng(a.latitude + dLat, a.longitude + dLon);
        final p2 = LatLng(a.latitude - dLat, a.longitude - dLon);
        final p3 = LatLng(b.latitude - dLat, b.longitude - dLon);
        final p4 = LatLng(b.latitude + dLat, b.longitude + dLon);
        polys.add([p1, p2, p3, p4, p1]);
      }
    }
    return polys;
  }

  /// Угол поворота в градусах в точке [i] (между вектором (i-1)->(i) и (i)->(i+1)). 0 = прямо.
  static double _turnAngleDegrees(List<LatLng> points, int i) {
    if (i <= 0 || i >= points.length - 1) return 0;
    final prev = points[i - 1];
    final curr = points[i];
    final next = points[i + 1];
    final b1 = bearingDegrees(prev.latitude, prev.longitude, curr.latitude, curr.longitude);
    final b2 = bearingDegrees(curr.latitude, curr.longitude, next.latitude, next.longitude);
    var diff = b2 - b1;
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    return diff.abs();
  }

  /// Упрощает трек для заливки: сохраняет точки по шагу и все заметные повороты, чтобы не было пустот на изгибах.
  List<LatLng> _simplifyForFill(List<LatLng> points, {double minStepMeters = 0.8, double minTurnAngleDeg = 4.0}) {
    if (points.length < 3) return points;
    final simplified = <LatLng>[points.first];
    var last = points.first;
    for (int i = 1; i < points.length - 1; i++) {
      final p = points[i];
      final d = haversineDistanceMeters(
        last.latitude,
        last.longitude,
        p.latitude,
        p.longitude,
      );
      final turnAngle = _turnAngleDegrees(points, i);
      final isSignificantTurn = turnAngle >= minTurnAngleDeg;
      if (d >= minStepMeters || isSignificantTurn) {
        simplified.add(p);
        last = p;
      }
    }
    simplified.add(points.last);
    return simplified;
  }

  /// Уплотняет трек: вставляет промежуточные точки на длинных сегментах для плавной заливки на поворотах.
  List<LatLng> _densifyTrack(List<LatLng> points, {double maxSegmentMeters = 2.0}) {
    if (points.length < 2 || maxSegmentMeters <= 0) return points;
    final result = <LatLng>[points.first];
    for (int i = 1; i < points.length; i++) {
      final a = result.last;
      final b = points[i];
      final d = haversineDistanceMeters(a.latitude, a.longitude, b.latitude, b.longitude);
      if (d <= maxSegmentMeters) {
        result.add(b);
        continue;
      }
      final steps = (d / maxSegmentMeters).ceil().clamp(2, 12);
      for (int k = 1; k < steps; k++) {
        final t = k / steps;
        result.add(LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
      }
      result.add(b);
    }
    return result;
  }

  Future<void> _syncTrack() async {
    final c = _controller ?? await _controllerCompleter.future;
    if (!widget.showTrack) {
      _lastTrackFingerprint = 'off';
      try {
        await c.setGeoJsonSource(_trackFillSourceId, {
          'type': 'FeatureCollection',
          'features': <Map<String, dynamic>>[],
        });
        if (_trackCenterLayerAdded) {
          await c.setGeoJsonSource(_trackCenterSourceId, {
            'type': 'FeatureCollection',
            'features': <Map<String, dynamic>>[],
          });
        }
      } catch (e, st) {
        AppLogger.warn('map.track.hide', 'Failed to clear track when hidden', error: e, stackTrace: st);
      }
      return;
    }
    final List<List<TrackPoint>> segments = widget.staticTrackSegments != null
        ? widget.staticTrackSegments!
        : await widget.trackRecorder.getVisibleTrackSegments();
    final width = _effectiveWidthMeters;
    final totalPoints = segments.fold<int>(0, (sum, s) => sum + s.length);
    final sectionKey = widget.sectionEnabled != null
        ? widget.sectionEnabled!.map((b) => b ? '1' : '0').join()
        : 'all';
    final fingerprint = 'on:${segments.length}:$totalPoints:${width.toStringAsFixed(2)}:$sectionKey';
    debugProbeLog(
      runId: 'run2',
      hypothesisId: 'H6',
      location: 'maplibre_map_widget.dart:syncTrackFingerprint',
      message: 'Track fingerprint before sync',
      data: {'fingerprint': fingerprint, 'prev': _lastTrackFingerprint},
    );
    if (_lastTrackFingerprint == fingerprint) {
      debugProbeLog(
        runId: 'run2',
        hypothesisId: 'H6',
        location: 'maplibre_map_widget.dart:syncTrackSkip',
        message: 'Skip sync (no track changes)',
        data: {'fingerprint': fingerprint},
      );
      return;
    }
    _lastTrackFingerprint = fingerprint;
    debugProbeLog(
      runId: 'run1',
      hypothesisId: 'H4',
      location: 'maplibre_map_widget.dart:635',
      message: 'Track sync input segments',
      data: {
        'segmentsCount': segments.length,
        'firstSegmentLen': segments.isNotEmpty ? segments.first.length : 0,
      },
    );
    final lineSegments = segments
        .map((seg) => seg
            .where((p) => p.lat.isFinite && p.lon.isFinite)
            .map((p) => LatLng(p.lat, p.lon))
            .where(_isValidLatLng)
            .toList())
        .where((seg) => seg.isNotEmpty)
        .toList();
    debugProbeLog(
      runId: 'run1',
      hypothesisId: 'H4',
      location: 'maplibre_map_widget.dart:648',
      message: 'Track sync filtered segments',
      data: {
        'lineSegmentsCount': lineSegments.length,
        'firstLineLen': lineSegments.isNotEmpty ? lineSegments.first.length : 0,
      },
    );
    if (lineSegments.isEmpty) {
      _lastTrackFingerprint = 'empty';
      try {
        await c.setGeoJsonSource(_trackFillSourceId, {
          'type': 'FeatureCollection',
          'features': <Map<String, dynamic>>[],
        });
        if (_trackCenterLayerAdded) {
          await c.setGeoJsonSource(_trackCenterSourceId, {
            'type': 'FeatureCollection',
            'features': <Map<String, dynamic>>[],
          });
        }
      } catch (e, st) {
        AppLogger.warn('map.track.clear', 'Failed to clear track GeoJSON', error: e, stackTrace: st);
      }
      for (final l in _trackBorders) {
        await c.removeLine(l);
      }
      _trackBorders.clear();
      return;
    }

    // ТЗ 5.2: Пунктирная центральная линия по центру полосы — через GeoJSON + lineDasharray
    final centerFeatures = <Map<String, dynamic>>[];
    for (final seg in lineSegments) {
      if (seg.length < 2) continue;
      final coords = seg.map((p) => [p.longitude, p.latitude]).toList();
      centerFeatures.add({
        'type': 'Feature',
        'geometry': {'type': 'LineString', 'coordinates': coords},
        'properties': <String, dynamic>{},
      });
    }
    try {
      if (_trackCenterLayerAdded) {
        await c.setGeoJsonSource(_trackCenterSourceId, {
          'type': 'FeatureCollection',
          'features': centerFeatures,
        });
      }
    } catch (e, st) {
      AppLogger.warn('map.track.center_source', 'Failed to update center line source', error: e, stackTrace: st);
    }

    final polys = <List<LatLng>>[];
    final sectionEnabled = widget.sectionEnabled;
    for (final seg in lineSegments) {
      final simplified = _simplifyForFill(seg);
      final densified = _densifyTrack(simplified, maxSegmentMeters: 2.0);
      polys.addAll(_buildStripPolygonsByPairs(densified, width, sectionEnabled: sectionEnabled));
    }
    if (polys.isEmpty) {
      final allSectionsOff = sectionEnabled != null && sectionEnabled.length >= _trackSectionCount && !sectionEnabled.any((e) => e);
      if (allSectionsOff) {
        try {
          await c.setGeoJsonSource(_trackFillSourceId, {'type': 'FeatureCollection', 'features': <Map<String, dynamic>>[]});
        } catch (e, st) {
          AppLogger.warn('map.track.clear', 'Failed to clear track GeoJSON', error: e, stackTrace: st);
        }
        return;
      }
      // Fallback 1: пробуем прежний алгоритм цельной полосы по сегменту (без учёта секций), со сглаживанием.
      for (final seg in lineSegments) {
        final smoothed = _densifyTrack(_simplifyForFill(seg), maxSegmentMeters: 2.0);
        final poly = _buildStripPolygon(smoothed, width);
        if (poly.length >= 3) polys.add(poly);
      }
    }
    if (polys.isEmpty) {
      // Fallback 2: хотя бы локальные полигоны по точкам, чтобы трек не исчезал.
      for (final seg in lineSegments) {
        for (final p in seg) {
          if (_isValidLatLng(p)) {
            polys.add(_buildSinglePointPolygon(p, width));
          }
        }
      }
    }
    if (polys.isEmpty) {
      // Не очищаем существующую заливку при временно пустой геометрии,
      // чтобы трек не "исчезал" из-за единичного сбоя входных точек.
      AppLogger.warn('map.track.empty_poly', 'Skip clearing fill due to empty polys with non-empty segments');
      return;
    }

    final features = <Map<String, dynamic>>[];
    for (final poly in polys) {
      final clean = poly.where(_isValidLatLng).toList();
      if (clean.length < 3) continue;
      final ring = clean.first == clean.last ? clean : [...clean, clean.first];
      if (ring.length < 4) continue;
      final coords = ring.map((p) => [p.longitude, p.latitude]).toList();
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [coords],
        },
        'properties': <String, dynamic>{},
      });
    }
    if (features.isEmpty) {
      AppLogger.warn('map.track.empty_features', 'Skip clearing fill due to invalid generated polygons');
      return;
    }
    try {
      await c.setGeoJsonSource(_trackFillSourceId, {
        'type': 'FeatureCollection',
        'features': features,
      });
    } catch (e, st) {
      AppLogger.warn('map.track.fill_source', 'Failed to update fill source', error: e, stackTrace: st);
    }

    // Границу рисуем через fill-outline-color в слое fill,
    // а старые line-границы удаляем.
    while (_trackBorders.isNotEmpty) {
      final l = _trackBorders.removeLast();
      await c.removeLine(l);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _trackSub?.cancel();
    _connectivitySub?.cancel();
    _renderTimer?.cancel();
    _trackSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasGpsSignal) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: const Center(
          child: Text(
            'НЕТ СИГНАЛА GPS',
            style: TextStyle(color: Colors.red, fontSize: 18),
          ),
        ),
      );
    }

    Widget mapContent = Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: MapLibreMap(
        styleString: _useOfflineStyle ? _offlineStyle : _styleUrl,
        initialCameraPosition: _fallbackCamera,
        onMapCreated: _onMapCreated,
        trackCameraPosition: true,
        onCameraMove: (cameraPosition) {
          final z = cameraPosition.zoom;
          if (z.isFinite && !_programmaticCameraMove) _cameraZoom = z;
          if (!_programmaticCameraMove) {
            _userInteracting = true;
          }
        },
        onCameraIdle: () {
          _userInteracting = false;
        },
        onStyleLoadedCallback: () async {
          _styleLoaded = true;
          final c = _controller ?? await _controllerCompleter.future;
          // P0: В офлайн-режиме добавляем только слои трека (без тайлов) — карта и трек usable без сети.
          if (_useOfflineStyle) {
            try {
              await c.addGeoJsonSource(_trackFillSourceId, {
                'type': 'FeatureCollection',
                'features': [],
              });
              await c.addFillLayer(
                _trackFillSourceId,
                _trackFillLayerId,
                const FillLayerProperties(
                  fillColor: '#FFEB3B',
                  fillOpacity: 0.35,
                  fillOutlineColor: '#FFFFFF',
                ),
              );
              await c.addGeoJsonSource(_trackCenterSourceId, {
                'type': 'FeatureCollection',
                'features': [],
              });
              await c.addLineLayer(
                _trackCenterSourceId,
                _trackCenterLayerId,
                const LineLayerProperties(
                  lineColor: '#FFEB3B',
                  lineWidth: 2.5,
                  lineDasharray: [3, 4],
                ),
                enableInteraction: false,
              );
              _trackCenterLayerAdded = true;
            } catch (e, st) {
              AppLogger.warn('map.style.offline_layers', 'Failed to create offline layers', error: e, stackTrace: st);
            }
            if (widget.follow) await _updateCamera();
            await _syncAll();
            if (widget.staticTrackSegments != null && widget.staticTrackSegments!.isNotEmpty) {
              final allPoints = widget.staticTrackSegments!.expand((s) => s).toList();
              if (allPoints.isNotEmpty) {
                double minLat = allPoints.first.lat, maxLat = minLat;
                double minLon = allPoints.first.lon, maxLon = minLon;
                for (final p in allPoints) {
                  if (p.lat < minLat) minLat = p.lat;
                  if (p.lat > maxLat) maxLat = p.lat;
                  if (p.lon < minLon) minLon = p.lon;
                  if (p.lon > maxLon) maxLon = p.lon;
                }
                final bounds = LatLngBounds(
                  southwest: LatLng(minLat, minLon),
                  northeast: LatLng(maxLat, maxLon),
                );
                await c.animateCamera(
                  CameraUpdate.newLatLngBounds(bounds, left: 48, top: 48, right: 48, bottom: 48),
                  duration: const Duration(milliseconds: 500),
                );
              }
            }
            if (mounted) setState(() {});
            return;
          }
          try {
            await c.addGeoJsonSource('agrokilar-field', {
              'type': 'FeatureCollection',
              'features': [
                {
                  'type': 'Feature',
                  'geometry': {
                    'type': 'Polygon',
                    'coordinates': [
                      [[-180, -90], [180, -90], [180, 90], [-180, 90], [-180, -90]]
                    ],
                  },
                },
              ],
            });
            await c.addFillLayer(
              'agrokilar-field',
              'agrokilar-field-layer',
              const FillLayerProperties(fillColor: '#2E7D32', fillOpacity: 1.0),
              belowLayerId: 'crimea-fill',
            );
            await c.addGeoJsonSource('agrokilar-differential', {
              'type': 'FeatureCollection',
              'features': [],
            });
            await c.addFillLayer(
              'agrokilar-differential',
              'agrokilar-differential-layer',
              const FillLayerProperties(fillColor: '#000000', fillOpacity: 0.0),
              belowLayerId: 'crimea-fill',
            );
            await c.addGeoJsonSource(_trackFillSourceId, {
              'type': 'FeatureCollection',
              'features': [],
            });
            await c.addFillLayer(
              _trackFillSourceId,
              _trackFillLayerId,
              const FillLayerProperties(
                fillColor: '#FFEB3B',
                fillOpacity: 0.35,
                fillOutlineColor: '#FFFFFF',
              ),
            );
            await c.addGeoJsonSource(_trackCenterSourceId, {
              'type': 'FeatureCollection',
              'features': [],
            });
            await c.addLineLayer(
              _trackCenterSourceId,
              _trackCenterLayerId,
              const LineLayerProperties(
                lineColor: '#FFEB3B',
                lineWidth: 2.5,
                lineDasharray: [3, 4],
              ),
              enableInteraction: false,
            );
            _trackCenterLayerAdded = true;
          } catch (e, st) {
            AppLogger.warn('map.style.online_layers', 'Failed to create online layers', error: e, stackTrace: st);
          }
          if (widget.follow) {
            await _updateCamera();
          }
          await _syncAll();
          if (widget.staticTrackSegments != null && widget.staticTrackSegments!.isNotEmpty) {
            final allPoints = widget.staticTrackSegments!.expand((s) => s).toList();
            if (allPoints.isNotEmpty) {
              double minLat = allPoints.first.lat, maxLat = minLat;
              double minLon = allPoints.first.lon, maxLon = minLon;
              for (final p in allPoints) {
                if (p.lat < minLat) minLat = p.lat;
                if (p.lat > maxLat) maxLat = p.lat;
                if (p.lon < minLon) minLon = p.lon;
                if (p.lon > maxLon) maxLon = p.lon;
              }
              final bounds = LatLngBounds(
                southwest: LatLng(minLat, minLon),
                northeast: LatLng(maxLat, maxLon),
              );
              await c.animateCamera(
                CameraUpdate.newLatLngBounds(bounds, left: 48, top: 48, right: 48, bottom: 48),
                duration: const Duration(milliseconds: 500),
              );
            }
          }
          if (mounted) setState(() {});
        },
        // Масштаб только через кнопки +/− (без двойного тапа и pinch).
        zoomGesturesEnabled: false,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        compassEnabled: false,
        myLocationEnabled: false,
        myLocationTrackingMode: MyLocationTrackingMode.none,
          ),
        ),
        // ТЗ 5.8: Кнопки масштаба +/− и «Найти меня»
        Positioned(
          left: 8,
          bottom: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapControlButton(
                    icon: Icons.add,
                    tooltip: 'Приблизить',
                    onPressed: () async {
                      final c = _controller ?? await _controllerCompleter.future;
                      await c.animateCamera(CameraUpdate.zoomIn());
                    },
                  ),
                  const SizedBox(width: 4),
                  _MapControlButton(
                    icon: Icons.remove,
                    tooltip: 'Отдалить',
                    onPressed: () async {
                      final c = _controller ?? await _controllerCompleter.future;
                      await c.animateCamera(CameraUpdate.zoomOut());
                    },
                  ),
                ],
              ),
              if (!widget.follow) ...[
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.my_location,
                  tooltip: 'Найти меня',
                  onPressed: () => _updateCamera(),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Ширина: ${_effectiveWidthMeters.toStringAsFixed(1)} м',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
    if (widget.repaintBoundaryKey != null) {
      mapContent = RepaintBoundary(
        key: widget.repaintBoundaryKey,
        child: mapContent,
      );
    }
    return mapContent;
  }
}

/// Кнопка управления картой (масштаб, центрирование).
class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 22),
        tooltip: tooltip,
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(36, 36),
        ),
      ),
    );
  }
}

