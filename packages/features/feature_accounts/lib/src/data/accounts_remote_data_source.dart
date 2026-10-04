/// Lanza las excepciones de Supabase; el repositorio las mapea a `Failure`.
abstract class AccountsRemoteDataSource {
  /// Filas de `accounts` del usuario autenticado (RLS filtra, sin `user_id`).
  Future<List<Map<String, dynamic>>> fetchAccounts();
}
