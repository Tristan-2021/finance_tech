/// Perfil del usuario. El [segment] lo calcula el backend; la app solo lo lee.
class UserProfile {
  final String fullName;
  final String segment;

  const UserProfile({required this.fullName, required this.segment});

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.fullName == fullName &&
      other.segment == segment;

  @override
  int get hashCode => Object.hash(fullName, segment);
}
