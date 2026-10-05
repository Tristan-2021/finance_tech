import 'package:core_network/core_network.dart';
import 'package:feature_accounts/src/data/money_parser.dart';
import 'package:feature_accounts/src/data/supabase_movement_write_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');
const _email = String.fromEnvironment('DEMO_EMAIL', defaultValue: 'joven@demo.com');
const _password = String.fromEnvironment('DEMO_PASSWORD', defaultValue: 'demo1234');

/// Contra el backend local real: confirma que `add_demo_movement` acepta el
/// monto como cadena decimal para su parámetro `numeric`. Crea un movimiento de
/// 0.01 y comprueba que el saldo sube exactamente un centavo.
///
/// Necesita `supabase start`, el usuario demo y los `--dart-define`; sin ellos
/// se omite (así no afecta al CI). Se corre a mano:
/// `flutter test test/movement_rpc_integration_test.dart
/// --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
void main() {
  test(
    'add_demo_movement acepta la cadena decimal y suma un centavo al saldo',
    () async {
      final client = SupabaseClient(_url, _key);
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(email: _email, password: _password);

      Future<({String id, int cents})> firstAccount() async {
        final rows = await client.from('accounts').select();
        return (
          id: rows.first['id'] as String,
          cents: parseCents(rows.first['balance']),
        );
      }

      final before = await firstAccount();
      await SupabaseMovementWriteRemoteDataSource(client).addMovement(
        accountId: before.id,
        type: 'credit',
        amount: '0.01',
        category: 'otros',
        description: 'Prueba de integración',
      );
      final after = await firstAccount();

      expect(after.cents, before.cents + 1);
    },
    skip: _url.isEmpty || _key.isEmpty
        ? 'Faltan SUPABASE_URL y SUPABASE_ANON_KEY (--dart-define)'
        : null,
  );
}
