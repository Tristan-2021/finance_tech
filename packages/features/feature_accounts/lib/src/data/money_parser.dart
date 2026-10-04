/// Convierte un `numeric(14,2)` de Postgres (String o num del JSON) a centavos
/// sin aritmética en `double`. Lanza [FormatException] si no es un monto válido
/// o si tiene más de 2 decimales significativos.
///
/// Un `numeric(14,2)` tiene a lo sumo 14 dígitos significativos, así que el
/// `toString()` de un `double` del JSON es exacto.
int parseCents(Object? value) {
  final String text;
  if (value is String) {
    text = value.trim();
  } else if (value is int) {
    text = value.toString();
  } else if (value is double) {
    text = value.toString();
  } else {
    throw FormatException('Monto inválido: $value');
  }

  final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(text);
  if (match == null) throw FormatException('Monto inválido: $text');

  final negative = match.group(1) == '-';
  final whole = int.parse(match.group(2)!);
  final fraction = match.group(3) ?? '';

  if (fraction.length > 2 && fraction.substring(2).replaceAll('0', '') != '') {
    throw FormatException('Más de 2 decimales: $text');
  }
  final cents = fraction.isEmpty
      ? 0
      : int.parse(fraction.padRight(2, '0').substring(0, 2));

  final total = whole * 100 + cents;
  return negative ? -total : total;
}
