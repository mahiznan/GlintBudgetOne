import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/dashboard_stats.dart';
import 'package:glintbudgetone/core/models/preference.dart';
import 'package:glintbudgetone/core/store/derived_providers.dart';
import 'package:glintbudgetone/core/store/firestore_providers.dart';
import 'package:glintbudgetone/features/dashboard/dashboard_screen.dart';
import 'package:go_router/go_router.dart';

GoRouter buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/app/add', builder: (_, __) => const SizedBox()),
      ],
    );

void main() {
  testWidgets('DashboardScreen shows summary cards, chart area, and FAB',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filteredTransactionsProvider.overrideWith((ref) => []),
          dashboardStatsProvider
              .overrideWith((ref) => DashboardStats.empty),
          preferenceStreamProvider
              .overrideWith((ref) => Preference.defaults()),
        ],
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    await tester.pump();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
  });

  testWidgets('shows empty state text when no transactions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filteredTransactionsProvider.overrideWith((ref) => []),
          dashboardStatsProvider
              .overrideWith((ref) => DashboardStats.empty),
          preferenceStreamProvider
              .overrideWith((ref) => Preference.defaults()),
        ],
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    await tester.pump();
    expect(find.text('No transactions this month'), findsOneWidget);
  });
}
