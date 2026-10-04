import 'dart:async';
import 'dart:io';

import 'package:core_errors/core_errors.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

Failure mapToFailure(Object e) {
  if (e is PostgrestException) {
    if (e.code == '42501') {
      return const Failure('Acceso denegado por RLS', 'rls_denied');
    }
    if ((e.code ?? '').contains('insufficient_funds') ||
        e.message.contains('insufficient_funds')) {
      return const Failure('Saldo insuficiente', 'insufficient_funds');
    }
    return Failure(e.message, 'unknown');
  }
  if (e is AuthException) return Failure(e.message, 'auth');
  if (e is SocketException ||
      e is TimeoutException ||
      e is http.ClientException) {
    return Failure(e.toString(), 'network');
  }
  return Failure(e.toString(), 'unknown');
}
