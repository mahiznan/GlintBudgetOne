import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/currencies.dart';

void main() {
  group('kCurrencies', () {
    test('contains 30 entries', () {
      expect(kCurrencies.length, equals(30));
    });

    test('all entries have non-empty code, name, symbol', () {
      for (final c in kCurrencies) {
        expect(c.code, isNotEmpty);
        expect(c.name, isNotEmpty);
        expect(c.symbol, isNotEmpty);
      }
    });

    test('USD is in the list', () {
      expect(kCurrencies.any((c) => c.code == 'USD'), isTrue);
    });

    test('SGD is in the list', () {
      expect(kCurrencies.any((c) => c.code == 'SGD'), isTrue);
    });

    test('no duplicate codes', () {
      final codes = kCurrencies.map((c) => c.code).toList();
      expect(codes.toSet().length, equals(codes.length));
    });
  });
}
