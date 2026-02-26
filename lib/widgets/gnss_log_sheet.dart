import 'package:flutter/material.dart';
import '../services/demo_gnss_simulation.dart';

/// Нижняя панель с логом GNSS (реальные и демо-записи).
class GnssLogSheet extends StatelessWidget {
  final List<GnssLogEntry> entries;
  final bool isDemoMode;

  final ScrollController? scrollController;

  const GnssLogSheet({
    super.key,
    required this.entries,
    this.isDemoMode = false,
    this.scrollController,
  });

  static void show(BuildContext context, List<GnssLogEntry> entries, bool isDemoMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => GnssLogSheet(
          entries: entries,
          isDemoMode: isDemoMode,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                isDemoMode ? 'Демо: журнал GPS' : 'Журнал GPS',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isDemoMode)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('СИМУЛЯЦИЯ', style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white24),
        Flexible(
          child: entries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Нет записей. Включите демо или дождитесь GPS.', style: TextStyle(color: Colors.white54)),
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return Card(
                      color: Colors.white12,
                      margin: const EdgeInsets.only(bottom: 6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}:${e.time.second.toString().padLeft(2, '0')}',
                                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                                ),
                                if (e.isDemo)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: const Text('DEMO', style: TextStyle(color: Colors.black87, fontSize: 10)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${e.lat.toStringAsFixed(6)}°, ${e.lon.toStringAsFixed(6)}°',
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            Text(
                              'Точность: ${e.accuracyMeters.toStringAsFixed(1)} м · ${e.speedKmh.toStringAsFixed(1)} км/ч · Курс: ${e.heading?.toStringAsFixed(0) ?? "—"}°',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            if (e.isDemo)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  e.toNmeaStyle(),
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontFamily: 'monospace'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
