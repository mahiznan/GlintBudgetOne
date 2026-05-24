import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/transaction.dart';
import 'package:glintbudgetone/core/widgets/transaction_tile.dart';

Transaction _tx({double amount = -50.0, String subCategory = 'Groceries'}) =>
    Transaction(
      id: 't1',
      userId: 'u1',
      category: 'Food',
      subCategory: subCategory,
      date: DateTime(2026, 5, 10),
      account: 'Cash',
      vendor: 'Fairprice',
      payment: 'Card',
      currency: 'SGD',
      notes: '',
      amount: amount,
      icon: '🛒',
    );

void main() {
  group('TransactionTile', () {
    Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

    testWidgets('shows icon, subCategory, vendor', (tester) async {
      await tester.pumpWidget(wrap(TransactionTile(transaction: _tx())));
      expect(find.text('🛒'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Fairprice'), findsOneWidget);
    });

    testWidgets('shows category when subCategory is empty', (tester) async {
      await tester.pumpWidget(wrap(TransactionTile(transaction: _tx(subCategory: ''))));
      expect(find.text('Food'), findsOneWidget);
    });

    testWidgets('negative amount shows minus prefix', (tester) async {
      await tester.pumpWidget(wrap(TransactionTile(transaction: _tx(amount: -50.0))));
      expect(find.textContaining('-50.00'), findsOneWidget);
    });

    testWidgets('positive amount shows plus prefix', (tester) async {
      await tester.pumpWidget(wrap(TransactionTile(transaction: _tx(amount: 100.0))));
      expect(find.textContaining('+100.00'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        TransactionTile(transaction: _tx(), onTap: () => tapped = true),
      ));
      await tester.tap(find.byType(ListTile));
      expect(tapped, isTrue);
    });
  });
}
