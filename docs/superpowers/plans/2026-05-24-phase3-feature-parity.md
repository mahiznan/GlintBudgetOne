# Phase 3 — Feature Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all three placeholder screens with real content, add Add/Edit transaction form, and implement Settings sub-screens.

**Architecture:** Same Phase 2 data layer (no new Firestore listeners). Two new Riverpod providers for text search. All mutations already exist from Phase 2. Charts via fl_chart. Date/number formatting via intl.

**Tech Stack:** Flutter, Riverpod 2.x, cloud_firestore, go_router, fl_chart ^0.68.0, intl ^0.19.0

**Spec:** `docs/superpowers/specs/2026-05-24-phase3-feature-parity.md`

**Run after every task before committing:**
```bash
flutter analyze --fatal-infos && flutter test
```

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `pubspec.yaml` | MODIFY | Add fl_chart, intl |
| `lib/core/store/derived_providers.dart` | MODIFY | Add searchQueryProvider + searchedTransactionsProvider |
| `lib/core/currencies.dart` | CREATE | Hardcoded list of 30 currencies |
| `lib/core/widgets/transaction_tile.dart` | CREATE | Shared transaction row widget |
| `lib/app/app_router.dart` | MODIFY | Add /app/add + settings sub-routes |
| `lib/features/dashboard/dashboard_screen.dart` | REPLACE | Full dashboard with month picker + stats + chart + list |
| `lib/features/dashboard/widgets/month_picker_row.dart` | CREATE | Month nav row |
| `lib/features/dashboard/widgets/summary_cards_row.dart` | CREATE | Income/expense/balance cards |
| `lib/features/dashboard/widgets/spending_chart.dart` | CREATE | fl_chart bar/pie |
| `lib/features/transactions/transactions_screen.dart` | REPLACE | Search + grouped list + swipe-to-delete |
| `lib/features/add_transaction/add_transaction_screen.dart` | CREATE | Full add/edit form |
| `lib/features/settings/settings_screen.dart` | REPLACE | Profile + theme + nav tiles + sign out |
| `lib/features/settings/screens/default_entries_screen.dart` | CREATE | Default entries pickers |
| `lib/features/settings/screens/currency_selection_screen.dart` | CREATE | Currency list |

---

## Task 1: Dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1.1: Add fl_chart and intl to pubspec.yaml**

Open `pubspec.yaml`. Under `dependencies:`, add:

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  google_sign_in: ^6.2.1
  flutter_riverpod: ^2.5.1
  go_router: ^14.3.0
  fl_chart: ^0.68.0
  intl: ^0.19.0
```

- [ ] **Step 1.2: Get packages and verify**

```bash
flutter pub get
flutter analyze --fatal-infos
```

Expected: no errors.

- [ ] **Step 1.3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add fl_chart and intl dependencies for Phase 3"
```

---

## Task 2: Derived providers additions

**Files:**
- Modify: `lib/core/store/derived_providers.dart`
- Modify: `test/core/store/derived_providers_test.dart`

- [ ] **Step 2.1: Write failing tests first**

Open `test/core/store/derived_providers_test.dart`. Add a new test group after existing ones:

```dart
group('searchedTransactionsProvider', () {
  Transaction _tx({
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

  ProviderContainer _container(List<Transaction> txns, String query) {
    return ProviderContainer(overrides: [
      transactionsStreamProvider.overrideWith((_) async* { yield txns; }),
      searchQueryProvider.overrideWith((ref) => query),
    ]);
  }

  test('empty query returns all transactions', () async {
    final txns = [_tx(id: '1', vendor: 'Fairprice'), _tx(id: '2', vendor: 'Grab')];
    final c = _container(txns, '');
    addTearDown(c.dispose);
    await c.read(transactionsStreamProvider.future);
    expect(c.read(searchedTransactionsProvider).length, equals(2));
  });

  test('filters by vendor (case-insensitive)', () async {
    final txns = [_tx(id: '1', vendor: 'Fairprice'), _tx(id: '2', vendor: 'Grab')];
    final c = _container(txns, 'fair');
    addTearDown(c.dispose);
    await c.read(transactionsStreamProvider.future);
    final result = c.read(searchedTransactionsProvider);
    expect(result.length, equals(1));
    expect(result.first.id, equals('1'));
  });

  test('filters by category', () async {
    final txns = [
      _tx(id: '1', vendor: 'Shell', category: 'Transport'),
      _tx(id: '2', vendor: 'NTUC', category: 'Food'),
    ];
    final c = _container(txns, 'transport');
    addTearDown(c.dispose);
    await c.read(transactionsStreamProvider.future);
    expect(c.read(searchedTransactionsProvider).single.id, equals('1'));
  });

  test('no matches returns empty list', () async {
    final txns = [_tx(id: '1', vendor: 'Fairprice')];
    final c = _container(txns, 'zzz');
    addTearDown(c.dispose);
    await c.read(transactionsStreamProvider.future);
    expect(c.read(searchedTransactionsProvider), isEmpty);
  });
});
```

Run: `flutter test test/core/store/derived_providers_test.dart`
Expected: FAIL — `searchQueryProvider` and `searchedTransactionsProvider` not found.

- [ ] **Step 2.2: Add providers to derived_providers.dart**

Open `lib/core/store/derived_providers.dart`. Add at the bottom:

```dart
/// Live text search query for the Transactions screen.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// All transactions (not month-filtered) matching the search query.
/// Empty query returns everything.
final searchedTransactionsProvider = Provider<List<Transaction>>((ref) {
  final all = ref.watch(transactionsStreamProvider).valueOrNull ?? [];
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return all;
  return all.where((t) =>
    t.vendor.toLowerCase().contains(query) ||
    t.category.toLowerCase().contains(query) ||
    t.subCategory.toLowerCase().contains(query) ||
    t.account.toLowerCase().contains(query) ||
    t.notes.toLowerCase().contains(query)
  ).toList();
});
```

- [ ] **Step 2.3: Run tests**

```bash
flutter analyze --fatal-infos && flutter test test/core/store/derived_providers_test.dart
```

Expected: all tests pass.

- [ ] **Step 2.4: Commit**

```bash
git add lib/core/store/derived_providers.dart test/core/store/derived_providers_test.dart
git commit -m "feat: add searchQueryProvider and searchedTransactionsProvider"
```

---

