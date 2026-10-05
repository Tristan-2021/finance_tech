import 'package:core_errors/core_errors.dart';

import '../domain/account.dart';
import '../domain/transaction.dart';
import '../domain/transaction_type.dart';

/// Formato propio de la caché (JSON de las entidades, con montos en centavos).
Map<String, dynamic> accountToJson(Account a) => {
  'id': a.id,
  'name': a.name,
  'type': a.type,
  'currency': a.currency,
  'balanceCents': a.balanceCents,
};

Account accountFromJson(Map<String, dynamic> json) => Account(
  id: json['id'] as String,
  name: json['name'] as String,
  type: json['type'] as String,
  currency: json['currency'] as String,
  balanceCents: json['balanceCents'] as int,
);

Map<String, dynamic> transactionToJson(Transaction t) => {
  'id': t.id,
  'accountId': t.accountId,
  'type': t.type.name,
  'amountCents': t.amountCents,
  'balanceAfterCents': t.balanceAfterCents,
  'createdAt': t.createdAt.toUtc().toIso8601String(),
  'category': t.category,
  'description': t.description,
};

Transaction transactionFromJson(Map<String, dynamic> json) => Transaction(
  id: json['id'] as String,
  accountId: json['accountId'] as String,
  type: TransactionType.values.byName(json['type'] as String),
  amountCents: json['amountCents'] as int,
  balanceAfterCents: json['balanceAfterCents'] as int,
  createdAt: DateTime.parse(json['createdAt'] as String),
  category: json['category'] as String?,
  description: json['description'] as String?,
);

/// Solo se sirve la copia guardada cuando el fallo es de conexión o del
/// servidor (`network` tras agotar reintentos, o 503 → `unknown`). Un fallo de
/// permisos (`rls_denied`) o de sesión (`auth`) nunca se tapa con datos viejos.
bool canServeFromCache(Failure? failure) =>
    failure?.code == 'network' || failure?.code == 'unknown';
