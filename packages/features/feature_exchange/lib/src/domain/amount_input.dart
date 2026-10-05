/// Interpreta lo que escribe el usuario (`12`, `12,5`, `12.50`, `.5`) como
/// centavos, sin `double`. Acepta coma o punto y hasta dos decimales.
///
/// Devuelve `null` si está vacío, tiene otros caracteres, más de dos decimales
/// o más de 12 dígitos enteros.
int? parseAmountInput(String input) {
  final match = RegExp(r'^(\d*)(?:[.,](\d{0,2}))?$').firstMatch(input.trim());
  if (match == null) return null;
  final whole = match.group(1)!;
  final fraction = match.group(2) ?? '';
  if (whole.isEmpty && fraction.isEmpty) return null;
  if (whole.length > 12) return null;
  final cents = int.parse(fraction.padRight(2, '0'));
  return (whole.isEmpty ? 0 : int.parse(whole)) * 100 + cents;
}
