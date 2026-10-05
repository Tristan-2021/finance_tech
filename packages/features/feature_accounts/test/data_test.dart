import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:feature_accounts/src/data/account_repository_impl.dart';
import 'package:feature_accounts/src/data/accounts_remote_data_source.dart';
import 'package:feature_accounts/src/data/money_parser.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRemote implements AccountsRemoteDataSource {
  Object? error;
  List<Map<String, dynamic>> rows = [];

  @override
  Future<List<Map<String, dynamic>>> fetchAccounts() async {
    if (error != null) throw error!;
    return rows;
  }
}

Map<String, dynamic> row(Object? balance) => {
  'id': 'a1',
  'name': 'Cuenta principal',
  'type': 'checking',
  'currency': 'USD',
  'balance': balance,
};

void main() {
  group('parseCents', () {
    test('String con 2 decimales', () => expect(parseCents('500.00'), 50000));
    test('String sin decimales', () => expect(parseCents('500'), 50000));
    test('un decimal', () => expect(parseCents('12.5'), 1250));
    test('num int', () => expect(parseCents(500), 50000));
    test('num double', () => expect(parseCents(1250.75), 125075));
    test('0.07 no pierde precisión', () => expect(parseCents('0.07'), 7));
    test('negativo', () => expect(parseCents('-3.10'), -310));
    test('monto grande de numeric(14,2)', () {
      expect(parseCents('999999999999.99'), 99999999999999);
    });
    test('decimales extra en cero se aceptan', () {
      expect(parseCents('1.500'), 150);
    });
    test('más de 2 decimales significativos falla', () {
      expect(() => parseCents('1.005'), throwsFormatException);
    });
    test('basura falla', () {
      expect(() => parseCents('abc'), throwsFormatException);
      expect(() => parseCents(null), throwsFormatException);
    });
  });

  group('AccountRepositoryImpl', () {
    late FakeRemote remote;
    late AccountRepositoryImpl repo;
    setUp(() {
      remote = FakeRemote();
      repo = AccountRepositoryImpl(remote);
    });

    test('mapea filas a Account con balance en centavos', () async {
      remote.rows = [row('500.00')];
      final r = await repo.getAccounts();
      expect(r.failure, isNull);
      expect(r.accounts?.single.id, 'a1');
      expect(r.accounts?.single.currency, 'USD');
      expect(r.accounts?.single.balanceCents, 50000);
    });

    test('sin filas -> lista vacía', () async {
      final r = await repo.getAccounts();
      expect(r.accounts, isEmpty);
      expect(r.failure, isNull);
    });

    test('42501 -> rls_denied', () async {
      remote.error = PostgrestException(message: 'denied', code: '42501');
      final r = await repo.getAccounts();
      expect(r.accounts, isNull);
      expect(r.failure?.code, 'rls_denied');
    });

    test('SocketException -> network', () async {
      remote.error = const SocketException('sin red');
      final r = await repo.getAccounts();
      expect(r.failure?.code, 'network');
    });

    test('saldo insuficiente -> insufficient_funds', () async {
      remote.error = PostgrestException(message: 'insufficient_funds');
      final r = await repo.getAccounts();
      expect(r.failure?.code, 'insufficient_funds');
    });

    test('balance corrupto -> unknown', () async {
      remote.rows = [row('abc')];
      final r = await repo.getAccounts();
      expect(r.accounts, isNull);
      expect(r.failure?.code, 'unknown');
    });
  });
}
