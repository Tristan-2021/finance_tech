import 'package:core_network/core_network.dart';
import 'package:core_telemetry/core_telemetry.dart';
import 'package:get_it/get_it.dart';

import 'data/auth_remote_data_source.dart';
import 'data/auth_repository_impl.dart';
import 'data/supabase_auth_remote_data_source.dart';
import 'domain/auth_repository.dart';
import 'domain/get_current_user.dart';
import 'domain/get_user_profile.dart';
import 'domain/sign_in.dart';
import 'domain/sign_out.dart';
import 'domain/sign_up.dart';
import 'presentation/login/login_cubit.dart';
import 'presentation/register/register_cubit.dart';

/// Registra en [getIt] todo lo que necesita el feature: data source,
/// repositorio, casos de uso (singletons perezosos) y fábricas de Cubit.
///
/// Asume que un `SupabaseClient` ya está registrado en [getIt]. Si hay un
/// `Telemetry` registrado, los Cubits emiten el embudo del registro y los fallos
/// de login; si no, no emiten nada.
void registerOnboardingDependencies(GetIt getIt) {
  Telemetry telemetry() =>
      getIt.isRegistered<Telemetry>() ? getIt<Telemetry>() : const NoopTelemetry();

  getIt
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => SupabaseAuthRemoteDataSource(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(getIt<AuthRemoteDataSource>()),
    )
    ..registerLazySingleton<SignIn>(() => SignIn(getIt<AuthRepository>()))
    ..registerLazySingleton<SignUp>(() => SignUp(getIt<AuthRepository>()))
    ..registerLazySingleton<SignOut>(() => SignOut(getIt<AuthRepository>()))
    ..registerLazySingleton<GetCurrentUser>(
      () => GetCurrentUser(getIt<AuthRepository>()),
    )
    ..registerLazySingleton<GetUserProfile>(
      () => GetUserProfile(getIt<AuthRepository>()),
    )
    ..registerFactory<LoginCubit>(
      () => LoginCubit(getIt<SignIn>(), telemetry: telemetry()),
    )
    ..registerFactory<RegisterCubit>(
      () => RegisterCubit(
        signUp: getIt<SignUp>(),
        getCurrentUser: getIt<GetCurrentUser>(),
        telemetry: telemetry(),
      ),
    );
}
