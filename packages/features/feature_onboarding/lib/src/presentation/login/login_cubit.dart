import 'package:core_ui/core_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/sign_in.dart';
import '../validators.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final SignIn _signIn;

  LoginCubit(this._signIn) : super(const LoginInitial());

  Future<void> submit({required String email, required String password}) async {
    if (state is LoginLoading) return;

    final emailError = validateEmail(email);
    final passwordError = validatePasswordRequired(password);
    if (emailError != null || passwordError != null) {
      emit(LoginInvalid(emailError: emailError, passwordError: passwordError));
      return;
    }

    emit(const LoginLoading());
    final failure = await _signIn(email: email.trim(), password: password);
    if (isClosed) return;

    if (failure != null) {
      emit(LoginError(messageForFailure(failure)));
    } else {
      emit(const LoginSuccess());
    }
  }
}
