import '../models/track_point.dart';
import '../models/work_session.dart';

/// Общая логика построения контента для экспорта (без platform-специфичного кода).
class ExportServiceCommon {
  static String buildGpxContent(WorkSession session, List<TrackPoint> points) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<gpx version="1.1" creator="Agrokilar Курсоуказатель">');
    sb.writeln('  <trk>');
    sb.writeln('    <name>${_escape(session.abLineName ?? "Трек")}</name>');
    sb.writeln('    <trkseg>');
    for (final p in points) {
      sb.writeln('      <trkpt lat="${p.lat}" lon="${p.lon}"><time>${p.timestamp.toUtc().toIso8601String()}</time></trkpt>');
    }
    sb.writeln('    </trkseg>');
    sb.writeln('  </trk>');
    sb.writeln('</gpx>');
    return sb.toString();
  }

  static String buildCsvContent(WorkSession session, List<TrackPoint> points) {
    final sb = StringBuffer();
    sb.writeln('Время;Широта;Долгота;Скорость_кмч;Курс;Отклонение_м');
    for (final p in points) {
      sb.writeln('${p.timestamp.toIso8601String()};${p.lat};${p.lon};${p.speedKmh ?? ""};${p.bearing ?? ""};${p.deviationMeters ?? ""}');
    }
    return sb.toString();
  }

  static String buildKmlContent(WorkSession session, List<TrackPoint> points) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    sb.writeln('  <Document>');
    sb.writeln('    <name>${_escape(session.abLineName ?? "Трек")}</name>');
    sb.writeln('    <Placemark>');
    sb.writeln('      <LineString>');
    sb.writeln('        <coordinates>');
    for (final p in points) {
      sb.writeln('          ${p.lon},${p.lat},0');
    }
    sb.writeln('        </coordinates>');
    sb.writeln('      </LineString>');
    sb.writeln('    </Placemark>');
    sb.writeln('  </Document>');
    sb.writeln('</kml>');
    return sb.toString();
  }

  static String _escape(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}
