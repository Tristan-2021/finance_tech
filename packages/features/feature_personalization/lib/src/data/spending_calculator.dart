import '../domain/spending_summary.dart';

/// Convierte el `numeric` que devuelve PostgREST (número JSON o texto) a
/// centavos sin pasar por `double`. Deuda técnica: duplica `parseCents` de
/// feature_accounts; unificar en un core cuando haya un tercer consumidor.
/// Devuelve `null` si el valor no es un importe válido.
int? parseAmountToCents(Object? value) {
  if (value is! num && value is! String) return null;
  final text = value.toString().trim();
  final match = RegExp(r'^(-)?(\d+)(?:\.(\d+))?$').firstMatch(text);
  if (match == null) return null;
  final fraction = (match.group(3) ?? '').padRight(2, '0').substring(0, 2);
  final cents = int.parse(match.group(2)!) * 100 + int.parse(fraction);
  return match.group(1) == null ? cents : -cents;
}

/// Calcula el resumen a partir de las filas `(month, category, total)` de la
/// RPC `spending_by_category`. Filas inválidas se ignoran.
/// Devuelve `null` si no hay ningún gasto en [now] ni en el mes anterior.
SpendingSummary? computeSpendingSummary(
  List<Map<String, Object?>> rows,
  DateTime now,
) {
  final currentKey = _monthKey(now.year, now.month);
  final previousKey = now.month == 1
      ? _monthKey(now.year - 1, 12)
      : _monthKey(now.year, now.month - 1);

  var total = 0;
  var previousTotal = 0;
  var hasPrevious = false;
  final byCategory = <String, int>{};

  for (final row in rows) {
    final month = row['month'];
    final category = row['category'];
    final cents = parseAmountToCents(row['total']);
    if (month is! String || month.length < 7 || cents == null) continue;
    final key = month.substring(0, 7);
    if (key == currentKey) {
      total += cents;
      if (category is String) {
        byCategory[category] = (byCategory[category] ?? 0) + cents;
      }
    } else if (key == previousKey) {
      previousTotal += cents;
      hasPrevious = true;
    }
  }

  if (total == 0 && !hasPrevious) return null;

  String? topCategory;
  var topCents = 0;
  for (final entry in byCategory.entries) {
    if (entry.value > topCents) {
      topCategory = entry.key;
      topCents = entry.value;
    }
  }

  return SpendingSummary(
    totalCents: total,
    topCategory: topCategory,
    topCategoryCents: topCents,
    previousTotalCents: hasPrevious ? previousTotal : null,
  );
}

String _monthKey(int year, int month) =>
    '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
