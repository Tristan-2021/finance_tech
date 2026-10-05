import 'package:core_network/core_network.dart';
import 'package:get_it/get_it.dart';

import 'data/account_repository_impl.dart';
import 'data/accounts_remote_data_source.dart';
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

/// Registra en [getIt] data sources, repositorios, casos de uso (singletons
/// perezosos) y las fábricas de Cubit del feature.
///
/// Asume que un `SupabaseClient` ya está registrado en [getIt].
void registerAccountsDependencies(GetIt getIt) {
  getIt
    ..registerLazySingleton<AccountsRemoteDataSource>(
      () => SupabaseAccountsRemoteDataSource(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(getIt<AccountsRemoteDataSource>()),
    )
    ..registerLazySingleton<TransactionsRemoteDataSource>(
      () => SupabaseTransactionsRemoteDataSource(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(getIt<TransactionsRemoteDataSource>()),
    )
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
    );
}
