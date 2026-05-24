// test/core/store/derived_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/dashboard_stats.dart';
import 'package:glintbudgetone/core/models/transaction.dart';
import 'package:glintbudgetone/core/store/derived_providers.dart';
import 'package:glintbudgetone/core/store/firestore_providers.dart';

Transaction _tx(String id, DateTime date, double amount, String category) =>
    Transaction(
      id: id,
      userId: 'uid',
      category: category,
      subCategory: '',
      date: date,
      account: '',
      vendor: '',
      payment: '',
      currency: 'SGD',
      notes: '',
      amount: amount,
      icon: '',
    );

void main() {
  group('filteredTransactionsProvider', () {
    test('returns only transactions in the selected month', () async {
      final may = _tx('1', DateTime(2026, 5, 15), 50.0, 'Food');
      final april = _tx('2', DateTime(2026, 4, 10), 30.0, 'Transport');
      final may2 = _tx('3', DateTime(2026, 5, 1), 20.0, 'Food');

      final container = ProviderContainer(overrides: [
        transactionsStreamProvider.overrideWith((_) async* {
          yield [may, april, may2];
        }),
      ]);
      addTearDown(container.dispose);

      await container.read(transactionsStreamProvider.future);
      container.read(selectedMonthProvider.notifier).state = DateTime(2026, 5);

      final filtered = container.read(filteredTransactionsProvider);
      expect(filtered.length, 2);
      expect(filtered.map((t) => t.id), containsAll(['1', '3']));
    });

    test('returns empty list when no transactions in month', () async {
      final container = ProviderContainer(overrides: [
        transactionsStreamProvider.overrideWith((_) async* {
          yield [_tx('1', DateTime(2026, 4, 10), 50.0, 'Food')];
        }),
      ]);
      addTearDown(container.dispose);

      await container.read(transactionsStreamProvider.future);
      container.read(selectedMonthProvider.notifier).state = DateTime(2026, 5);

      expect(container.read(filteredTransactionsProvider), isEmpty);
    });
  });

  group('dashboardStatsProvider', () {
    test('sums income (positive) and expense (negative) separately', () async {
      final txns = [
        _tx('1', DateTime(2026, 5, 1), 1000.0, 'Salary'),
        _tx('2', DateTime(2026, 5, 2), -80.0, 'Food'),
        _tx('3', DateTime(2026, 5, 3), -20.0, 'Transport'),
      ];

      final container = ProviderContainer(overrides: [
        transactionsStreamProvider.overrideWith((_) async* {
          yield txns;
        }),
      ]);
      addTearDown(container.dispose);

      await container.read(transactionsStreamProvider.future);
      container.read(selectedMonthProvider.notifier).state = DateTime(2026, 5);

      final stats = container.read(dashboardStatsProvider);
      expect(stats.totalIncome, closeTo(1000.0, 0.001));
      expect(stats.totalExpense, closeTo(100.0, 0.001));
      expect(stats.balance, closeTo(900.0, 0.001));
    });

    test('builds categoryBreakdown from expense transactions', () async {
      final txns = [
        _tx('1', DateTime(2026, 5, 1), -80.0, 'Food'),
        _tx('2', DateTime(2026, 5, 2), -40.0, 'Food'),
        _tx('3', DateTime(2026, 5, 3), -30.0, 'Transport'),
      ];

      final container = ProviderContainer(overrides: [
        transactionsStreamProvider.overrideWith((_) async* {
          yield txns;
        }),
      ]);
      addTearDown(container.dispose);

      await container.read(transactionsStreamProvider.future);
      container.read(selectedMonthProvider.notifier).state = DateTime(2026, 5);

      final stats = container.read(dashboardStatsProvider);
      expect(stats.categoryBreakdown['Food'], closeTo(120.0, 0.001));
      expect(stats.categoryBreakdown['Transport'], closeTo(30.0, 0.001));
    });

    test('empty transactions gives empty stats', () async {
      final container = ProviderContainer(overrides: [
        transactionsStreamProvider.overrideWith((_) async* {
          yield <Transaction>[];
        }),
      ]);
      addTearDown(container.dispose);

      await container.read(transactionsStreamProvider.future);
      final stats = container.read(dashboardStatsProvider);
      expect(stats, equals(DashboardStats.empty));
    });
  });

  group('searchedTransactionsProvider', () {
    Transaction makeTx({
      required String id,
      required String vendor,
      String category = 'Food',
      String subCategory = 'Groceries',
      String account = 'Cash',
      String notes = '',
    }) =>
        Transaction(
          id: id,
          userId: 'u1',
          category: category,
          subCategory: subCategory,
          date: DateTime(2026, 5, 10),
          account: account,
          vendor: vendor,
          payment: 'Card',
          currency: 'SGD',
          notes: notes,
          amount: -10.0,
          icon: '🛒',
        );

    ProviderContainer makeContainer(List<Transaction> txns, String query) {
      return ProviderContainer(overrides: [
        transactionsStreamProvider.overrideWith((_) async* { yield txns; }),
        searchQueryProvider.overrideWith((ref) => query),
      ]);
    }

    test('empty query returns all transactions', () async {
      final txns = [makeTx(id: '1', vendor: 'Fairprice'), makeTx(id: '2', vendor: 'Grab')];
      final c = makeContainer(txns, '');
      addTearDown(c.dispose);
      await c.read(transactionsStreamProvider.future);
      expect(c.read(searchedTransactionsProvider).length, equals(2));
    });

    test('filters by vendor case-insensitively', () async {
      final txns = [makeTx(id: '1', vendor: 'Fairprice'), makeTx(id: '2', vendor: 'Grab')];
      final c = makeContainer(txns, 'fair');
      addTearDown(c.dispose);
      await c.read(transactionsStreamProvider.future);
      final result = c.read(searchedTransactionsProvider);
      expect(result.length, equals(1));
      expect(result.first.id, equals('1'));
    });

    test('filters by category', () async {
      final txns = [
        makeTx(id: '1', vendor: 'Shell', category: 'Transport'),
        makeTx(id: '2', vendor: 'NTUC', category: 'Food'),
      ];
      final c = makeContainer(txns, 'transport');
      addTearDown(c.dispose);
      await c.read(transactionsStreamProvider.future);
      expect(c.read(searchedTransactionsProvider).single.id, equals('1'));
    });

    test('no matches returns empty list', () async {
      final txns = [makeTx(id: '1', vendor: 'Fairprice')];
      final c = makeContainer(txns, 'zzz');
      addTearDown(c.dispose);
      await c.read(transactionsStreamProvider.future);
      expect(c.read(searchedTransactionsProvider), isEmpty);
    });
  });
}
