import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/app/app_shell.dart';
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
      MaterialApp.router(routerConfig: buildRouter(screenWidth: 400)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('shows NavigationRail on wide screen (>=600px)', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: buildRouter(screenWidth: 800)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('shows 3 destinations on narrow screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: buildRouter(screenWidth: 400)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(3));
  });
}
