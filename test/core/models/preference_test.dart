// test/core/models/preference_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/currency.dart';
import 'package:glintbudgetone/core/models/preference.dart';

void main() {
  group('Preference.defaults', () {
    test('has USD default currency', () {
      expect(Preference.defaults().defaultCurrency.code, 'USD');
    });

    test('themeId defaults to null', () {
      expect(Preference.defaults().themeId, isNull);
    });
  });

  group('Preference.fromMap – defaultEntries', () {
    test('decodes flat alternating array from Swift', () {
      final pref = Preference.fromMap(const {
        'default_entries': ['vendor', 'FairPrice', 'category', 'Food'],
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      expect(pref.defaultEntries['vendor'], 'FairPrice');
      expect(pref.defaultEntries['category'], 'Food');
    });

    test('decodes already-normalised Firestore Map', () {
      final pref = Preference.fromMap(const {
        'default_entries': {'vendor': 'NTUC', 'category': 'Groceries'},
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      expect(pref.defaultEntries['vendor'], 'NTUC');
    });

    test('handles missing default_entries', () {
      final pref = Preference.fromMap(const {
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      expect(pref.defaultEntries, isEmpty);
    });

    test('handles odd-length flat array safely', () {
      final pref = Preference.fromMap(const {
        'default_entries': ['vendor', 'FairPrice', 'dangling'],
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      expect(pref.defaultEntries['vendor'], 'FairPrice');
      expect(pref.defaultEntries.length, 1);
    });
  });

  group('Preference.fromMap – other fields', () {
    test('maps bookmarkedCurrencies from frequent_currencies', () {
      final pref = Preference.fromMap(const {
        'frequent_currencies': ['SGD', 'EUR'],
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      expect(pref.bookmarkedCurrencies, containsAll(['SGD', 'EUR']));
    });

    test('reads themeId and spendingChartType', () {
      final pref = Preference.fromMap(const {
        'themeId': 'forest',
        'spendingChartType': 'line',
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      expect(pref.themeId, 'forest');
      expect(pref.spendingChartType, 'line');
    });

    test('maps accounts list', () {
      final pref = Preference.fromMap(const {
        'accounts': [
          {'name': 'DBS', 'type': 'account'},
        ],
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      expect(pref.accounts?.first.name, 'DBS');
    });
  });

  group('Preference.toFirestore', () {
    test('writes default_entries as a Map (normalised format)', () {
      final pref = Preference.fromMap(const {
        'default_entries': ['vendor', 'FairPrice'],
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      final written = pref.toFirestore();
      expect(written['default_entries'], isA<Map>());
      expect((written['default_entries'] as Map)['vendor'], 'FairPrice');
    });

    test('writes frequent_currencies for bookmarkedCurrencies', () {
      const pref = Preference(
        defaultCurrency: Currency.defaults,
        bookmarkedCurrencies: ['SGD'],
        defaultEntries: {},
      );
      expect(pref.toFirestore()['frequent_currencies'], ['SGD']);
    });
  });
}
