import 'package:core_errors/core_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Failure guarda message y code', () {
    const f = Failure('sin red', 'NETWORK');
    expect(f.message, 'sin red');
    expect(f.code, 'NETWORK');
  });
  test('dos Failure iguales son ==', () {
    expect(const Failure('a'), const Failure('a'));
  });
}
