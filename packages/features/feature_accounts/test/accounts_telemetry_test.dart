import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:core_telemetry/core_telemetry.dart';
import 'package:feature_accounts/src/data/account_repository_impl.dart';
import 'package:feature_accounts/src/data/accounts_remote_data_source.dart';
import 'package:feature_accounts/src/data/cached_account_repository.dart';
import 'package:feature_accounts/src/data/cached_transaction_repository.dart';
import 'package:feature_accounts/src/data/transaction_repository_impl.dart';
import 'package:feature_accounts/src/data/transactions_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_cache_store.dart';

class _FakeTelemetry implements Telemetry {
  final events = <({String name, Map<String, Object?> params})>[];
  final traces = <String>[];

  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) =>
      events.add((name: name, params: params));

  @override
  void recordError(Object error, StackTrace stack, {bool fatal = false, String? reason}) {}

  @override
  void setSegment(String? segment) {}

  @override
  Future<T> trace<T>(String name, Future<T> Function() action) {
    traces.add(name);
    return action();
  }

  List<String> get names => events.map((e) => e.name).toList();
}

class _FakeAccountsRemote implements AccountsRemoteDataSource {
  Object? error;

  @override
  Future<List<Map<String, dynamic>>> fetchAccounts() async {
    if (error != null) throw error!;
    return [
      {
        'id': 'a1',
        'name': 'Cuenta de ahorros',
        'type': 'savings',
        'currency': 'USD',
        'balance': '500.00',
      },
    ];
  }
}

class _FakeTransactionsRemote implements TransactionsRemoteDataSource {
  Object? error;

  @override
  Future<List<Map<String, dynamic>>> fetchTransactions({
    required String accountId,
    int offset = 0,
    int limit = 20,
  }) async {
    if (error != null) throw error!;
    return [
      {
        'id': 't1',
        'account_id': accountId,
        'type': 'debit',
        'category': 'comida',
        'description': 'Almuerzo',
        'amount': '12.30',
        'balance_after': '487.70',
        'created_at': '2026-10-04T12:00:00Z',
      },
    ];
  }
}

const _offline = SocketException('sin conexión');

void main() {
  late _FakeTelemetry telemetry;
  late FakeCacheStore cache;

  setUp(() {
    telemetry = _FakeTelemetry();
    cache = FakeCacheStore();
  });

  void expectPrivate() {
    for (final event in telemetry.events) {
      expect(TelemetrySanitizer.allowedKeys, containsAll(event.params.keys));
      final values = event.params.values.join(' ');
      for (final secret in ['Cuenta', 'Almuerzo', '500', '12.30', '@']) {
        expect(values, isNot(contains(secret)), reason: event.name);
      }
    }
  }

  group('cuentas', () {
    late _FakeAccountsRemote remote;
    late CachedAccountRepository repo;

    setUp(() {
      remote = _FakeAccountsRemote();
      repo = CachedAccountRepository(
        AccountRepositoryImpl(remote, telemetry: telemetry),
        cache,
        telemetry: telemetry,
      );
    });

    test('con red: mide la carga y no emite eventos de degradación', () async {
      await repo.getAccounts();
      expect(telemetry.traces, ['load_balance']);
      expect(telemetry.events, isEmpty);
    });

    test('sin red y con caché: retry_exhausted y cache_served', () async {
      await repo.getAccounts(); // guarda la copia
      remote.error = _offline;

      final result = await repo.getAccounts();

      expect(result.accounts, isNotNull);
      expect(telemetry.names, ['retry_exhausted', 'cache_served']);
      expect(telemetry.events.first.params, {'source': 'accounts', 'code': 'network'});
      expect(telemetry.events.last.params, {'source': 'accounts'});
      expectPrivate();
    });

    test('sin red y sin caché: solo retry_exhausted', () async {
      remote.error = _offline;
      final result = await repo.getAccounts();

      expect(result.accounts, isNull);
      expect(telemetry.names, ['retry_exhausted']);
    });

    test('un fallo que no es de red no emite nada', () async {
      remote.error = PostgrestException(message: 'denegado', code: '42501');
      await repo.getAccounts();
      expect(telemetry.events, isEmpty);
    });
  });

  group('movimientos', () {
    late _FakeTransactionsRemote remote;
    late CachedTransactionRepository repo;

    setUp(() {
      remote = _FakeTransactionsRemote();
      repo = CachedTransactionRepository(
        TransactionRepositoryImpl(remote, telemetry: telemetry),
        cache,
        telemetry: telemetry,
      );
    });

    Future<void> load({int offset = 0}) =>
        repo.getTransactions(accountId: 'a1', offset: offset, limit: 20);

    test('con red: mide la carga y no emite eventos de degradación', () async {
      await load();
      expect(telemetry.traces, ['load_movements']);
      expect(telemetry.events, isEmpty);
    });

    test('sin red y con caché: retry_exhausted y cache_served', () async {
      await load();
      remote.error = _offline;
      await load();

      expect(telemetry.names, ['retry_exhausted', 'cache_served']);
      expect(telemetry.events.first.params, {'source': 'movements', 'code': 'network'});
      expect(telemetry.events.last.params, {'source': 'movements'});
      expectPrivate();
    });

    test('sin red y sin caché: solo retry_exhausted', () async {
      remote.error = _offline;
      await load();
      expect(telemetry.names, ['retry_exhausted']);
    });

    test('las páginas siguientes nunca se sirven de la caché', () async {
      await load();
      remote.error = _offline;
      await load(offset: 20);
      expect(telemetry.names, ['retry_exhausted']);
    });
  });
}
