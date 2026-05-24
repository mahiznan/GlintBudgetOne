import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/auth/auth_notifier.dart';
import 'package:glintbudgetone/core/auth/auth_state.dart';
import 'package:glintbudgetone/core/models/preference.dart';
import 'package:glintbudgetone/core/store/firestore_providers.dart';
import 'package:glintbudgetone/features/settings/screens/currency_selection_screen.dart';

void main() {
  testWidgets('shows list of currencies', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferenceStreamProvider.overrideWith((ref) => Preference.defaults()),
          authNotifierProvider.overrideWith(
            (_) => AuthNotifier.stub(const AuthUnauthenticated()),
          ),
        ],
        child: const MaterialApp(home: CurrencySelectionScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('SGD'), findsOneWidget);
    expect(find.text('EUR'), findsOneWidget);
  });
}
