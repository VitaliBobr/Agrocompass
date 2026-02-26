/// Форматирование для отображения: м, км, га.
String formatDistanceKm(double km) {
  return '${km.toStringAsFixed(2)}';
}

String formatAreaHa(double ha) {
  return '${ha.toStringAsFixed(3)}';
}

String formatDeviationMeters(double m) {
  return m.toStringAsFixed(2);
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final min = d.inMinutes.remainder(60);
  if (h > 0) return '${h} ч ${min} мин';
  return '${min} мин';
}
