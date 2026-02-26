import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/ab_line.dart';
import '../services/location_service.dart';
import '../services/track_recorder_service.dart';

class MapWidget extends StatefulWidget {
  final bool hasGpsSignal;
  final AbLine? abLine;
  final TrackRecorderService trackRecorder;
  final LocationService locationService;
  /// Курс в градусах (0–360) для отрисовки штанги трактора.
  final double? headingDegrees;

  const MapWidget({
    super.key,
    required this.hasGpsSignal,
    required this.abLine,
    required this.trackRecorder,
    required this.locationService,
    this.headingDegrees,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final _mapController = MapController();
  StreamSubscription<TrackRecordingState>? _trackSub;
  StreamSubscription<PositionUpdate>? _positionSub;
  List<LatLng> _trackPoints = [];
  List<LatLng> _trackPolygon = [];
  double _widthMeters = 0;
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _trackSub = widget.trackRecorder.stateStream.listen(_onTrackState);
    _positionSub = widget.locationService.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
      });
      if (widget.trackRecorder.state.isRecording) {
        _loadTrackPoints();
      }
    });
    _loadTrackPoints();
  }

  void _onTrackState(TrackRecordingState s) {
    _loadTrackPoints();
  }

  static const double _defaultWidthMeters = 2.0;

  Future<void> _loadTrackPoints() async {
    final points = await widget.trackRecorder.getCurrentTrackPoints();
    if (!mounted) return;
    setState(() {
      _trackPoints = points.map((p) => LatLng(p.lat, p.lon)).toList();
      _widthMeters = widget.abLine?.widthMeters ?? _defaultWidthMeters;
      _trackPolygon = _buildStripPolygon(_trackPoints, _widthMeters);
    });
  }

  /// Строит полигон-полосу из линии трека (ширина в метрах).
  List<LatLng> _buildStripPolygon(List<LatLng> points, double widthMeters) {
    if (points.isEmpty || widthMeters <= 0) return [];
    if (points.length == 1) {
      return _buildSinglePointPolygon(points.first, widthMeters);
    }
    const mPerDegLat = 111320.0;
    final half = widthMeters / 2;
    final left = <LatLng>[];
    final right = <LatLng>[];
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      double dx, dy;
      if (i == 0) {
        dx = points[1].longitude - p.longitude;
        dy = points[1].latitude - p.latitude;
      } else if (i == points.length - 1) {
        dx = p.longitude - points[i - 1].longitude;
        dy = p.latitude - points[i - 1].latitude;
      } else {
        dx = points[i + 1].longitude - points[i - 1].longitude;
        dy = points[i + 1].latitude - points[i - 1].latitude;
      }
      final cosLat = math.cos(p.latitude * math.pi / 180).clamp(0.01, 1.0);
      final lenM = mPerDegLat * math.sqrt(dy * dy + (dx * cosLat) * (dx * cosLat));
      if (lenM < 1e-6) {
        left.add(p);
        right.add(p);
        continue;
      }
      final k = half / lenM;
      final leftLat = p.latitude - dy * k;
      final leftLon = p.longitude + dx * k;
      final rightLat = p.latitude + dy * k;
      final rightLon = p.longitude - dx * k;
      left.add(LatLng(leftLat, leftLon));
      right.add(LatLng(rightLat, rightLon));
    }
    return [...left, ...right.reversed];
  }

  /// Один пункт — рисуем квадрат вокруг точки (сразу видна закраска).
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

  /// Слой штанги — белая пунктирная линия.
  Widget _boomPolylineLayer() {
    final pts = _boomBarPoints(
      _currentPosition!,
      widget.headingDegrees ?? 0,
      _widthMeters,
    );
    if (pts == null) return const SizedBox.shrink();
    final segments = <List<LatLng>>[];
    for (var d = 0.0; d < 1.0; d += 0.25) {
      final t0 = d.clamp(0.0, 1.0);
      final t1 = (d + 0.2).clamp(0.0, 1.0);
      if (t0 >= t1) break;
      segments.add([
        LatLng(
          pts[0].latitude + (pts[1].latitude - pts[0].latitude) * t0,
          pts[0].longitude + (pts[1].longitude - pts[0].longitude) * t0,
        ),
        LatLng(
          pts[0].latitude + (pts[1].latitude - pts[0].latitude) * t1,
          pts[0].longitude + (pts[1].longitude - pts[0].longitude) * t1,
        ),
      ]);
    }
    return PolylineLayer(
      polylines: [
        for (final seg in segments)
          Polyline(points: seg, color: const Color(0xFFFFEB3B), strokeWidth: 8),
      ],
    );
  }

  /// Слой «сопел» на штанге — короткие вертикальные отрезки.
  Widget _boomNozzlesLayer() {
    final pts = _boomBarPoints(
      _currentPosition!,
      widget.headingDegrees ?? 0,
      _widthMeters,
    );
    if (pts == null) return const SizedBox.shrink();
    final h = (widget.headingDegrees ?? 0) * math.pi / 180;
    const mPerDegLat = 111320.0;
    final cosLat = math.cos(_currentPosition!.latitude * math.pi / 180).clamp(0.01, 1.0);
    const nozzleLenM = 0.4;
    final nozzleLat = nozzleLenM / mPerDegLat;
    final nozzleLon = nozzleLenM / (mPerDegLat * cosLat);
    final nozzleSegments = <List<LatLng>>[];
    for (var i = 1; i <= 5; i++) {
      final t = i / 6;
      final cx = pts[0].latitude + (pts[1].latitude - pts[0].latitude) * t;
      final cy = pts[0].longitude + (pts[1].longitude - pts[0].longitude) * t;
      final nLat = math.sin(h) * nozzleLat;
      final nLon = math.cos(h) * nozzleLon;
      nozzleSegments.add([
        LatLng(cx - nLat, cy - nLon),
        LatLng(cx + nLat, cy + nLon),
      ]);
    }
    return PolylineLayer(
      polylines: [
        for (final seg in nozzleSegments)
          Polyline(points: seg, color: Colors.white, strokeWidth: 4),
      ],
    );
  }

  /// Претензия 4: Штанга — по направлению за трактором (вдоль вектора движения, назад).
  List<LatLng>? _boomBarPoints(LatLng center, double headingDeg, double widthMeters) {
    if (widthMeters <= 0) return null;
    const mPerDegLat = 111320.0;
    final h = headingDeg * math.pi / 180;
    final cosLat = math.cos(center.latitude * math.pi / 180).clamp(0.01, 1.0);
    final northB = -math.cos(h) * (widthMeters / 2);
    final eastB = -math.sin(h) * (widthMeters / 2);
    final back = LatLng(
      center.latitude + northB / mPerDegLat,
      center.longitude + eastB / (mPerDegLat * cosLat),
    );
    return [center, back];
  }

  @override
  void didUpdateWidget(covariant MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.abLine != widget.abLine || oldWidget.trackRecorder != widget.trackRecorder) {
      _loadTrackPoints();
    }
  }

  @override
  void dispose() {
    _trackSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  void _centerOnMe() {
    LatLng pos;
    if (_currentPosition != null) {
      pos = _currentPosition!;
    } else if (widget.abLine != null) {
      pos = LatLng(
        (widget.abLine!.latA + widget.abLine!.latB) / 2,
        (widget.abLine!.lonA + widget.abLine!.lonB) / 2,
      );
    } else {
      pos = const LatLng(55.75, 37.62);
    }
    _mapController.move(pos, _mapController.camera.zoom);
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
          child: Text('НЕТ СИГНАЛА GPS', style: TextStyle(color: Colors.red, fontSize: 18)),
        ),
      );
    }

    final center = _currentPosition ?? (widget.abLine != null
        ? LatLng(
            (widget.abLine!.latA + widget.abLine!.latB) / 2,
            (widget.abLine!.lonA + widget.abLine!.lonB) / 2,
          )
        : LatLng(55.75, 37.62));

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 16,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.agrokilar.compass',
              ),
              // AB-линия
              if (widget.abLine != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        LatLng(widget.abLine!.latA, widget.abLine!.lonA),
                        LatLng(widget.abLine!.latB, widget.abLine!.lonB),
                      ],
                      color: Colors.amber,
                      strokeWidth: 6,
                    ),
                  ],
                ),
              // Полоса трека обработки — жёлтая
              if (_trackPolygon.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _trackPolygon,
                      color: Colors.yellow.withValues(alpha: 0.55),
                      borderColor: Colors.yellow.shade800,
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              // Штанга трактора — белая, с «соплами» (вертикальные отрезки)
              if (_currentPosition != null && _widthMeters > 0) ...[
                _boomPolylineLayer(),
                _boomNozzlesLayer(),
              ],
              // Трактор — белый, как на референсе
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 52,
                      height: 52,
                      child: Transform.rotate(
                        angle: -(widget.headingDegrees ?? 0) * math.pi / 180,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade700, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.agriculture,
                            color: Color(0xFF333333),
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: IconButton(
            onPressed: _centerOnMe,
            icon: const Icon(Icons.my_location, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
          ),
        ),
      ],
    );
  }
}
