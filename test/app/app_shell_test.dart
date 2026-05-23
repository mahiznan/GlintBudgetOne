import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/app/app_shell.dart';
import 'package:glintbudgetone/core/store/derived_providers.dart';
import 'package:glintbudgetone/core/sync/sync_status.dart';
import 'package:go_router/go_router.dart';

void main() {
  GoRouter buildRouter({required double screenWidth}) {
    return GoRouter(
      routes: [
        ShellRoute(
          builder: (context, state, child) => MediaQuery(
            data: MediaQueryData(size: Size(screenWidth, 800)),
            child: AppShell(child: child),
          ),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const SizedBox()),
          ],
        ),
      ],
    );
  }

  testWidgets('shows NavigationBar on narrow screen (<600px)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: buildRouter(screenWidth: 400)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('shows NavigationRail on wide screen (>=600px)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: buildRouter(screenWidth: 800)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('shows 3 destinations on narrow screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: buildRouter(screenWidth: 400)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(3));
  });

  testWidgets('SyncDot shows nothing when synced', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusProvider.overrideWith((ref) => SyncStatus.synced),
        ],
        child: MaterialApp.router(routerConfig: buildRouter(screenWidth: 400)),
      ),
    );
    await tester.pump();
    // SizedBox.shrink has zero size — no sync-related Tooltip, no cloud icon
    final syncTooltip = find.byWidgetPredicate(
      (w) => w is Tooltip && (w.message == 'Saving...' || w.message == 'Offline'),
    );
    expect(syncTooltip, findsNothing);
    expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
  });

  testWidgets('SyncDot shows Saving tooltip when pending', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusProvider.overrideWith((ref) => SyncStatus.pending),
        ],
        child: MaterialApp.router(routerConfig: buildRouter(screenWidth: 400)),
      ),
    );
    await tester.pump();
    final savingTooltip = find.byWidgetPredicate(
      (w) => w is Tooltip && w.message == 'Saving...',
    );
    expect(savingTooltip, findsOneWidget);
  });

  testWidgets('SyncDot shows Offline tooltip when offline', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusProvider.overrideWith((ref) => SyncStatus.offline),
        ],
        child: MaterialApp.router(routerConfig: buildRouter(screenWidth: 400)),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    final offlineTooltip = find.byWidgetPredicate(
      (w) => w is Tooltip && w.message == 'Offline',
    );
    expect(offlineTooltip, findsOneWidget);
  });
}
