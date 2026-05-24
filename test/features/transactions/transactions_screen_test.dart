import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/transaction.dart';
import 'package:glintbudgetone/core/store/derived_providers.dart';
import 'package:glintbudgetone/features/transactions/transactions_screen.dart';
import 'package:go_router/go_router.dart';

Transaction makeTx(String id, String vendor) => Transaction(
      id: id,
      userId: 'u1',
      category: 'Food',
      subCategory: 'Groceries',
      date: DateTime(2026, 5, 10),
      account: 'Cash',
      vendor: vendor,
      payment: 'Card',
      currency: 'SGD',
      notes: '',
      amount: -20.0,
      icon: '🛒',
    );

GoRouter buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const TransactionsScreen()),
        GoRoute(path: '/app/add', builder: (_, __) => const SizedBox()),
      ],
    );

void main() {
  testWidgets('shows search field and FAB when empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchedTransactionsProvider.overrideWith((ref) => []),
        ],
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    await tester.pump();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('renders transaction tiles for provided transactions',
      (tester) async {
    final txns = [makeTx('1', 'Fairprice'), makeTx('2', 'Grab')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchedTransactionsProvider.overrideWith((ref) => txns),
        ],
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    await tester.pump();
    expect(find.text('Fairprice'), findsOneWidget);
    expect(find.text('Grab'), findsOneWidget);
  });
}
