/// Lanza las excepciones de Supabase; el repositorio las mapea a `Failure`.
abstract class MovementWriteRemoteDataSource {
  /// [type] es `credit` o `debit`; [amount] es una cadena decimal exacta
  /// (`"12.30"`), nunca un `double`.
  Future<void> addMovement({
    required String accountId,
    required String type,
    required String amount,
    required String category,
    required String description,
  });
}
