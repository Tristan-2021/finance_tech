class SignUpParams {
  final String email;
  final String password;
  final String fullName;
  final DateTime birthDate;
  final String accountUsage;

  const SignUpParams({
    required this.email,
    required this.password,
    required this.fullName,
    required this.birthDate,
    required this.accountUsage,
  });
}
