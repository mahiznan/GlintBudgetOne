import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/transaction.dart' as transaction_model;

void main() {
  group('Transaction', () {
    final sampleDate = DateTime(2026, 5, 10, 12, 0);

    final sampleMap = {
      'user_id': 'uid-123',
      'category': 'Food',
      'sub_category': 'Groceries',
      'date': Timestamp.fromDate(sampleDate),
      'account': 'DBS',
      'vendor': 'FairPrice',
      'payment': 'Visa',
      'currency': 'SGD',
      'notes': 'weekly shop',
      'amount': 42.50,
      'icon': '🛒',
    };

    test('fromMap maps all fields correctly', () {
      final t = transaction_model.Transaction.fromMap('txn-1', sampleMap);
      expect(t.id, 'txn-1');
      expect(t.userId, 'uid-123');
      expect(t.category, 'Food');
      expect(t.subCategory, 'Groceries');
      expect(t.date, sampleDate);
      expect(t.account, 'DBS');
      expect(t.vendor, 'FairPrice');
      expect(t.payment, 'Visa');
      expect(t.currency, 'SGD');
      expect(t.notes, 'weekly shop');
      expect(t.amount, 42.50);
      expect(t.icon, '🛒');
    });

    test('toFirestore writes correct Firestore field names', () {
      final t = transaction_model.Transaction.fromMap('txn-1', sampleMap);
      final map = t.toFirestore();
      expect(map.containsKey('user_id'), isTrue);
      expect(map.containsKey('sub_category'), isTrue);
      expect(map['user_id'], 'uid-123');
      expect(map['sub_category'], 'Groceries');
      expect(map['date'], isA<Timestamp>());
      expect((map['date'] as Timestamp).toDate(), sampleDate);
    });

    test('fromMap defaults missing fields gracefully', () {
      final t = transaction_model.Transaction.fromMap('txn-x', const <String, dynamic>{});
      expect(t.id, 'txn-x');
      expect(t.userId, '');
      expect(t.amount, 0.0);
    });

    test('amount handles int Firestore values', () {
      final t = transaction_model.Transaction.fromMap('txn-2', {...sampleMap, 'amount': 100});
      expect(t.amount, 100.0);
    });
  });
}
