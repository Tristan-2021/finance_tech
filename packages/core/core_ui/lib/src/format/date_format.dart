const _months = [
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

String _two(int n) => n.toString().padLeft(2, '0');

/// `14 may 2026`, en hora local. El día no lleva cero a la izquierda.
String formatDateEs(DateTime date) {
  final d = date.toLocal();
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// `14 may 2026, 09:30`, en hora local y formato de 24 horas.
String formatDateTimeEs(DateTime date) {
  final d = date.toLocal();
  return '${formatDateEs(d)}, ${_two(d.hour)}:${_two(d.minute)}';
}
