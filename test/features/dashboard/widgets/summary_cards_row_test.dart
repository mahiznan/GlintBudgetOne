import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/dashboard_stats.dart';
import 'package:glintbudgetone/features/dashboard/widgets/summary_cards_row.dart';

void main() {
  group('SummaryCardsRow', () {
    Widget wrap(DashboardStats stats) =>
        MaterialApp(home: Scaffold(body: SummaryCardsRow(stats: stats)));

    testWidgets('shows income, expense, and balance values', (tester) async {
      const stats = DashboardStats(
        totalIncome: 1000.0,
        totalExpense: 400.0,
        categoryBreakdown: {},
      );
      await tester.pumpWidget(wrap(stats));
      expect(find.textContaining('1000.00'), findsOneWidget);
      expect(find.textContaining('400.00'), findsOneWidget);
      expect(find.textContaining('600.00'), findsOneWidget);
    });

    testWidgets('shows zero values for empty stats', (tester) async {
      await tester.pumpWidget(wrap(DashboardStats.empty));
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Balance'), findsOneWidget);
    });
  });
}
