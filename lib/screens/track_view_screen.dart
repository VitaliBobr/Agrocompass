import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/track_point.dart';
import '../models/work_session.dart';
import '../repository/app_repository.dart';
import '../services/export_service.dart';
import '../utils/app_logger.dart';
import '../services/location_service.dart';
import '../services/track_recorder_service.dart';
import '../utils/format_utils.dart';
import '../widgets/maplibre_map_widget.dart';

/// ТЗ 11: Экран просмотра старого трека на карте.
class TrackViewScreen extends StatefulWidget {
  final int sessionId;

  const TrackViewScreen({super.key, required this.sessionId});

  @override
  State<TrackViewScreen> createState() => _TrackViewScreenState();
}

class _TrackViewScreenState extends State<TrackViewScreen> {
  final _repo = AppRepository();
  final _location = LocationService();
  final _tracker = TrackRecorderService();
  final GlobalKey _mapRepaintKey = GlobalKey();

  WorkSession? _session;
  List<List<TrackPoint>> _segments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final session = await _repo.getWorkSessionById(widget.sessionId);
      if (session == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Сессия не найдена';
          });
        }
        return;
      }
      final points = await _repo.getTrackPointsBySessionId(widget.sessionId);
      if (mounted) {
        setState(() {
          _session = session;
          _segments = points.isEmpty ? [] : [points];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          _session?.abLineName ?? 'Трек',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black26,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _showExportMenu(context),
            tooltip: 'Поделиться',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    if (_segments.isEmpty) {
      return const Center(
        child: Text(
          'Нет точек трека',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
      );
    }

    final widthMeters = _session?.widthMeters ?? 2.0;

    return Column(
      children: [
        if (_session != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InfoChip(label: 'Путь', value: formatDistanceKm(_session!.distanceKm)),
                _InfoChip(label: 'Площадь', value: formatAreaHa(_session!.areaHa)),
                _InfoChip(label: 'Длительность', value: formatDuration(_session!.duration)),
              ],
            ),
          ),
        Expanded(
          child: MapLibreMapWidget(
            hasGpsSignal: true,
            abLine: null,
            trackRecorder: _tracker,
            locationService: _location,
            headingDegrees: 0,
            speedKmh: 0,
            is3D: false,
            follow: false,
            passIndex: 0,
            staticTrackSegments: _segments,
            staticTrackWidthMeters: widthMeters,
            repaintBoundaryKey: _mapRepaintKey,
          ),
        ),
      ],
    );
  }

  Future<void> _showExportMenu(BuildContext context) async {
    if (_session == null) return;
    final points = await _repo.getTrackPointsBySessionId(widget.sessionId);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Поделиться', style: TextStyle(color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.map, color: Colors.white70),
              title: const Text('GPX', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await ExportService.exportGpx(_session!, points);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.white70),
              title: const Text('CSV', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await ExportService.exportCsv(_session!, points);
              },
            ),
            ListTile(
              leading: const Icon(Icons.terrain, color: Colors.white70),
              title: const Text('KML', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await ExportService.exportKml(_session!, points);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.white70),
              title: const Text('Снимок карты', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await _captureAndShareMapImage(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureAndShareMapImage(BuildContext context) async {
    final boundary = _mapRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Карта недоступна для снимка')),
        );
      }
      return;
    }
    try {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Не удалось создать изображение');
      final bytes = byteData.buffer.asUint8List();
      await ExportService.shareMapImage(bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Снимок карты готов к отправке')),
        );
      }
    } catch (e, st) {
      AppLogger.warn('map.snapshot.track_view', 'Failed to capture/share map image', error: e, stackTrace: st);
      final msg = e.toString().trim().isEmpty || e.toString() == 'null'
          ? 'Неизвестная ошибка'
          : e.toString();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка снимка: $msg')),
        );
      }
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
