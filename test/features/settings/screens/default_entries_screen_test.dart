import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/auth/auth_notifier.dart';
import 'package:glintbudgetone/core/auth/auth_state.dart';
import 'package:glintbudgetone/core/models/preference.dart';
import 'package:glintbudgetone/core/store/firestore_providers.dart';
import 'package:glintbudgetone/features/settings/screens/default_entries_screen.dart';

void main() {
  testWidgets('DefaultEntriesScreen renders field rows', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferenceStreamProvider.overrideWith((ref) => Preference.defaults()),
          authNotifierProvider.overrideWith(
            (_) => AuthNotifier.stub(const AuthUnauthenticated()),
          ),
        ],
        child: const MaterialApp(home: DefaultEntriesScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Vendor'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Sub-category'), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget);
  });
}
