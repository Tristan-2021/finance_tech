class Failure {
  final String message;
  final String? code;
  const Failure(this.message, [this.code]);

  @override
  String toString() => 'Failure(message: $message, code: $code)';

  @override
  bool operator ==(Object other) =>
      other is Failure && other.message == message && other.code == code;

  @override
  int get hashCode => Object.hash(message, code);
}
