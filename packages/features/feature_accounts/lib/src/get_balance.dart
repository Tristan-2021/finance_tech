import 'package:core_errors/core_errors.dart';

class GetBalance {
  Future<({double? balance, Failure? failure})> call(String userId) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (userId.isEmpty) {
      return (
        balance: null,
        failure: const Failure('userId vacío', 'INVALID_INPUT'),
      );
    }
    // Dummy real: luego será Supabase. Ahora demuestra el flujo + resiliencia.
    return (balance: 1250.75, failure: null);
  }
}
