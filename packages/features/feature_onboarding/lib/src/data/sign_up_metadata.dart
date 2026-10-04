import '../domain/sign_up_params.dart';

/// Metadata que el backend lee en el trigger de registro.
Map<String, dynamic> signUpMetadata(SignUpParams params) {
  final d = params.birthDate;
  final birthDate =
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return {
    'full_name': params.fullName,
    'birth_date': birthDate,
    'account_usage': params.accountUsage,
  };
}
