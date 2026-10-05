import 'package:feature_accounts/src/domain/movement_amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateAmount: texto a centavos', () {
    test('enteros, coma o punto y hasta dos decimales', () {
      expect(validateAmount('12').cents, 1200);
      expect(validateAmount('12.3').cents, 1230);
      expect(validateAmount('12,30').cents, 1230);
      expect(validateAmount('0.05').cents, 5);
      expect(validateAmount(' 7 ').cents, 700);
      expect(validateAmount('.5').cents, 50);
      expect(validateAmount('12.').cents, 1200);
    });

    test('vacío', () {
      expect(validateAmount('').error, AmountError.empty);
      expect(validateAmount('   ').error, AmountError.empty);
    });

    test('texto no numérico', () {
      expect(validateAmount('abc').error, AmountError.invalid);
      expect(validateAmount('1,2,3').error, AmountError.invalid);
      expect(validateAmount('-5').error, AmountError.invalid);
      expect(validateAmount('.').error, AmountError.invalid);
    });

    test('más de dos decimales', () {
      expect(validateAmount('1.234').error, AmountError.tooManyDecimals);
      expect(validateAmount('0,001').error, AmountError.tooManyDecimals);
    });

    test('cero', () {
      expect(validateAmount('0').error, AmountError.notPositive);
      expect(validateAmount('0.00').error, AmountError.notPositive);
    });

    test('tope', () {
      expect(validateAmount('1000000').cents, maxMovementCents);
      expect(validateAmount('1000000.01').error, AmountError.tooLarge);
      expect(validateAmount('1234567890123').error, AmountError.tooLarge);
    });

    test('un resultado válido no trae error y uno inválido no trae centavos', () {
      expect(validateAmount('1').error, isNull);
      expect(validateAmount('x').cents, isNull);
    });
  });

  group('centsToDecimalString: centavos a cadena decimal exacta', () {
    test('casos', () {
      expect(centsToDecimalString(1230), '12.30');
      expect(centsToDecimalString(5), '0.05');
      expect(centsToDecimalString(0), '0.00');
      expect(centsToDecimalString(100), '1.00');
      expect(centsToDecimalString(123456789), '1234567.89');
    });

    test('es el inverso de validateAmount', () {
      for (final cents in [1, 5, 99, 100, 1230, 99999999]) {
        expect(validateAmount(centsToDecimalString(cents)).cents, cents);
      }
    });

    test('rechaza negativos', () {
      expect(() => centsToDecimalString(-1), throwsArgumentError);
    });
  });
}
