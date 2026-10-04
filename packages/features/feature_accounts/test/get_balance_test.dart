import 'package:feature_accounts/feature_accounts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retorna balance para userId válido', () async {
    final r = await GetBalance().call('user-123');
    expect(r.failure, isNull);
    expect(r.balance, 1250.75);
  });

  test('retorna Failure para userId vacío', () async {
    final r = await GetBalance().call('');
    expect(r.balance, isNull);
    expect(r.failure!.code, 'INVALID_INPUT');
  });
}
