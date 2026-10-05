import 'package:core_errors/core_errors.dart';
import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/data/cached_account_repository.dart';
import 'package:feature_accounts/src/data/cached_transaction_repository.dart';
import 'package:feature_accounts/src/domain/account_repository.dart';
import 'package:feature_accounts/src/domain/stale_list.dart';
import 'package:feature_accounts/src/domain/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'fake_cache_store.dart';
import 'fake_transaction_repository.dart';

const savings = Account(
  id: 'a1',
  name: 'Cuenta de ahorros',
  type: 'savings',
  currency: 'USD',
  balanceCents: 123456,
);

class FakeRemoteAccounts implements AccountRepository {
  List<Account> accounts = [savings];
  Failure? failure;

  @override
  Future<({List<Account>? accounts, Failure? failure})> getAccounts() async =>
      failure == null
      ? (accounts: accounts, failure: null)
      : (accounts: null, failure: failure);
}

void main() {
  late FakeCacheStore cache;
  setUp(() => cache = FakeCacheStore());

  group('CachedAccountRepository', () {
    late FakeRemoteAccounts remote;
    late CachedAccountRepository repo;
    setUp(() {
      remote = FakeRemoteAccounts();
      repo = CachedAccountRepository(remote, cache);
    });

    test('con red devuelve datos frescos y actualiza la caché', () async {
      final r = await repo.getAccounts();

      expect(r.failure, isNull);
      expect(r.accounts, isNot(isA<StaleList<Account>>()));
      expect(r.accounts?.single.balanceCents, 123456);
      expect(cache.entries.containsKey(CachedAccountRepository.cacheKey), isTrue);
    });

    test('si falla la red sirve la copia guardada, marcada con su fecha', () async {
      await repo.getAccounts(); // guarda a las 12:00

      remote.failure = const Failure('sin red', 'network');
      final r = await repo.getAccounts();

      expect(r.failure, isNull);
      final stale = r.accounts as StaleList<Account>;
      expect(stale.cachedAt, DateTime.utc(2026, 10, 4, 12));
      expect(stale.single.id, 'a1');
      expect(stale.single.name, 'Cuenta de ahorros');
      expect(stale.single.balanceCents, 123456);
    });

    test('un 503 agotado (unknown) también sirve la copia', () async {
      await repo.getAccounts();

      remote.failure = const Failure('503', 'unknown');
      final r = await repo.getAccounts();

      expect(r.accounts, isA<StaleList<Account>>());
    });

    test('un fallo de permisos no se tapa con datos viejos', () async {
      await repo.getAccounts();

      remote.failure = const Failure('denegado', 'rls_denied');
      final r = await repo.getAccounts();

      expect(r.accounts, isNull);
      expect(r.failure?.code, 'rls_denied');
    });

    test('sin caché y sin red devuelve el Failure', () async {
      remote.failure = const Failure('sin red', 'network');
      final r = await repo.getAccounts();

      expect(r.accounts, isNull);
      expect(r.failure?.code, 'network');
    });

    test('una copia ilegible se trata como si no existiera', () async {
      cache.entries[CachedAccountRepository.cacheKey] = CacheEntry(
        value: 'esto no es json',
        savedAt: DateTime.utc(2026, 10, 4),
      );
      remote.failure = const Failure('sin red', 'network');

      final r = await repo.getAccounts();

      expect(r.accounts, isNull);
      expect(r.failure?.code, 'network');
    });

    test('un fallo al guardar o leer la caché no rompe la carga', () async {
      cache.failWrites = true;
      final fresh = await repo.getAccounts();
      expect(fresh.accounts?.single.id, 'a1');

      cache.failReads = true;
      remote.failure = const Failure('sin red', 'network');
      final r = await repo.getAccounts();
      expect(r.failure?.code, 'network');
    });
  });

  group('CachedTransactionRepository', () {
    late FakeTransactionRepository remote;
    late CachedTransactionRepository repo;
    setUp(() {
      remote = FakeTransactionRepository()..all = List.generate(25, makeTx);
      repo = CachedTransactionRepository(remote, cache);
    });

    Future<({List<Transaction>? transactions, Failure? failure})> page(
      int offset, {
      String accountId = 'a1',
      int limit = 20,
    }) {
      return repo.getTransactions(
        accountId: accountId,
        offset: offset,
        limit: limit,
      );
    }

    test('la primera página fresca se guarda por cuenta', () async {
      final r = await page(0);

      expect(r.transactions, isNot(isA<StaleList<Transaction>>()));
      expect(r.transactions?.length, 20);
      expect(
        cache.entries.containsKey(CachedTransactionRepository.cacheKey('a1')),
        isTrue,
      );
    });

    test('si falla la red sirve la primera página guardada, con su fecha', () async {
      await page(0);

      remote.failure = const Failure('sin red', 'network');
      final r = await page(0);

      expect(r.failure, isNull);
      final stale = r.transactions as StaleList<Transaction>;
      expect(stale.cachedAt, DateTime.utc(2026, 10, 4, 12));
      expect(stale.length, 20);
      expect(stale.first.id, 't0');
      expect(stale.first.type, TransactionType.credit);
      expect(stale.first.amountCents, 100);
      expect(stale.first.description, 'Mov 0');
      expect(stale[1].type, TransactionType.debit);
      expect(stale.first.createdAt, DateTime.utc(2026, 10, 4, 12));
    });

    test('las páginas siguientes no se guardan ni se sirven de la caché', () async {
      await page(0);
      final before = Map.of(cache.entries);

      await page(20); // éxito en la 2.ª página: no toca la caché
      expect(cache.entries, before);

      remote.failure = const Failure('sin red', 'network');
      final r = await page(20); // falla: no hay copia de la 2.ª página
      expect(r.transactions, isNull);
      expect(r.failure?.code, 'network');
    });

    test('las cuentas no mezclan sus copias', () async {
      await page(0, accountId: 'a1');

      remote.failure = const Failure('sin red', 'network');
      final r = await page(0, accountId: 'a2');

      expect(r.transactions, isNull);
      expect(r.failure?.code, 'network');
    });

    test('respeta el límite pedido al servir la copia', () async {
      await page(0);

      remote.failure = const Failure('sin red', 'network');
      final r = await page(0, limit: 5);

      expect(r.transactions?.length, 5);
    });

    test('un fallo de permisos no se tapa con datos viejos', () async {
      await page(0);

      remote.failure = const Failure('denegado', 'rls_denied');
      final r = await page(0);

      expect(r.transactions, isNull);
      expect(r.failure?.code, 'rls_denied');
    });

    test('sin caché y sin red devuelve el Failure', () async {
      remote.failure = const Failure('sin red', 'network');
      final r = await page(0);

      expect(r.transactions, isNull);
      expect(r.failure?.code, 'network');
    });
  });

  group('registerAccountsDependencies', () {
    late GetIt getIt;
    late SupabaseClient client;

    setUp(() {
      getIt = GetIt.asNewInstance();
      // Cliente real con URL y clave de mentira: no abre red si no se usa.
      client = SupabaseClient('https://example.test', 'test-key');
      getIt.registerSingleton<SupabaseClient>(client);
    });
    tearDown(() async {
      await getIt.reset();
      await client.dispose();
    });

    test('con un CacheStore registrado, los repositorios usan la caché', () {
      getIt.registerSingleton<CacheStore>(cache);
      registerAccountsDependencies(getIt);

      expect(getIt<AccountRepository>(), isA<CachedAccountRepository>());
      expect(
        getIt<TransactionRepository>(),
        isA<CachedTransactionRepository>(),
      );
    });

    test('sin CacheStore, los repositorios van solo contra el servidor', () {
      registerAccountsDependencies(getIt);

      expect(getIt<AccountRepository>(), isNot(isA<CachedAccountRepository>()));
      expect(
        getIt<TransactionRepository>(),
        isNot(isA<CachedTransactionRepository>()),
      );
    });
  });
}
