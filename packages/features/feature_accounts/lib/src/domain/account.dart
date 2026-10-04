class Account {
  final String id;
  final String name;
  final String type;
  final String currency;

  /// Saldo en centavos. Los montos nunca pasan por `double`.
  final int balanceCents;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.balanceCents,
  });
}
