abstract final class ActivityDateFormatter {
  // Zona fija del diseño. Las fechas originales se conservan en UTC.
  static const offset = Duration(hours: -5);
  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static String format(DateTime date) {
    final display = date.toUtc().add(offset);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${display.day} ${_months[display.month - 1]} ${display.year} · '
        '${two(display.hour)}:${two(display.minute)}:${two(display.second)}';
  }
}
