import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/budget_data.dart';

void main() {
  group('BudgetData', () {
    test('fromMap maps all fields', () {
      final b = BudgetData.fromMap(const {
        'name': 'Groceries',
        'type': 'category',
        'emoji': '🛒',
        'parent': null,
      });
      expect(b.name, 'Groceries');
      expect(b.type, 'category');
      expect(b.emoji, '🛒');
      expect(b.parent, isNull);
    });

    test('fromMap handles optional fields absent', () {
      final b = BudgetData.fromMap(const {'name': 'Visa', 'type': 'payment'});
      expect(b.emoji, isNull);
      expect(b.parent, isNull);
    });

    test('toMap round-trips all fields', () {
      const b = BudgetData(name: 'Food', type: 'sub_category', emoji: '🍔', parent: 'category');
      final map = b.toMap();
      expect(map['name'], 'Food');
      expect(map['type'], 'sub_category');
      expect(map['emoji'], '🍔');
      expect(map['parent'], 'category');
    });

    test('toMap omits null optional fields', () {
      const b = BudgetData(name: 'DBS', type: 'account');
      final map = b.toMap();
      expect(map.containsKey('emoji'), isFalse);
      expect(map.containsKey('parent'), isFalse);
    });
  });
}
