import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/auth/auth_notifier.dart';
import 'package:glintbudgetone/core/auth/auth_state.dart';
import 'package:glintbudgetone/core/models/preference.dart';
import 'package:glintbudgetone/core/store/firestore_providers.dart';
import 'package:glintbudgetone/features/settings/settings_screen.dart';
import 'package:go_router/go_router.dart';

GoRouter buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SettingsScreen()),
        GoRoute(
          path: '/app/settings/currency',
          builder: (_, __) => const SizedBox(),
        ),
        GoRoute(
          path: '/app/settings/default-entries',
          builder: (_, __) => const SizedBox(),
        ),
      ],
    );

void main() {
  testWidgets('SettingsScreen shows Theme section and Sign out',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferenceStreamProvider.overrideWith((ref) => Preference.defaults()),
          authNotifierProvider.overrideWith(
            (_) => AuthNotifier.stub(const AuthUnauthenticated()),
          ),
        ],
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    await tester.pump();
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Default Currency'), findsOneWidget);
    expect(find.text('Default Entries'), findsOneWidget);
  });
}
