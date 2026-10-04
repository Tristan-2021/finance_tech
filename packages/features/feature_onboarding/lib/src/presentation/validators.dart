import 'onboarding_strings.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// `null` si es válido; si no, el mensaje de error del campo.
String? validateEmail(String value) {
  final email = value.trim();
  if (email.isEmpty) return OnboardingStrings.emailRequired;
  if (!_emailPattern.hasMatch(email)) return OnboardingStrings.emailInvalid;
  return null;
}

/// En el login solo se exige que no esté vacía.
String? validatePasswordRequired(String value) {
  if (value.isEmpty) return OnboardingStrings.passwordRequired;
  return null;
}