## Task 3: Currencies list

**Files:**
- Create: `lib/core/currencies.dart`
- Create: `test/core/currencies_test.dart`

- [ ] **Step 3.1: Write failing test**

Create `test/core/currencies_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:glint_budget_one/core/currencies.dart';
import 'package:glint_budget_one/core/models/currency.dart';

void main() {
  group('kCurrencies', () {
    test('contains at least 20 entries', () {
      expect(kCurrencies.length, greaterThanOrEqualTo(20));
    });

    test('all entries have non-empty code, name, symbol', () {
      for (final c in kCurrencies) {
        expect(c.code, isNotEmpty);
        expect(c.name, isNotEmpty);
        expect(c.symbol, isNotEmpty);
      }
    });

    test('USD is in the list', () {
      expect(kCurrencies.any((c) => c.code == 'USD'), isTrue);
    });

    test('SGD is in the list', () {
      expect(kCurrencies.any((c) => c.code == 'SGD'), isTrue);
    });

    test('no duplicate codes', () {
      final codes = kCurrencies.map((c) => c.code).toList();
      expect(codes.toSet().length, equals(codes.length));
    });
  });
}
```

Run: `flutter test test/core/currencies_test.dart`
Expected: FAIL — `currencies.dart` not found.

- [ ] **Step 3.2: Create currencies.dart**

Create `lib/core/currencies.dart`:

```dart
import 'models/currency.dart';

const List<Currency> kCurrencies = [
  Currency(name: 'US Dollar',          code: 'USD', symbol: '\$'),
  Currency(name: 'Euro',               code: 'EUR', symbol: '€'),
  Currency(name: 'British Pound',      code: 'GBP', symbol: '£'),
  Currency(name: 'Singapore Dollar',   code: 'SGD', symbol: 'S\$'),
  Currency(name: 'Australian Dollar',  code: 'AUD', symbol: 'A\$'),
  Currency(name: 'Canadian Dollar',    code: 'CAD', symbol: 'C\$'),
  Currency(name: 'Japanese Yen',       code: 'JPY', symbol: '¥'),
  Currency(name: 'Chinese Yuan',       code: 'CNY', symbol: '¥'),
  Currency(name: 'Indian Rupee',       code: 'INR', symbol: '₹'),
  Currency(name: 'Swiss Franc',        code: 'CHF', symbol: 'CHF'),
  Currency(name: 'Hong Kong Dollar',   code: 'HKD', symbol: 'HK\$'),
  Currency(name: 'South Korean Won',   code: 'KRW', symbol: '₩'),
  Currency(name: 'Malaysian Ringgit',  code: 'MYR', symbol: 'RM'),
  Currency(name: 'Thai Baht',          code: 'THB', symbol: '฿'),
  Currency(name: 'Indonesian Rupiah',  code: 'IDR', symbol: 'Rp'),
  Currency(name: 'Philippine Peso',    code: 'PHP', symbol: '₱'),
  Currency(name: 'Vietnamese Dong',    code: 'VND', symbol: '₫'),
  Currency(name: 'New Zealand Dollar', code: 'NZD', symbol: 'NZ\$'),
  Currency(name: 'Swedish Krona',      code: 'SEK', symbol: 'kr'),
  Currency(name: 'Norwegian Krone',    code: 'NOK', symbol: 'kr'),
  Currency(name: 'Danish Krone',       code: 'DKK', symbol: 'kr'),
  Currency(name: 'Mexican Peso',       code: 'MXN', symbol: 'MX\$'),
  Currency(name: 'Brazilian Real',     code: 'BRL', symbol: 'R\$'),
  Currency(name: 'South African Rand', code: 'ZAR', symbol: 'R'),
  Currency(name: 'UAE Dirham',         code: 'AED', symbol: 'AED'),
  Currency(name: 'Saudi Riyal',        code: 'SAR', symbol: 'SAR'),
  Currency(name: 'Turkish Lira',       code: 'TRY', symbol: '₺'),
  Currency(name: 'Russian Ruble',      code: 'RUB', symbol: '₽'),
  Currency(name: 'Polish Zloty',       code: 'PLN', symbol: 'zł'),
  Currency(name: 'Czech Koruna',       code: 'CZK', symbol: 'Kč'),
];
```

- [ ] **Step 3.3: Run tests**

```bash
flutter analyze --fatal-infos && flutter test test/core/currencies_test.dart
```

Expected: all pass.

- [ ] **Step 3.4: Commit**

```bash
git add lib/core/currencies.dart test/core/currencies_test.dart
git commit -m "feat: add kCurrencies constant list (30 currencies)"
```

---

## Task 4: TransactionTile shared widget

**Files:**
- Create: `lib/core/widgets/transaction_tile.dart`
- Create: `test/core/widgets/transaction_tile_test.dart`

- [ ] **Step 4.1: Write failing test**

Create `test/core/widgets/transaction_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glint_budget_one/core/models/transaction.dart';
import 'package:glint_budget_one/core/widgets/transaction_tile.dart';

Transaction _tx({double amount = -50.0, String subCategory = 'Groceries'}) =>
    Transaction(
      id: 't1',
      userId: 'u1',
      category: 'Food',
      subCategory: subCategory,
      date: DateTime(2026, 5, 10),
      account: 'Cash',
      vendor: 'Fairprice',
      payment: 'Card',
      currency: 'SGD',
      notes: '',
      amount: amount,
      icon: '🛒',
    );

void main() {
  group('TransactionTile', () {
    Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

    testWidgets('shows icon, subCategory, vendor', (tester) async {
      await tester.pumpWidget(_wrap(TransactionTile(transaction: _tx())));
      expect(find.text('🛒'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Fairprice'), findsOneWidget);
    });

    testWidgets('shows category when subCategory is empty', (tester) async {
      await tester.pumpWidget(_wrap(TransactionTile(transaction: _tx(subCategory: ''))));
      expect(find.text('Food'), findsOneWidget);
    });

    testWidgets('negative amount prefixed with minus', (tester) async {
      await tester.pumpWidget(_wrap(TransactionTile(transaction: _tx(amount: -50.0))));
      expect(find.textContaining('-50.00'), findsOneWidget);
    });

    testWidgets('positive amount prefixed with plus', (tester) async {
      await tester.pumpWidget(_wrap(TransactionTile(transaction: _tx(amount: 100.0))));
      expect(find.textContaining('+100.00'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        TransactionTile(transaction: _tx(), onTap: () => tapped = true),
      ));
      await tester.tap(find.byType(TransactionTile));
      expect(tapped, isTrue);
    });
  });
}
```

