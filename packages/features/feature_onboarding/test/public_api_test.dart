import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:feature_onboarding/src/data/auth_remote_data_source.dart';
import 'package:feature_onboarding/src/domain/auth_repository.dart';
import 'package:feature_onboarding/src/domain/sign_up.dart';
import 'package:feature_onboarding/src/presentation/login/login_cubit.dart';
import 'package:feature_onboarding/src/presentation/register/register_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  group('registerOnboardingDependencies', () {
    late GetIt getIt;
    late SupabaseClient client;

    setUp(() {
      getIt = GetIt.asNewInstance();
      // Cliente real con URL y clave de mentira: no abre red mientras no se use.
      client = SupabaseClient('https://example.test', 'test-key');
      getIt.registerSingleton<SupabaseClient>(client);
      registerOnboardingDependencies(getIt);
    });

    tearDown(() async {
      await getIt.reset();
      await client.dispose();
    });

    test('registra data source, repositorio y casos de uso', () {
      expect(getIt<AuthRemoteDataSource>(), isA<AuthRemoteDataSource>());
      expect(getIt<AuthRepository>(), isA<AuthRepository>());
      expect(getIt<SignIn>(), isA<SignIn>());
      expect(getIt<SignUp>(), isA<SignUp>());
      expect(getIt<SignOut>(), isA<SignOut>());
      expect(getIt<GetCurrentUser>(), isA<GetCurrentUser>());
      expect(getIt<GetUserProfile>(), isA<GetUserProfile>());
    });

    test('los casos de uso son singletons', () {
      expect(identical(getIt<SignIn>(), getIt<SignIn>()), isTrue);
      expect(identical(getIt<AuthRepository>(), getIt<AuthRepository>()), isTrue);
    });

    test('los Cubits son fábricas: una instancia nueva por resolución', () async {
      final login1 = getIt<LoginCubit>();
      final login2 = getIt<LoginCubit>();
      final register1 = getIt<RegisterCubit>();
      final register2 = getIt<RegisterCubit>();
      expect(identical(login1, login2), isFalse);
      expect(identical(register1, register2), isFalse);
      await login1.close();
      await login2.close();
      await register1.close();
      await register2.close();
    });

    test('sin sesión, GetCurrentUser devuelve null (lectura local)', () {
      expect(getIt<GetCurrentUser>()(), isNull);
    });
  });

  group('barril público', () {
    final exports = File('lib/feature_onboarding.dart')
        .readAsLinesSync()
        .where((l) => l.startsWith('export '))
        .map((l) => l.split("'")[1])
        .toSet();

    test('no exporta nada de data/', () {
      expect(exports.where((e) => e.contains('/data/')), isEmpty);
    });

    test('exporta exactamente la API que necesita el shell', () {
      expect(exports, {
        'src/domain/auth_user.dart',
        'src/domain/get_current_user.dart',
        'src/domain/get_user_profile.dart',
        'src/domain/sign_in.dart',
        'src/domain/sign_out.dart',
        'src/domain/user_profile.dart',
        'src/onboarding_dependencies.dart',
        'src/presentation/login/login_page.dart',
        'src/presentation/register/register_page.dart',
      });
    });
  });
}
