import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/currency.dart';

void main() {
  group('Currency', () {
    test('fromMap maps all fields', () {
      final c = Currency.fromMap(const {
        'name': 'Singapore Dollar',
        'code': 'SGD',
        'symbol': 'S\$',
      });
      expect(c.name, 'Singapore Dollar');
      expect(c.code, 'SGD');
      expect(c.symbol, 'S\$');
    });

    test('toFirestore round-trips', () {
      const c = Currency(name: 'Euro', code: 'EUR', symbol: '€');
      expect(Currency.fromMap(c.toFirestore()), equals(c));
    });

    test('fromMap handles missing fields with empty strings', () {
      final c = Currency.fromMap(const {});
      expect(c.name, '');
      expect(c.code, '');
      expect(c.symbol, '');
    });

    test('defaults returns USD', () {
      expect(Currency.defaults.code, 'USD');
    });
  });
}
