import 'package:flutter/material.dart';
import '../models/work_session.dart';
import '../repository/app_repository.dart';
import '../services/export_service.dart';
import '../utils/format_utils.dart';
import 'track_view_screen.dart';

class WorkHistoryScreen extends StatefulWidget {
  const WorkHistoryScreen({super.key});

  @override
  State<WorkHistoryScreen> createState() => _WorkHistoryScreenState();
}

class _WorkHistoryScreenState extends State<WorkHistoryScreen> {
  final _repo = AppRepository();
  List<WorkSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.getAllWorkSessions();
    if (mounted) setState(() => _sessions = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('История работ', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black26,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _sessions.isEmpty
          ? const Center(child: Text('Нет записей', style: TextStyle(color: Colors.white70, fontSize: 18)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sessions.length,
              itemBuilder: (context, i) {
                final s = _sessions[i];
                return Card(
                  color: Colors.white12,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: s.id != null
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TrackViewScreen(sessionId: s.id!),
                              ),
                            )
                        : null,
                    title: Text(
                      s.abLineName ?? 'Без линии',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${_formatDate(s.startTime)} · ${formatDuration(s.duration)}\n'
                      'Путь: ${formatDistanceKm(s.distanceKm)} км · Площадь: ${formatAreaHa(s.areaHa)} га',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.share, color: Colors.white70),
                      onPressed: () => _showExportMenu(context, s),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showExportMenu(BuildContext context, WorkSession s) async {
    if (s.id == null) return;
    final points = await _repo.getTrackPointsBySessionId(s.id!);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Экспорт трека', style: TextStyle(color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.map, color: Colors.white70),
              title: const Text('GPX', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await ExportService.exportGpx(s, points);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.white70),
              title: const Text('CSV', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await ExportService.exportCsv(s, points);
              },
            ),
            ListTile(
              leading: const Icon(Icons.terrain, color: Colors.white70),
              title: const Text('KML', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await ExportService.exportKml(s, points);
              },
            ),
          ],
        ),
      ),
    );
  }
}
