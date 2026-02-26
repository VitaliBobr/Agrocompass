import 'dart:convert';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../models/track_point.dart';
import '../models/work_session.dart';
import 'export_service_common.dart';

/// Реализация экспорта для Web (без path_provider и dart:io — используется XFile.fromData).
class ExportService {
  static Future<void> exportGpx(WorkSession session, List<TrackPoint> points) async {
    final content = ExportServiceCommon.buildGpxContent(session, points);
    final bytes = Uint8List.fromList(utf8.encode(content));
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: 'track_${session.id ?? 0}.gpx')],
      text: 'Трек курсоуказателя',
    );
  }

  static Future<void> exportCsv(WorkSession session, List<TrackPoint> points) async {
    final content = ExportServiceCommon.buildCsvContent(session, points);
    final bytes = Uint8List.fromList(utf8.encode(content));
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: 'track_${session.id ?? 0}.csv')],
      text: 'Трек CSV',
    );
  }

  static Future<void> exportKml(WorkSession session, List<TrackPoint> points) async {
    final content = ExportServiceCommon.buildKmlContent(session, points);
    final bytes = Uint8List.fromList(utf8.encode(content));
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: 'track_${session.id ?? 0}.kml')],
      text: 'Трек KML',
    );
  }

  /// P1: Экспорт снимка карты — делится PNG-изображением.
  static Future<void> shareMapImage(Uint8List pngBytes) async {
    await Share.shareXFiles(
      [XFile.fromData(pngBytes, name: 'map_snapshot.png')],
      text: 'Снимок карты',
    );
  }
}
