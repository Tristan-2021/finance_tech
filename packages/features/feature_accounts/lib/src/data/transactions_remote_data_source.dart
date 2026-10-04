/// Lanza las excepciones de Supabase; el repositorio las mapea a `Failure`.
abstract class TransactionsRemoteDataSource {
  /// Filas de `transactions` de [accountId], `created_at` desc con desempate
  /// por `id` desc. RLS filtra por usuario (no se pasa `user_id`).
  Future<List<Map<String, dynamic>>> fetchTransactions({
    required String accountId,
    int offset = 0,
    int limit = 20,
  });
}