Run: `flutter test test/core/widgets/transaction_tile_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 4.2: Create transaction_tile.dart**

Create `lib/core/widgets/transaction_tile.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  final Transaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.amount < 0;
    final absAmount = transaction.amount.abs().toStringAsFixed(2);
    final amountText = isExpense ? '-$absAmount' : '+$absAmount';
    final amountColor = isExpense
        ? Theme.of(context).colorScheme.error
        : Colors.green.shade700;
    final title = transaction.subCategory.isNotEmpty
        ? transaction.subCategory
        : transaction.category;

    return ListTile(
      leading: Text(
        transaction.icon.isNotEmpty ? transaction.icon : '💰',
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(title),
      subtitle: Text(transaction.vendor),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amountText,
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            transaction.payment,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 4.3: Run tests**

```bash
flutter analyze --fatal-infos && flutter test test/core/widgets/transaction_tile_test.dart
```

Expected: all pass.

- [ ] **Step 4.4: Commit**

```bash
git add lib/core/widgets/transaction_tile.dart test/core/widgets/transaction_tile_test.dart
git commit -m "feat: add shared TransactionTile widget"
```

---

## Task 5: Router changes + stub screens

**Files:**
- Modify: `lib/app/app_router.dart`
- Create: `lib/features/add_transaction/add_transaction_screen.dart` (stub)
- Create: `lib/features/settings/screens/default_entries_screen.dart` (stub)
- Create: `lib/features/settings/screens/currency_selection_screen.dart` (stub)

- [ ] **Step 5.1: Create stub screens**

Create `lib/features/add_transaction/add_transaction_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/models/transaction.dart';

class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({super.key, this.existing});
  final Transaction? existing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(existing == null ? 'Add Transaction' : 'Edit Transaction'),
      ),
      body: const Center(child: Text('Form coming soon')),
    );
  }
}
```

Create `lib/features/settings/screens/default_entries_screen.dart`:

```dart
import 'package:flutter/material.dart';

class DefaultEntriesScreen extends StatelessWidget {
  const DefaultEntriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Default Entries')),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
```

Create `lib/features/settings/screens/currency_selection_screen.dart`:

```dart
import 'package:flutter/material.dart';

class CurrencySelectionScreen extends StatelessWidget {
  const CurrencySelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Currency')),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
```

- [ ] **Step 5.2: Update app_router.dart**

Replace the entire content of `lib/app/app_router.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_notifier.dart';
import '../core/auth/auth_state.dart';
import '../core/models/transaction.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/transactions/transactions_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/screens/default_entries_screen.dart';
import '../features/settings/screens/currency_selection_screen.dart';
import '../features/add_transaction/add_transaction_screen.dart';
import 'app_shell.dart';

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthListenable(ref);

  return GoRouter(
    initialLocation: '/app/dashboard',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isLoading = authState is AuthLoading;
      final isAuthed = authState is AuthAuthenticated;
      final goingToSignIn = state.matchedLocation == '/signin';

      if (isLoading) return null;
      if (!isAuthed && !goingToSignIn) return '/signin';
      if (isAuthed && goingToSignIn) return '/app/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      // Add/Edit form — outside ShellRoute so no nav bar is shown
      GoRoute(
        path: '/app/add',
        builder: (context, state) => AddTransactionScreen(
          existing: state.extra as Transaction?,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/app/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/app/transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/app/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'default-entries',
                builder: (context, state) => const DefaultEntriesScreen(),
              ),
              GoRoute(
                path: 'currency',
                builder: (context, state) => const CurrencySelectionScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
```

- [ ] **Step 5.3: Verify compilation**

```bash
flutter analyze --fatal-infos && flutter test
```

Expected: all existing tests still pass, no new errors.

- [ ] **Step 5.4: Commit**

```bash
git add lib/app/app_router.dart \
        lib/features/add_transaction/add_transaction_screen.dart \
        lib/features/settings/screens/default_entries_screen.dart \
        lib/features/settings/screens/currency_selection_screen.dart
git commit -m "feat: add /app/add route and settings sub-routes; scaffold stub screens"
```

---

## Task 6: Dashboard widgets

**Files:**
- Create: `lib/features/dashboard/widgets/month_picker_row.dart`
- Create: `lib/features/dashboard/widgets/summary_cards_row.dart`
- Create: `lib/features/dashboard/widgets/spending_chart.dart`
- Create: `test/features/dashboard/widgets/summary_cards_row_test.dart`

- [ ] **Step 6.1: Write failing test for SummaryCardsRow**

Create `test/features/dashboard/widgets/summary_cards_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glint_budget_one/core/models/dashboard_stats.dart';
import 'package:glint_budget_one/features/dashboard/widgets/summary_cards_row.dart';

void main() {
  group('SummaryCardsRow', () {
    Widget _wrap(DashboardStats stats) => MaterialApp(
          home: Scaffold(body: SummaryCardsRow(stats: stats)),
        );

    testWidgets('shows income, expense, balance values', (tester) async {
      const stats = DashboardStats(
        totalIncome: 1000.0,
        totalExpense: 400.0,
        categoryBreakdown: {},
      );
      await tester.pumpWidget(_wrap(stats));
      expect(find.textContaining('1000.00'), findsOneWidget);
      expect(find.textContaining('400.00'), findsOneWidget);
      expect(find.textContaining('600.00'), findsOneWidget); // balance
    });
  });
}
```

Run: `flutter test test/features/dashboard/widgets/summary_cards_row_test.dart`
Expected: FAIL.

- [ ] **Step 6.2: Create MonthPickerRow**

Create `lib/features/dashboard/widgets/month_picker_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/store/derived_providers.dart';

class MonthPickerRow extends ConsumerWidget {
  const MonthPickerRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMonthProvider);
    final now = DateTime.now();
    final isCurrentMonth =
        selected.year == now.year && selected.month == now.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              ref.read(selectedMonthProvider.notifier).state =
                  DateTime(selected.year, selected.month - 1);
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(selected),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isCurrentMonth
                ? null
                : () {
                    ref.read(selectedMonthProvider.notifier).state =
                        DateTime(selected.year, selected.month + 1);
                  },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6.3: Create SummaryCardsRow**

Create `lib/features/dashboard/widgets/summary_cards_row.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../core/models/dashboard_stats.dart';

class SummaryCardsRow extends StatelessWidget {
  const SummaryCardsRow({super.key, required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _Card(
            label: 'Income',
            value: stats.totalIncome,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 8),
          _Card(
            label: 'Expense',
            value: stats.totalExpense,
            color: colorScheme.error,
          ),
          const SizedBox(width: 8),
          _Card(
            label: 'Balance',
            value: stats.balance,
            color: stats.balance >= 0 ? Colors.green.shade700 : colorScheme.error,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              Text(
                value.toStringAsFixed(2),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6.4: Create SpendingChart**

Create `lib/features/dashboard/widgets/spending_chart.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SpendingChart extends StatelessWidget {
  const SpendingChart({
    super.key,
    required this.breakdown,
    required this.chartType,
  });

  final Map<String, double> breakdown;
  final String chartType; // 'bar' or 'pie'

  static const _colors = [
    Colors.blue,
    Colors.orange,
    Colors.green,
    Colors.purple,
    Colors.red,
    Colors.teal,
  ];

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('No spending this month')),
      );
    }

    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();

    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: chartType == 'pie' ? _buildPie(top) : _buildBar(context, top),
      ),
    );
  }

  Widget _buildBar(BuildContext context, List<MapEntry<String, double>> top) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: top.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                color: _colors[e.key % _colors.length],
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= top.length) return const SizedBox.shrink();
                final label = top[idx].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label.length > 8 ? '${label.substring(0, 7)}.' : label,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildPie(List<MapEntry<String, double>> top) {
    final total = top.fold(0.0, (s, e) => s + e.value);
    return PieChart(
      PieChartData(
        sections: top.asMap().entries.map((e) {
          final pct = total > 0 ? (e.value.value / total * 100) : 0;
          return PieChartSectionData(
            color: _colors[e.key % _colors.length],
            value: e.value.value,
            title: '${pct.toStringAsFixed(0)}%',
            radius: 70,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        sectionsSpace: 2,
      ),
    );
  }
}
```

- [ ] **Step 6.5: Run tests**

```bash
flutter analyze --fatal-infos && flutter test test/features/dashboard/widgets/
```

Expected: summary_cards_row_test passes.

- [ ] **Step 6.6: Commit**

```bash
git add lib/features/dashboard/widgets/ test/features/dashboard/widgets/
git commit -m "feat: add dashboard widgets (month picker, summary cards, spending chart)"
```

---

## Task 7: Dashboard screen

**Files:**
- Modify: `lib/features/dashboard/dashboard_screen.dart`
- Create: `test/features/dashboard/dashboard_screen_test.dart`

- [ ] **Step 7.1: Write smoke test**

Create `test/features/dashboard/dashboard_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glint_budget_one/core/models/dashboard_stats.dart';
import 'package:glint_budget_one/core/models/preference.dart';
import 'package:glint_budget_one/core/models/transaction.dart';
import 'package:glint_budget_one/core/store/derived_providers.dart';
import 'package:glint_budget_one/core/store/firestore_providers.dart';
import 'package:glint_budget_one/features/dashboard/dashboard_screen.dart';
import 'package:go_router/go_router.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(path: '/app/add', builder: (_, __) => const SizedBox()),
      ],
    );

void main() {
  testWidgets('DashboardScreen shows summary cards and FAB', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filteredTransactionsProvider.overrideWith((ref) => []),
          dashboardStatsProvider.overrideWith((ref) => DashboardStats.empty),
          preferenceStreamProvider.overrideWith((ref) => Preference.defaults()),
        ],
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    await tester.pump();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    // Summary card labels
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
  });
}
```

Run: `flutter test test/features/dashboard/dashboard_screen_test.dart`
Expected: FAIL.

- [ ] **Step 7.2: Replace dashboard_screen.dart**

Replace the entire content of `lib/features/dashboard/dashboard_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/store/derived_providers.dart';
import '../../core/store/firestore_providers.dart';
import '../../core/widgets/transaction_tile.dart';
import '../../core/models/transaction.dart';
import 'widgets/month_picker_row.dart';
import 'widgets/summary_cards_row.dart';
import 'widgets/spending_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final txns = ref.watch(filteredTransactionsProvider);
    final pref = ref.watch(preferenceStreamProvider);
    final grouped = _groupByDate(txns);
    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Build a flat list: date header items + transaction items
    final items = <_Item>[];
    for (final date in sortedDates) {
      items.add(_DateHeaderItem(date));
      for (final t in grouped[date]!) {
        items.add(_TxItem(t));
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const MonthPickerRow(),
            SummaryCardsRow(stats: stats),
            SpendingChart(
              breakdown: stats.categoryBreakdown,
              chartType: pref.spendingChartType ?? 'bar',
            ),
            Expanded(
              child: txns.isEmpty
                  ? const Center(child: Text('No transactions this month'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        if (item is _DateHeaderItem) {
                          return _DateHeader(date: item.date);
                        }
                        final tx = (item as _TxItem).transaction;
                        return TransactionTile(
                          transaction: tx,
                          onTap: () => context.push('/app/add', extra: tx),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/app/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Map<DateTime, List<Transaction>> _groupByDate(List<Transaction> txns) {
    final map = <DateTime, List<Transaction>>{};
    for (final t in txns) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      map.putIfAbsent(day, () => []).add(t);
    }
    return map;
  }
}

sealed class _Item {}
class _DateHeaderItem extends _Item { _DateHeaderItem(this.date); final DateTime date; }
class _TxItem extends _Item { _TxItem(this.transaction); final Transaction transaction; }

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        DateFormat('EEE, d MMM').format(date),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
```

- [ ] **Step 7.3: Run tests**

```bash
flutter analyze --fatal-infos && flutter test test/features/dashboard/
```

Expected: all pass.

- [ ] **Step 7.4: Commit**

```bash
git add lib/features/dashboard/ test/features/dashboard/
git commit -m "feat: implement Dashboard screen (month picker, summary cards, chart, transaction list)"
```

---

## Task 8: Transactions screen

**Files:**
- Modify: `lib/features/transactions/transactions_screen.dart`
- Create: `test/features/transactions/transactions_screen_test.dart`

- [ ] **Step 8.1: Write smoke test**

Create `test/features/transactions/transactions_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glint_budget_one/core/models/transaction.dart';
import 'package:glint_budget_one/core/store/derived_providers.dart';
import 'package:glint_budget_one/features/transactions/transactions_screen.dart';
import 'package:go_router/go_router.dart';

Transaction _tx(String id, String vendor) => Transaction(
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

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const TransactionsScreen()),
        GoRoute(path: '/app/add', builder: (_, __) => const SizedBox()),
      ],
    );

void main() {
  testWidgets('shows search field and FAB', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchedTransactionsProvider.overrideWith((ref) => []),
        ],
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    await tester.pump();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('renders transaction tiles', (tester) async {
    final txns = [_tx('1', 'Fairprice'), _tx('2', 'Grab')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchedTransactionsProvider.overrideWith((ref) => txns),
        ],
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    await tester.pump();
    expect(find.text('Fairprice'), findsOneWidget);
    expect(find.text('Grab'), findsOneWidget);
  });
}
```

Run: `flutter test test/features/transactions/transactions_screen_test.dart`
Expected: FAIL.

- [ ] **Step 8.2: Replace transactions_screen.dart**

Replace the entire content of `lib/features/transactions/transactions_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/store/derived_providers.dart';
import '../../core/store/transaction_mutations.dart';
import '../../core/widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(searchedTransactionsProvider);
    final grouped = _groupByDate(txns);
    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final items = <_Item>[];
    for (final date in sortedDates) {
      items.add(_DateHeaderItem(date));
      for (final t in grouped[date]!) {
        items.add(_TxItem(t));
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _SearchBar(
              onChanged: (q) =>
                  ref.read(searchQueryProvider.notifier).state = q,
            ),
            Expanded(
              child: txns.isEmpty
                  ? const Center(child: Text('No transactions found'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        if (item is _DateHeaderItem) {
                          return _DateHeader(date: item.date);
                        }
                        final tx = (item as _TxItem).transaction;
                        return Dismissible(
                          key: ValueKey(tx.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDelete(context),
                          onDismissed: (_) => deleteTransaction(tx.id),
                          background: Container(
                            color: Theme.of(context).colorScheme.error,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: TransactionTile(
                            transaction: tx,
                            onTap: () => context.push('/app/add', extra: tx),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/app/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Map<DateTime, List<Transaction>> _groupByDate(List<Transaction> txns) {
    final map = <DateTime, List<Transaction>>{};
    for (final t in txns) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      map.putIfAbsent(day, () => []).add(t);
    }
    return map;
  }
}

sealed class _Item {}
class _DateHeaderItem extends _Item { _DateHeaderItem(this.date); final DateTime date; }
class _TxItem extends _Item { _TxItem(this.transaction); final Transaction transaction; }

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Search transactions...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          isDense: true,
        ),
        onChanged: (val) {
          setState(() {}); // rebuild to show/hide clear button
          widget.onChanged(val);
        },
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        DateFormat('EEE, d MMM').format(date),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
```

- [ ] **Step 8.3: Run tests**

```bash
flutter analyze --fatal-infos && flutter test test/features/transactions/
```

Expected: all pass.

- [ ] **Step 8.4: Commit**

```bash
git add lib/features/transactions/transactions_screen.dart \
        test/features/transactions/transactions_screen_test.dart
git commit -m "feat: implement Transactions screen (search, grouped list, swipe-to-delete)"
```

---

## Task 9: Add/Edit Transaction screen

**Files:**
- Modify: `lib/features/add_transaction/add_transaction_screen.dart` (replace stub)
- Create: `test/features/add_transaction/add_transaction_screen_test.dart`

This screen is a `StatefulWidget` because the form fields hold local state.

- [ ] **Step 9.1: Write smoke test**

Create `test/features/add_transaction/add_transaction_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glint_budget_one/core/auth/auth_notifier.dart';
import 'package:glint_budget_one/core/auth/auth_state.dart';
import 'package:glint_budget_one/core/models/preference.dart';
import 'package:glint_budget_one/core/store/firestore_providers.dart';
import 'package:glint_budget_one/features/add_transaction/add_transaction_screen.dart';

void main() {
  Widget _wrap({transaction}) => ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            (_) => AuthNotifier()
              ..state = const AuthAuthenticated(
                user: AuthUser(uid: 'u1', email: 'test@test.com'),
              ),
          ),
          preferenceStreamProvider.overrideWith(
            (ref) => Preference.defaults(),
          ),
        ],
        child: MaterialApp(
          home: AddTransactionScreen(existing: transaction),
        ),
      );

  testWidgets('shows Add Transaction title in create mode', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.text('Add Transaction'), findsOneWidget);
  });

  testWidgets('shows Edit Transaction title in edit mode', (tester) async {
    // We can't easily build a full Transaction here without Firestore,
    // so just verify the screen accepts null existing without crashing.
    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.byType(AddTransactionScreen), findsOneWidget);
  });

  testWidgets('amount field is present', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    // The amount TextField should be present
    expect(find.byType(TextField), findsWidgets);
  });
}
```

Run: `flutter test test/features/add_transaction/add_transaction_screen_test.dart`
Expected: FAIL (AuthNotifier state not settable this way — adjust test as needed to just verify screen renders).

**Note on the test:** `AuthNotifier` has private state management. The test should override `authNotifierProvider` with a mock. Use this override instead:

```dart
authNotifierProvider.overrideWith((_) {
  final notifier = AuthNotifier();
  // State is set by FirebaseAuth.instance.authStateChanges() in the constructor.
  // Override so the provider returns an already-authenticated state:
  return notifier;
}),
```

Actually, since `AuthNotifier` connects to Firebase, in tests it's simpler to just test that the widget tree renders without crashing, without verifying the auth state. Adjust the test to not override authNotifierProvider — just verify the screen renders.

Simplest smoke test:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glint_budget_one/core/models/preference.dart';
import 'package:glint_budget_one/core/store/firestore_providers.dart';
import 'package:glint_budget_one/features/add_transaction/add_transaction_screen.dart';

void main() {
  testWidgets('AddTransactionScreen renders in create mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferenceStreamProvider.overrideWith((ref) => Preference.defaults()),
        ],
        child: const MaterialApp(home: AddTransactionScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Add Transaction'), findsOneWidget);
    expect(find.byType(AddTransactionScreen), findsOneWidget);
  });
}
```

Use this simpler version. Run it — expected: FAIL.

- [ ] **Step 9.2: Replace add_transaction_screen.dart**

Replace the entire file with the full form implementation:

```dart
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../core/currencies.dart';
import '../../core/models/budget_data.dart';
import '../../core/models/currency.dart';
import '../../core/models/preference.dart';
import '../../core/models/transaction.dart';
import '../../core/store/firestore_providers.dart';
import '../../core/store/transaction_mutations.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.existing});
  final Transaction? existing;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _iconController = TextEditingController();

  bool _isExpense = true;
  DateTime _date = DateTime.now();
  String? _category;
  String? _subCategory;
  String? _vendor;
  String? _account;
  String? _payment;
  Currency? _currency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    if (t != null) {
      // Edit mode: pre-fill from existing transaction
      final abs = t.amount.abs();
      _amountController.text = abs.toStringAsFixed(2);
      _isExpense = t.amount < 0;
      _date = t.date;
      _category = t.category;
      _subCategory = t.subCategory.isNotEmpty ? t.subCategory : null;
      _vendor = t.vendor.isNotEmpty ? t.vendor : null;
      _account = t.account.isNotEmpty ? t.account : null;
      _payment = t.payment.isNotEmpty ? t.payment : null;
      _iconController.text = t.icon;
      _notesController.text = t.notes;
      _currency = kCurrencies.firstWhere(
        (c) => c.code == t.currency,
        orElse: () => Currency.defaults,
      );
    }
  }

  void _prefillFromDefaults(Preference pref) {
    if (widget.existing != null) return; // Only for create mode
    final d = pref.defaultEntries;
    _category ??= d['category'];
    _subCategory ??= d['sub_category'];
    _vendor ??= d['vendor'];
    _account ??= d['account'];
    _payment ??= d['payment'];
    _currency ??= pref.defaultCurrency;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amountText = _amountController.text.trim();
    final absAmount = double.tryParse(amountText);
    if (absAmount == null || absAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    final authState = ref.read(authNotifierProvider);
    if (authState is! AuthAuthenticated) return;
    final uid = authState.user.uid;
    final signedAmount = _isExpense ? -absAmount : absAmount;

    final id = widget.existing?.id ??
        FirebaseFirestore.instance.collection('transactions').doc().id;

    final t = Transaction(
      id: id,
      userId: uid,
      category: _category ?? '',
      subCategory: _subCategory ?? '',
      date: _date,
      account: _account ?? '',
      vendor: _vendor ?? '',
      payment: _payment ?? '',
      currency: (_currency ?? Currency.defaults).code,
      notes: _notesController.text.trim(),
      amount: signedAmount,
      icon: _iconController.text.trim(),
    );

    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await addTransaction(t);
      } else {
        await updateTransaction(t);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pref = ref.watch(preferenceStreamProvider);
    _prefillFromDefaults(pref);

    final subCats = pref.subCategories
            ?.where((s) => _category == null || s.parent == _category)
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
            widget.existing == null ? 'Add Transaction' : 'Edit Transaction'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount row
            Row(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Expense')),
                    ButtonSegment(value: false, label: Text('Income')),
                  ],
                  selected: {_isExpense},
                  onSelectionChanged: (s) =>
                      setState(() => _isExpense = s.first),
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return _isExpense
                            ? Theme.of(context).colorScheme.error
                            : Colors.green.shade700;
                      }
                      return null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(_formatDate(_date)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const Divider(),

            // Icon
            TextField(
              controller: _iconController,
              maxLength: 2,
              decoration: const InputDecoration(
                labelText: 'Icon (emoji)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),

            // Category
            _DropdownField(
              label: 'Category',
              value: _category,
              options: pref.categories ?? [],
              onChanged: (v) => setState(() {
                _category = v;
                _subCategory = null; // reset dependent field
              }),
            ),
            const SizedBox(height: 12),

            // Sub-category (filtered by category)
            _DropdownField(
              label: 'Sub-category',
              value: _subCategory,
              options: subCats,
              onChanged: (v) => setState(() => _subCategory = v),
            ),
            const SizedBox(height: 12),

            // Vendor
            _DropdownField(
              label: 'Vendor',
              value: _vendor,
              options: pref.vendors ?? [],
              onChanged: (v) => setState(() => _vendor = v),
            ),
            const SizedBox(height: 12),

            // Account
            _DropdownField(
              label: 'Account',
              value: _account,
              options: pref.accounts ?? [],
              onChanged: (v) => setState(() => _account = v),
            ),
            const SizedBox(height: 12),

            // Payment
            _DropdownField(
              label: 'Payment',
              value: _payment,
              options: pref.payments ?? [],
              onChanged: (v) => setState(() => _payment = v),
            ),
            const SizedBox(height: 12),

            // Currency
            DropdownButtonFormField<Currency>(
              value: _currency ?? pref.defaultCurrency,
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              items: kCurrencies
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.code} ${c.symbol}'),
                      ))
                  .toList(),
              onChanged: (c) => setState(() => _currency = c),
            ),
            const SizedBox(height: 12),

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<BudgetData> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      // No preset options — show freeform text field
      return TextField(
        controller: TextEditingController(text: value),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      );
    }

    // Ensure value is in options (reset if not)
    final validValue =
        options.any((o) => o.name == value) ? value : null;

    return DropdownButtonFormField<String>(
      value: validValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('None')),
        ...options.map((o) => DropdownMenuItem(
              value: o.name,
              child: Text(
                o.emoji != null ? '${o.emoji} ${o.name}' : o.name,
              ),
            )),
      ],
      onChanged: onChanged,
    );
  }
}
```

- [ ] **Step 9.3: Run tests**

```bash
flutter analyze --fatal-infos && flutter test test/features/add_transaction/
```

Expected: smoke test passes.

- [ ] **Step 9.4: Commit**

```bash
git add lib/features/add_transaction/add_transaction_screen.dart \
        test/features/add_transaction/add_transaction_screen_test.dart
git commit -m "feat: implement Add/Edit Transaction form with all fields and pre-fill from defaults"
```

---

## Task 10: Settings screen

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`
- Create: `test/features/settings/settings_screen_test.dart`

- [ ] **Step 10.1: Write smoke test**

Create `test/features/settings/settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glint_budget_one/core/auth/auth_notifier.dart';
import 'package:glint_budget_one/core/auth/auth_state.dart';
import 'package:glint_budget_one/core/models/preference.dart';
import 'package:glint_budget_one/core/store/firestore_providers.dart';
import 'package:glint_budget_one/features/settings/settings_screen.dart';
import 'package:go_router/go_router.dart';

GoRouter _router() => GoRouter(
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
  testWidgets('shows profile, theme, and sign out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((_) {
            final n = AuthNotifier();
            n.state = const AuthAuthenticated(
              user: AuthUser(
                uid: 'u1',
                email: 'test@example.com',
                displayName: 'Test User',
              ),
            );
            return n;
          }),
          preferenceStreamProvider.overrideWith((ref) => Preference.defaults()),
        ],
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );
    await tester.pump();
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
  });
}
```

Run: `flutter test test/features/settings/settings_screen_test.dart`
Expected: FAIL.

**Note on the test:** `AuthNotifier` sets state internally from Firebase. If `AuthNotifier()` constructor calls Firebase which is not initialized in tests, you will get an error. In that case, simplify the test to not override `authNotifierProvider` and just check that the SettingsScreen renders without auth-dependent content. Use:

```dart
testWidgets('SettingsScreen renders', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferenceStreamProvider.overrideWith((ref) => Preference.defaults()),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pump();
  expect(find.byType(SettingsScreen), findsOneWidget);
  expect(find.text('Theme'), findsOneWidget);
  expect(find.text('Sign out'), findsOneWidget);
});
```

Use this simpler version.

- [ ] **Step 10.2: Replace settings_screen.dart**

Replace the entire content of `lib/features/settings/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../core/store/firestore_providers.dart';
import '../../core/store/preference_mutations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final pref = ref.watch(preferenceStreamProvider);
    final currentTheme = ref.watch(themeProvider);

    AuthUser? user;
    if (authState is AuthAuthenticated) user = authState.user;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (user != null) _UserProfileCard(user: user),
            const SizedBox(height: 16),

            _SectionHeader('Theme'),
            _ThemeSelector(
              currentId: currentTheme.id,
              onSelect: (id) {
                if (user == null) return;
                updateTheme(user.uid, id);
              },
            ),
            const SizedBox(height: 16),

            _SectionHeader('Preferences'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Default Currency'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pref.defaultCurrency.code,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => context.push('/app/settings/currency'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Default Entries'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push('/app/settings/default-entries'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _SectionHeader('Account'),
            Card(
              child: ListTile(
                title: const Text('Sign out'),
                textColor: Theme.of(context).colorScheme.error,
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                ),
                onTap: () =>
                    ref.read(authNotifierProvider.notifier).signOut(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard({required this.user});
  final AuthUser user;

  String _initials() {
    final name = user.displayName ?? user.email;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              onBackgroundImageError: user.photoUrl != null
                  ? (_, __) {}
                  : null,
              child: user.photoUrl == null
                  ? Text(
                      _initials(),
                      style: const TextStyle(fontSize: 20),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? user.email,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.displayName != null)
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.currentId, required this.onSelect});
  final String currentId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: themeRegistry.entries.map((entry) {
            final isSelected = entry.key == currentId;
            return GestureDetector(
              onTap: () => onSelect(entry.key),
              child: Tooltip(
                message: entry.value.label,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: entry.value.seed,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: entry.value.seed.withAlpha(100),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
```

- [ ] **Step 10.3: Run tests**

```bash
flutter analyze --fatal-infos && flutter test test/features/settings/settings_screen_test.dart
```

Expected: passes.

- [ ] **Step 10.4: Commit**

```bash
git add lib/features/settings/settings_screen.dart \
        test/features/settings/settings_screen_test.dart
git commit -m "feat: implement Settings screen (profile card, theme selector, nav tiles, sign out)"
```

---

## Task 11: Default Entries sub-screen

**Files:**
- Modify: `lib/features/settings/screens/default_entries_screen.dart` (replace stub)
- Create: `test/features/settings/screens/default_entries_screen_test.dart`

- [ ] **Step 11.1: Write smoke test**

Create `test/features/settings/screens/default_entries_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glint_budget_one/core/auth/auth_notifier.dart';
import 'package:glint_budget_one/core/auth/auth_state.dart';
import 'package:glint_budget_one/core/models/preference.dart';
import 'package:glint_budget_one/core/store/firestore_providers.dart';
import 'package:glint_budget_one/features/settings/screens/default_entries_screen.dart';

void main() {
  testWidgets('DefaultEntriesScreen renders field rows', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferenceStreamProvider.overrideWith((ref) => Preference.defaults()),
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
```

Run: FAIL.

- [ ] **Step 11.2: Replace default_entries_screen.dart**

Replace the entire content of `lib/features/settings/screens/default_entries_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/models/budget_data.dart';
import '../../../core/store/firestore_providers.dart';
import '../../../core/store/preference_mutations.dart';

class DefaultEntriesScreen extends ConsumerWidget {
  const DefaultEntriesScreen({super.key});

  static const _fields = [
    ('Vendor',       'vendor'),
    ('Account',      'account'),
    ('Category',     'category'),
    ('Sub-category', 'sub_category'),
    ('Payment',      'payment'),
  ];

  List<BudgetData>? _optionsFor(String key, dynamic pref) {
    return switch (key) {
      'vendor'       => (pref as dynamic).vendors as List<BudgetData>?,
      'account'      => (pref as dynamic).accounts as List<BudgetData>?,
      'category'     => (pref as dynamic).categories as List<BudgetData>?,
      'sub_category' => (pref as dynamic).subCategories as List<BudgetData>?,
      'payment'      => (pref as dynamic).payments as List<BudgetData>?,
      _              => null,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pref = ref.watch(preferenceStreamProvider);
    final authState = ref.watch(authNotifierProvider);
    final uid = authState is AuthAuthenticated ? authState.user.uid : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Default Entries')),
      body: ListView(
        children: _fields.map((field) {
          final (label, key) = field;
          final current = pref.defaultEntries[key];
          final options = switch (key) {
            'vendor'       => pref.vendors,
            'account'      => pref.accounts,
            'category'     => pref.categories,
            'sub_category' => pref.subCategories,
            'payment'      => pref.payments,
            _              => null,
          };

          return ListTile(
            title: Text(label),
            subtitle: Text(current ?? 'None'),
            trailing: const Icon(Icons.chevron_right),
            onTap: uid == null || (options?.isEmpty ?? true)
                ? null
                : () => _pickValue(context, ref, uid, label, key, current, options!),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickValue(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String label,
    String key,
    String? current,
    List<BudgetData> options,
  ) async {
    final pref = ref.read(preferenceStreamProvider);
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              'Select $label',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('None'),
            leading: current == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(ctx).pop(''),
          ),
          ...options.map((o) => ListTile(
                leading: current == o.name ? const Icon(Icons.check) : null,
                title: Text(o.emoji != null ? '${o.emoji} ${o.name}' : o.name),
                onTap: () => Navigator.of(ctx).pop(o.name),
              )),
        ],
      ),
    );

    if (selected == null) return;
    final updated = Map<String, String>.from(pref.defaultEntries);
    if (selected.isEmpty) {
      updated.remove(key);
    } else {
      updated[key] = selected;
    }
    await updateDefaultEntries(uid, updated);
  }
}
```

- [ ] **Step 11.3: Run tests**

```bash
flutter analyze --fatal-infos && flutter test test/features/settings/screens/default_entries_screen_test.dart
```

Expected: passes.

- [ ] **Step 11.4: Commit**

```bash
git add lib/features/settings/screens/default_entries_screen.dart \
        test/features/settings/screens/default_entries_screen_test.dart
git commit -m "feat: implement Default Entries settings sub-screen"
```

---

## Task 12: Currency selection sub-screen

**Files:**
- Modify: `lib/features/settings/screens/currency_selection_screen.dart` (replace stub)
- Create: `test/features/settings/screens/currency_selection_screen_test.dart`

- [ ] **Step 12.1: Write smoke test**

Create `test/features/settings/screens/currency_selection_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glint_budget_one/core/auth/auth_notifier.dart';
import 'package:glint_budget_one/core/auth/auth_state.dart';
import 'package:glint_budget_one/core/models/preference.dart';
import 'package:glint_budget_one/core/store/firestore_providers.dart';
import 'package:glint_budget_one/features/settings/screens/currency_selection_screen.dart';

void main() {
  testWidgets('shows list of currencies', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferenceStreamProvider.overrideWith((ref) => Preference.defaults()),
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
```

Run: FAIL.

- [ ] **Step 12.2: Replace currency_selection_screen.dart**

Replace the entire content of `lib/features/settings/screens/currency_selection_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/currencies.dart';
import '../../../core/models/currency.dart';
import '../../../core/store/firestore_providers.dart';
import '../../../core/store/preference_mutations.dart';

class CurrencySelectionScreen extends ConsumerWidget {
  const CurrencySelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pref = ref.watch(preferenceStreamProvider);
    final authState = ref.watch(authNotifierProvider);
    final uid = authState is AuthAuthenticated ? authState.user.uid : null;
    final currentCode = pref.defaultCurrency.code;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Currency')),
      body: ListView.builder(
        itemCount: kCurrencies.length,
        itemBuilder: (context, index) {
          final currency = kCurrencies[index];
          final isSelected = currency.code == currentCode;
          return ListTile(
            leading: Text(
              currency.symbol,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            title: Text(currency.code),
            subtitle: Text(currency.name),
            trailing: isSelected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: uid == null
                ? null
                : () async {
                    await updateDefaultCurrency(uid, currency);
                    if (context.mounted) Navigator.of(context).pop();
                  },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 12.3: Run tests**

```bash
flutter analyze --fatal-infos && flutter test test/features/settings/screens/
```

Expected: passes.

- [ ] **Step 12.4: Commit**

```bash
git add lib/features/settings/screens/currency_selection_screen.dart \
        test/features/settings/screens/currency_selection_screen_test.dart
git commit -m "feat: implement Currency Selection settings sub-screen"
```

---

## Task 13: Final integration check + tracker update

**Files:**
- Modify: `MASTER_IMPLEMENTATION_TRACKER.md`

- [ ] **Step 13.1: Run full test suite**

```bash
flutter analyze --fatal-infos && flutter test
```

Expected: all tests pass, no analyzer warnings.

- [ ] **Step 13.2: Update MASTER_IMPLEMENTATION_TRACKER.md**

Update the tracker:
1. Change `Current phase:` to `Phase 3 - Feature Parity`
2. Change Phase 3 row from `⬜ Not started` to `✅ Complete`
3. Update Dashboard screen row from `⬜ Placeholder` to `✅`
4. Update Transactions screen row from `⬜ Placeholder` to `✅`
5. Update Settings screen row from `⬜ Placeholder` to `✅`
6. Add new module rows:

| Module | Status | Location |
|---|---|---|
| Add/Edit transaction form | ✅ | `lib/features/add_transaction/` |
| Currency list | ✅ | `lib/core/currencies.dart` |
| Shared transaction tile | ✅ | `lib/core/widgets/transaction_tile.dart` |
| Default entries sub-screen | ✅ | `lib/features/settings/screens/` |
| Currency selection sub-screen | ✅ | `lib/features/settings/screens/` |
| Dashboard widgets | ✅ | `lib/features/dashboard/widgets/` |

- [ ] **Step 13.3: Final commit**

```bash
git add MASTER_IMPLEMENTATION_TRACKER.md
git commit -m "chore: mark Phase 3 complete in tracker"
```

---

## Self-Review Checklist (run after all tasks)

- [ ] `flutter analyze --fatal-infos` passes clean
- [ ] `flutter test` — all tests pass
- [ ] `flutter run -d chrome` — sign in works, dashboard shows stats/chart/list
- [ ] Navigate months on dashboard — list updates, no network calls
- [ ] Tap FAB on dashboard — Add Transaction form opens
- [ ] Fill form and save — transaction appears in dashboard and transactions list
- [ ] Tap a transaction to edit — form pre-fills with existing data
- [ ] Swipe left on transactions screen — delete confirmation dialog appears
- [ ] Settings screen — theme switcher changes app colors immediately
- [ ] Settings > Default Currency — currency list, selection persists
- [ ] Settings > Default Entries — bottom sheet pickers work
- [ ] Sign out — returns to sign-in screen
