import 'transaction_type.dart';

class Transaction {
  final String id;
  final String accountId;
  final TransactionType type;

  /// Texto libre; no es un enum cerrado.
  final String? category;
  final String? description;

  /// Monto siempre positivo, en centavos. El sentido lo da [type].
  final int amountCents;

  /// Saldo de la cuenta tras este movimiento, en centavos.
  final int balanceAfterCents;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amountCents,
    required this.balanceAfterCents,
    required this.createdAt,
    this.category,
    this.description,
  });
}
