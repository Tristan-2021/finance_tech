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

/// Al registrarse: no vacía y de al menos 8 caracteres.
String? validateNewPassword(String value) {
  if (value.isEmpty) return OnboardingStrings.passwordRequired;
  if (value.length < 8) return OnboardingStrings.passwordTooShort;
  return null;
}

String? validateFullName(String value) {
  if (value.trim().isEmpty) return OnboardingStrings.fullNameRequired;
  return null;
}

/// `true` si [birth] ya cumplió 18 años en [today]. El día exacto del
/// cumpleaños 18 cuenta como mayor de edad.
bool isAtLeast18(DateTime birth, DateTime today) {
  var age = today.year - birth.year;
  final birthdayPassed =
      today.month > birth.month ||
      (today.month == birth.month && today.day >= birth.day);
  if (!birthdayPassed) age--;
  return age >= 18;
}

String? validateBirthDate(DateTime? birth, DateTime today) {
  if (birth == null) return OnboardingStrings.birthDateRequired;
  final day = DateTime(birth.year, birth.month, birth.day);
  if (day.isAfter(DateTime(today.year, today.month, today.day))) {
    return OnboardingStrings.birthDateInvalid;
  }
  if (!isAtLeast18(day, today)) return OnboardingStrings.underAge;
  return null;
}
