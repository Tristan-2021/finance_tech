/// Tope de un movimiento manual: 1.000.000,00 (en centavos).
const maxMovementCents = 100000000;

enum AmountError { empty, invalid, tooManyDecimals, notPositive, tooLarge }

/// Interpreta lo que escribe el usuario (`12`, `12,3`, `12.30`) como centavos,
/// sin `double`. Acepta coma o punto y hasta dos decimales. Devuelve los
/// centavos o el motivo por el que el texto no vale: vacío, no numérico, más de
/// dos decimales, cero, o por encima de [maxMovementCents].
({int? cents, AmountError? error}) validateAmount(String input) {
  final text = input.trim();
  if (text.isEmpty) return (cents: null, error: AmountError.empty);

  final match = RegExp(r'^(\d*)(?:[.,](\d*))?$').firstMatch(text);
  final whole = match?.group(1) ?? '';
  final fraction = match?.group(2) ?? '';
  if (match == null || (whole.isEmpty && fraction.isEmpty)) {
    return (cents: null, error: AmountError.invalid);
  }
  if (fraction.length > 2) {
    return (cents: null, error: AmountError.tooManyDecimals);
  }
  if (whole.length > 12) return (cents: null, error: AmountError.tooLarge);

  final cents =
      (whole.isEmpty ? 0 : int.parse(whole)) * 100 +
      int.parse(fraction.padRight(2, '0'));
  if (cents == 0) return (cents: null, error: AmountError.notPositive);
  if (cents > maxMovementCents) {
    return (cents: null, error: AmountError.tooLarge);
  }
  return (cents: cents, error: null);
}

/// Centavos a cadena decimal exacta: `1230` -> `"12.30"`, `5` -> `"0.05"`.
/// Es lo que se envía al RPC (`numeric`), nunca un `double`.
String centsToDecimalString(int cents) {
  if (cents < 0) throw ArgumentError.value(cents, 'cents', 'no puede ser negativo');
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return '${cents ~/ 100}.$fraction';
}
