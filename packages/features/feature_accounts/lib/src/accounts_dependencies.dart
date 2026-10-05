import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:get_it/get_it.dart';

import 'data/account_repository_impl.dart';
import 'data/accounts_remote_data_source.dart';
import 'data/cached_account_repository.dart';
import 'data/cached_transaction_repository.dart';
import 'data/supabase_accounts_remote_data_source.dart';
import 'data/supabase_transactions_remote_data_source.dart';
import 'data/transaction_repository_impl.dart';
import 'data/transactions_remote_data_source.dart';
import 'domain/account_repository.dart';
import 'domain/get_accounts.dart';
import 'domain/get_balance.dart';
import 'domain/get_transactions.dart';
import 'domain/transaction_repository.dart';
import 'presentation/accounts_cubit.dart';
import 'presentation/movements_cubit.dart';

/// Registra en [getIt] data sources, repositorios, casos de uso (singletons
/// perezosos) y las fábricas de Cubit del feature.
///
/// Asume que un `SupabaseClient` ya está registrado en [getIt]. Si además hay
/// un [CacheStore] registrado, los repositorios guardan y sirven copias
/// (*cache-then-network*); si no, funcionan solo contra el servidor.
void registerAccountsDependencies(GetIt getIt) {
  getIt
    ..registerLazySingleton<AccountsRemoteDataSource>(
      () => SupabaseAccountsRemoteDataSource(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<AccountRepository>(() {
      final AccountRepository remote = AccountRepositoryImpl(
        getIt<AccountsRemoteDataSource>(),
      );
      return getIt.isRegistered<CacheStore>()
          ? CachedAccountRepository(remote, getIt<CacheStore>())
          : remote;
    })
    ..registerLazySingleton<TransactionsRemoteDataSource>(
      () => SupabaseTransactionsRemoteDataSource(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<TransactionRepository>(() {
      final TransactionRepository remote = TransactionRepositoryImpl(
        getIt<TransactionsRemoteDataSource>(),
      );
      return getIt.isRegistered<CacheStore>()
          ? CachedTransactionRepository(remote, getIt<CacheStore>())
          : remote;
    })
    ..registerLazySingleton<GetAccounts>(
      () => GetAccounts(getIt<AccountRepository>()),
    )
    ..registerLazySingleton<GetBalance>(
      () => GetBalance(getIt<AccountRepository>()),
    )
    ..registerLazySingleton<GetTransactions>(
      () => GetTransactions(getIt<TransactionRepository>()),
    )
    ..registerFactory<AccountsCubit>(
      () => AccountsCubit(getIt<GetAccounts>()),
    )
    ..registerLazySingleton<MovementsCubitFactory>(
      () =>
          (accountId) => MovementsCubit(getIt<GetTransactions>(), accountId),
    );
}
