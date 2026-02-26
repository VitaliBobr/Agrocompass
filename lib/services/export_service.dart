/// Экспорт трека: на web — XFile.fromData, на mobile/desktop — path_provider + File.
/// По умолчанию (web) используем web-реализацию, для VM (io) — io-реализацию.
export 'export_service_web.dart'
    if (dart.library.io) 'export_service_io.dart';
