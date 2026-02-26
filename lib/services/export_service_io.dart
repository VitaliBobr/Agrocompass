import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/track_point.dart';
import '../models/work_session.dart';
import 'export_service_common.dart';

/// Реализация экспорта для iOS, Android, desktop (использует path_provider и File).
class ExportService {
  static Future<void> exportGpx(WorkSession session, List<TrackPoint> points) async {
    final content = ExportServiceCommon.buildGpxContent(session, points);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/track_${session.id ?? 0}.gpx');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)], text: 'Трек курсоуказателя');
  }

  static Future<void> exportCsv(WorkSession session, List<TrackPoint> points) async {
    final content = ExportServiceCommon.buildCsvContent(session, points);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/track_${session.id ?? 0}.csv');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)], text: 'Трек CSV');
  }

  static Future<void> exportKml(WorkSession session, List<TrackPoint> points) async {
    final content = ExportServiceCommon.buildKmlContent(session, points);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/track_${session.id ?? 0}.kml');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)], text: 'Трек KML');
  }

  /// P1: Экспорт снимка карты — делится PNG-изображением.
  static Future<void> shareMapImage(Uint8List pngBytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/map_snapshot_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(pngBytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Снимок карты');
  }
}
