/// Usuario autenticado. Entidad propia: el dominio no expone el `User` de
/// Supabase.
class AuthUser {
  final String id;
  final String email;

  const AuthUser({required this.id, required this.email});

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}
