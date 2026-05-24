import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/preference.dart';
import 'package:glintbudgetone/core/store/firestore_providers.dart';
import 'package:glintbudgetone/features/add_transaction/add_transaction_screen.dart';

void main() {
  Widget wrap({bool editMode = false}) => ProviderScope(
        overrides: [
          preferenceStreamProvider.overrideWith((ref) => Preference.defaults()),
        ],
        child: const MaterialApp(
          home: AddTransactionScreen(existing: null),
        ),
      );

  testWidgets('shows Add Transaction title in create mode', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    expect(find.text('Add Transaction'), findsOneWidget);
  });

  testWidgets('Save button is present', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('Amount field and Expense/Income toggle present', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
