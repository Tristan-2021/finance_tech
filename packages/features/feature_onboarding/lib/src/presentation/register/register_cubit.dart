import 'package:core_ui/core_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/get_current_user.dart';
import '../../domain/sign_up.dart';
import '../../domain/sign_up_params.dart';
import '../onboarding_strings.dart';
import '../validators.dart';
import 'register_state.dart';

class RegisterCubit extends Cubit<RegisterState> {
  final SignUp _signUp;
  final GetCurrentUser _getCurrentUser;
  final DateTime Function() _clock;

  /// Solo en memoria y fuera del estado. Se borra al terminar.
  String _password = '';

  RegisterCubit({
    required this._signUp,
    required this._getCurrentUser,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const RegisterState());

  /// "Hoy" según el reloj inyectado (la vista lo usa para el selector).
  DateTime get today => _clock();

  /// Paso 1 -> 2.
  void nextFromCredentials({required String email, required String password}) {
    final emailError = validateEmail(email);
    final passwordError = validateNewPassword(password);
    if (emailError != null || passwordError != null) {
      emit(
        state.copyWith(emailError: emailError, passwordError: passwordError),
      );
      return;
    }
    _password = password;
    emit(state.copyWith(email: email.trim(), step: 2));
  }

  /// Paso 2 -> 3. Exige ser mayor de 18 años.
  void nextFromProfile({required String fullName, required DateTime? birthDate}) {
    final nameError = validateFullName(fullName);
    final birthError = validateBirthDate(birthDate, today);
    if (nameError != null || birthError != null) {
      emit(
        state.copyWith(
          fullName: fullName.trim(),
          birthDate: birthDate,
          fullNameError: nameError,
          birthDateError: birthError,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        fullName: fullName.trim(),
        birthDate: DateTime(birthDate!.year, birthDate.month, birthDate.day),
        step: 3,
      ),
    );
  }

  void selectUsage(String usage) {
    emit(state.copyWith(accountUsage: usage));
  }

  /// Vuelve un paso conservando lo ingresado. En el paso 1 no hace nada: salir
  /// del flujo lo resuelve el shell.
  void back() {
    if (state.status == RegisterStatus.submitting || state.step <= 1) return;
    emit(state.copyWith(step: state.step - 1));
  }

  /// Paso 3: crea la cuenta.
  Future<void> submit() async {
    if (state.status == RegisterStatus.submitting) return;
    final usage = state.accountUsage;
    final birthDate = state.birthDate;
    if (usage == null) {
      emit(state.copyWith(usageError: OnboardingStrings.usageRequired));
      return;
    }
    if (birthDate == null) return;

    emit(state.copyWith(status: RegisterStatus.submitting));
    final failure = await _signUp(
      SignUpParams(
        email: state.email,
        password: _password,
        fullName: state.fullName,
        birthDate: birthDate,
        accountUsage: usage,
      ),
    );
    if (isClosed) return;

    if (failure != null) {
      emit(
        state.copyWith(
          status: RegisterStatus.error,
          message: messageForFailure(failure),
        ),
      );
      return;
    }

    _password = '';
    final user = _getCurrentUser();
    emit(
      state.copyWith(
        status: user != null
            ? RegisterStatus.registered
            : RegisterStatus.confirmEmail,
      ),
    );
  }
}
