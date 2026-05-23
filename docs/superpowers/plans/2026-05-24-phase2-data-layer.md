# Phase 2 — Data Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire real-time Firestore streams into a Riverpod provider graph so every screen stays in sync with any device automatically.

**Architecture:** Pure Riverpod `StreamProvider`s open two Firestore listeners on login (transactions + preference). Derived `Provider`s filter and aggregate in-memory — zero extra network calls. Mutations use `set(merge: true)` and rely on the stream echo for UI consistency. Offline persistence is enabled on all platforms.

**Tech Stack:** Flutter, Riverpod 2.x (`flutter_riverpod ^2.5.1`), `cloud_firestore ^5.4.4`, `firebase_auth ^5.3.1`

**Spec:** `docs/superpowers/specs/2026-05-24-phase2-data-layer-design.md`

**Run after every task before committing:**
```bash
flutter analyze --fatal-infos && flutter test
```

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `lib/core/models/currency.dart` | CREATE | Currency value type + Firestore mapping |
| `lib/core/models/budget_data.dart` | CREATE | BudgetData value type + Firestore mapping |
| `lib/core/models/transaction.dart` | CREATE | Transaction value type + Firestore mapping |
| `lib/core/models/dashboard_stats.dart` | CREATE | Computed stats value type (no Firestore) |
| `lib/core/models/preference.dart` | CREATE | Preference value type + complex defaultEntries decoding |
| `lib/core/sync/sync_status.dart` | CREATE | SyncStatus enum + pure helper function |
| `lib/core/store/firestore_providers.dart` | CREATE | authStateProvider, transactionsStreamProvider, preferenceSnapshotProvider, preferenceStreamProvider |
| `lib/core/store/derived_providers.dart` | CREATE | selectedMonthProvider, filteredTransactionsProvider, dashboardStatsProvider, syncStatusProvider |
| `lib/core/store/transaction_mutations.dart` | CREATE | addTransaction, updateTransaction, deleteTransaction |
| `lib/core/store/preference_mutations.dart` | CREATE | updateTheme, updateSpendingChartType, updateDefaultCurrency, updateDefaultEntries |
| `lib/core/theme/theme_provider.dart` | MODIFY | Rewire from local StateNotifier to preferenceStreamProvider |
| `lib/app/app_shell.dart` | MODIFY | Convert to ConsumerWidget, add sync status indicator |
| `lib/main.dart` | MODIFY | Enable Firestore offline persistence on web |
| `test/core/models/currency_test.dart` | CREATE | fromMap / toFirestore round-trip |
| `test/core/models/budget_data_test.dart` | CREATE | fromMap / toMap round-trip |
| `test/core/models/transaction_test.dart` | CREATE | fromMap / toFirestore with Timestamp conversion |
| `test/core/models/dashboard_stats_test.dart` | CREATE | Computed fields |
| `test/core/models/preference_test.dart` | CREATE | defaultEntries: flat-array decode + Map decode |
| `test/core/sync/sync_status_test.dart` | CREATE | syncStatusFromFlags pure function |
| `test/core/store/derived_providers_test.dart` | CREATE | filteredTransactions and dashboardStats computation |

---

## Task 1: Currency model

**Files:**
- Create: `lib/core/models/currency.dart`
- Create: `test/core/models/currency_test.dart`

- [ ] **Step 1.1: Write the failing test**

```dart
// test/core/models/currency_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/currency.dart';

void main() {
  group('Currency', () {
    test('fromMap maps all fields', () {
      final c = Currency.fromMap({'name': 'Singapore Dollar', 'code': 'SGD', 'symbol': 'S\$'});
      expect(c.name, 'Singapore Dollar');
      expect(c.code, 'SGD');
      expect(c.symbol, 'S\$');
    });

    test('toFirestore round-trips', () {
      const c = Currency(name: 'Euro', code: 'EUR', symbol: '€');
      expect(Currency.fromMap(c.toFirestore()), equals(c));
    });

    test('fromMap handles missing fields with empty strings', () {
      final c = Currency.fromMap({});
      expect(c.name, '');
      expect(c.code, '');
      expect(c.symbol, '');
    });

    test('defaults returns USD', () {
      expect(Currency.defaults.code, 'USD');
    });
  });
}
```

- [ ] **Step 1.2: Run test — expect FAIL (class not found)**

```bash
flutter test test/core/models/currency_test.dart
```

Expected: compilation error — `Currency` not defined.

- [ ] **Step 1.3: Implement `Currency`**

```dart
// lib/core/models/currency.dart
import 'package:flutter/foundation.dart';

@immutable
class Currency {
  const Currency({
    required this.name,
    required this.code,
    required this.symbol,
  });

  final String name;
  final String code;
  final String symbol;

  static const Currency defaults =
      Currency(name: 'US Dollar', code: 'USD', symbol: '\$');

  factory Currency.fromMap(Map<String, dynamic> data) => Currency(
        name: data['name'] as String? ?? '',
        code: data['code'] as String? ?? '',
        symbol: data['symbol'] as String? ?? '',
      );

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'code': code,
        'symbol': symbol,
      };

  @override
  bool operator ==(Object other) =>
      other is Currency && other.code == code && other.name == name && other.symbol == symbol;

  @override
  int get hashCode => Object.hash(name, code, symbol);
}
```

- [ ] **Step 1.4: Run test — expect PASS**

```bash
flutter test test/core/models/currency_test.dart
```

Expected: All 4 tests pass.

- [ ] **Step 1.5: Analyze and commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/core/models/currency.dart test/core/models/currency_test.dart
git commit -m "feat: add Currency model with Firestore mapping"
```

---

## Task 2: BudgetData model

**Files:**
- Create: `lib/core/models/budget_data.dart`
- Create: `test/core/models/budget_data_test.dart`

- [ ] **Step 2.1: Write the failing test**

```dart
// test/core/models/budget_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/budget_data.dart';

void main() {
  group('BudgetData', () {
    test('fromMap maps all fields', () {
      final b = BudgetData.fromMap({
        'name': 'Groceries',
        'type': 'category',
        'emoji': '🛒',
        'parent': null,
      });
      expect(b.name, 'Groceries');
      expect(b.type, 'category');
      expect(b.emoji, '🛒');
      expect(b.parent, isNull);
    });

    test('fromMap handles optional fields absent', () {
      final b = BudgetData.fromMap({'name': 'Visa', 'type': 'payment'});
      expect(b.emoji, isNull);
      expect(b.parent, isNull);
    });

    test('toMap round-trips all fields', () {
      const b = BudgetData(name: 'Food', type: 'sub_category', emoji: '🍔', parent: 'category');
      final map = b.toMap();
      expect(map['name'], 'Food');
      expect(map['type'], 'sub_category');
      expect(map['emoji'], '🍔');
      expect(map['parent'], 'category');
    });

    test('toMap omits null optional fields', () {
      const b = BudgetData(name: 'DBS', type: 'account');
      final map = b.toMap();
      expect(map.containsKey('emoji'), isFalse);
      expect(map.containsKey('parent'), isFalse);
    });
  });
}
```

- [ ] **Step 2.2: Run test — expect FAIL**

```bash
flutter test test/core/models/budget_data_test.dart
```

Expected: compilation error — `BudgetData` not defined.

- [ ] **Step 2.3: Implement `BudgetData`**

```dart
// lib/core/models/budget_data.dart
import 'package:flutter/foundation.dart';

@immutable
class BudgetData {
  const BudgetData({
    required this.name,
    required this.type,
    this.emoji,
    this.parent,
  });

  final String name;
  final String type; // "vendor" | "account" | "category" | "sub_category" | "payment"
  final String? emoji;
  final String? parent;

  factory BudgetData.fromMap(Map<String, dynamic> data) => BudgetData(
        name: data['name'] as String? ?? '',
        type: data['type'] as String? ?? '',
        emoji: data['emoji'] as String?,
        parent: data['parent'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        if (emoji != null) 'emoji': emoji,
        if (parent != null) 'parent': parent,
      };
}
```

- [ ] **Step 2.4: Run test — expect PASS**

```bash
flutter test test/core/models/budget_data_test.dart
```

Expected: All 4 tests pass.

- [ ] **Step 2.5: Analyze and commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/core/models/budget_data.dart test/core/models/budget_data_test.dart
git commit -m "feat: add BudgetData model with Firestore mapping"
```

---

## Task 3: Transaction model

**Files:**
- Create: `lib/core/models/transaction.dart`
- Create: `test/core/models/transaction_test.dart`

- [ ] **Step 3.1: Write the failing test**

```dart
// test/core/models/transaction_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/transaction.dart';

void main() {
  group('Transaction', () {
    final sampleDate = DateTime(2026, 5, 10, 12, 0);

    final sampleMap = {
      'user_id': 'uid-123',
      'category': 'Food',
      'sub_category': 'Groceries',
      'date': Timestamp.fromDate(sampleDate),
      'account': 'DBS',
      'vendor': 'FairPrice',
      'payment': 'Visa',
      'currency': 'SGD',
      'notes': 'weekly shop',
      'amount': 42.50,
      'icon': '🛒',
    };

    test('fromMap maps all fields correctly', () {
      final t = Transaction.fromMap('txn-1', sampleMap);
      expect(t.id, 'txn-1');
      expect(t.userId, 'uid-123');
      expect(t.category, 'Food');
      expect(t.subCategory, 'Groceries');
      expect(t.date, sampleDate);
      expect(t.account, 'DBS');
      expect(t.vendor, 'FairPrice');
      expect(t.payment, 'Visa');
      expect(t.currency, 'SGD');
      expect(t.notes, 'weekly shop');
      expect(t.amount, 42.50);
      expect(t.icon, '🛒');
    });

    test('toFirestore writes correct Firestore field names', () {
      final t = Transaction.fromMap('txn-1', sampleMap);
      final map = t.toFirestore();
      expect(map.containsKey('user_id'), isTrue);
      expect(map.containsKey('sub_category'), isTrue);
      expect(map['user_id'], 'uid-123');
      expect(map['sub_category'], 'Groceries');
      expect(map['date'], isA<Timestamp>());
      expect((map['date'] as Timestamp).toDate(), sampleDate);
    });

    test('fromMap defaults missing fields gracefully', () {
      final t = Transaction.fromMap('txn-x', {});
      expect(t.id, 'txn-x');
      expect(t.userId, '');
      expect(t.amount, 0.0);
    });

    test('amount handles int Firestore values', () {
      final t = Transaction.fromMap('txn-2', {...sampleMap, 'amount': 100});
      expect(t.amount, 100.0);
    });
  });
}
```

- [ ] **Step 3.2: Run test — expect FAIL**

```bash
flutter test test/core/models/transaction_test.dart
```

Expected: compilation error — `Transaction` not defined.

- [ ] **Step 3.3: Implement `Transaction`**

```dart
// lib/core/models/transaction.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class Transaction {
  const Transaction({
    required this.id,
    required this.userId,
    required this.category,
    required this.subCategory,
    required this.date,
    required this.account,
    required this.vendor,
    required this.payment,
    required this.currency,
    required this.notes,
    required this.amount,
    required this.icon,
  });

  final String id;
  final String userId;
  final String category;
  final String subCategory;
  final DateTime date;
  final String account;
  final String vendor;
  final String payment;
  final String currency;
  final String notes;
  final double amount;
  final String icon;

  factory Transaction.fromMap(String id, Map<String, dynamic> data) {
    final dateRaw = data['date'];
    final date = dateRaw is Timestamp
        ? dateRaw.toDate()
        : dateRaw is DateTime
            ? dateRaw
            : DateTime.now();

    return Transaction(
      id: id,
      userId: data['user_id'] as String? ?? '',
      category: data['category'] as String? ?? '',
      subCategory: data['sub_category'] as String? ?? '',
      date: date,
      account: data['account'] as String? ?? '',
      vendor: data['vendor'] as String? ?? '',
      payment: data['payment'] as String? ?? '',
      currency: data['currency'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      icon: data['icon'] as String? ?? '',
    );
  }

  factory Transaction.fromFirestore(DocumentSnapshot doc) =>
      Transaction.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});

  Map<String, dynamic> toFirestore() => {
        'user_id': userId,
        'category': category,
        'sub_category': subCategory,
        'date': Timestamp.fromDate(date),
        'account': account,
        'vendor': vendor,
        'payment': payment,
        'currency': currency,
        'notes': notes,
        'amount': amount,
        'icon': icon,
      };
}
```

- [ ] **Step 3.4: Run test — expect PASS**

```bash
flutter test test/core/models/transaction_test.dart
```

Expected: All 4 tests pass.

- [ ] **Step 3.5: Analyze and commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/core/models/transaction.dart test/core/models/transaction_test.dart
git commit -m "feat: add Transaction model with Firestore mapping"
```

---

## Task 4: DashboardStats model

**Files:**
- Create: `lib/core/models/dashboard_stats.dart`
- Create: `test/core/models/dashboard_stats_test.dart`

- [ ] **Step 4.1: Write the failing test**

```dart
// test/core/models/dashboard_stats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/dashboard_stats.dart';

void main() {
  group('DashboardStats', () {
    test('balance is totalIncome minus totalExpense', () {
      const stats = DashboardStats(
        totalIncome: 1000.0,
        totalExpense: 350.0,
        categoryBreakdown: {},
      );
      expect(stats.balance, closeTo(650.0, 0.001));
    });

    test('empty has all zero values', () {
      expect(DashboardStats.empty.totalIncome, 0.0);
      expect(DashboardStats.empty.totalExpense, 0.0);
      expect(DashboardStats.empty.balance, 0.0);
      expect(DashboardStats.empty.categoryBreakdown, isEmpty);
    });

    test('categoryBreakdown holds per-category totals', () {
      const stats = DashboardStats(
        totalIncome: 0,
        totalExpense: 150.0,
        categoryBreakdown: {'Food': 80.0, 'Transport': 70.0},
      );
      expect(stats.categoryBreakdown['Food'], 80.0);
      expect(stats.categoryBreakdown['Transport'], 70.0);
    });
  });
}
```

- [ ] **Step 4.2: Run test — expect FAIL**

```bash
flutter test test/core/models/dashboard_stats_test.dart
```

Expected: compilation error — `DashboardStats` not defined.

- [ ] **Step 4.3: Implement `DashboardStats`**

```dart
// lib/core/models/dashboard_stats.dart
import 'package:flutter/foundation.dart';

@immutable
class DashboardStats {
  const DashboardStats({
    required this.totalIncome,
    required this.totalExpense,
    required this.categoryBreakdown,
  });

  final double totalIncome;
  final double totalExpense;
  final Map<String, double> categoryBreakdown;

  double get balance => totalIncome - totalExpense;

  static const DashboardStats empty = DashboardStats(
    totalIncome: 0,
    totalExpense: 0,
    categoryBreakdown: {},
  );
}
```

- [ ] **Step 4.4: Run test — expect PASS**

```bash
flutter test test/core/models/dashboard_stats_test.dart
```

Expected: All 3 tests pass.

- [ ] **Step 4.5: Analyze and commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/core/models/dashboard_stats.dart test/core/models/dashboard_stats_test.dart
git commit -m "feat: add DashboardStats value class"
```

---

## Task 5: Preference model

**Files:**
- Create: `lib/core/models/preference.dart`
- Create: `test/core/models/preference_test.dart`

The key complexity here is `default_entries`: written by Swift as a flat alternating array `["vendor", "FairPrice", "category", "Food"]`, read by Dart into `Map<String,String>`, and written back by Dart as a standard Firestore Map.

- [ ] **Step 5.1: Write the failing test**

```dart
// test/core/models/preference_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/budget_data.dart';
import 'package:glintbudgetone/core/models/currency.dart';
import 'package:glintbudgetone/core/models/preference.dart';

void main() {
  group('Preference.defaults', () {
    test('has USD default currency', () {
      expect(Preference.defaults().defaultCurrency.code, 'USD');
    });

    test('themeId defaults to null', () {
      expect(Preference.defaults().themeId, isNull);
    });
  });

  group('Preference.fromMap – defaultEntries', () {
    test('decodes flat alternating array from Swift', () {
      final pref = Preference.fromMap({
        'default_entries': ['vendor', 'FairPrice', 'category', 'Food'],
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      expect(pref.defaultEntries['vendor'], 'FairPrice');
      expect(pref.defaultEntries['category'], 'Food');
    });

    test('decodes already-normalised Firestore Map', () {
      final pref = Preference.fromMap({
        'default_entries': {'vendor': 'NTUC', 'category': 'Groceries'},
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      expect(pref.defaultEntries['vendor'], 'NTUC');
    });

    test('handles missing default_entries', () {
      final pref = Preference.fromMap({
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      expect(pref.defaultEntries, isEmpty);
    });

    test('handles odd-length flat array safely', () {
      final pref = Preference.fromMap({
        'default_entries': ['vendor', 'FairPrice', 'dangling'],
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      expect(pref.defaultEntries['vendor'], 'FairPrice');
      expect(pref.defaultEntries.length, 1);
    });
  });

  group('Preference.fromMap – other fields', () {
    test('maps bookmarkedCurrencies from frequent_currencies', () {
      final pref = Preference.fromMap({
        'frequent_currencies': ['SGD', 'EUR'],
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      expect(pref.bookmarkedCurrencies, containsAll(['SGD', 'EUR']));
    });

    test('reads themeId and spendingChartType', () {
      final pref = Preference.fromMap({
        'themeId': 'forest',
        'spendingChartType': 'line',
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      expect(pref.themeId, 'forest');
      expect(pref.spendingChartType, 'line');
    });

    test('maps accounts list', () {
      final pref = Preference.fromMap({
        'accounts': [
          {'name': 'DBS', 'type': 'account'},
        ],
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      expect(pref.accounts?.first.name, 'DBS');
    });
  });

  group('Preference.toFirestore', () {
    test('writes default_entries as a Map (normalised format)', () {
      final pref = Preference.fromMap({
        'default_entries': ['vendor', 'FairPrice'],
        'default_currency': {'name': 'US Dollar', 'code': 'USD', 'symbol': '\$'},
      });
      final written = pref.toFirestore();
      expect(written['default_entries'], isA<Map>());
      expect((written['default_entries'] as Map)['vendor'], 'FairPrice');
    });

    test('writes frequent_currencies for bookmarkedCurrencies', () {
      final pref = Preference(
        defaultCurrency: Currency.defaults,
        bookmarkedCurrencies: ['SGD'],
        defaultEntries: {},
      );
      expect(pref.toFirestore()['frequent_currencies'], ['SGD']);
    });
  });
}
```

- [ ] **Step 5.2: Run test — expect FAIL**

```bash
flutter test test/core/models/preference_test.dart
```

Expected: compilation error — `Preference` not defined.

- [ ] **Step 5.3: Implement `Preference`**

```dart
// lib/core/models/preference.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'budget_data.dart';
import 'currency.dart';

@immutable
class Preference {
  const Preference({
    this.accounts,
    this.categories,
    this.subCategories,
    this.vendors,
    this.payments,
    required this.defaultCurrency,
    this.bookmarkedCurrencies = const [],
    this.defaultEntries = const {},
    this.themeId,
    this.spendingChartType,
  });

  final List<BudgetData>? accounts;
  final List<BudgetData>? categories;
  final List<BudgetData>? subCategories;
  final List<BudgetData>? vendors;
  final List<BudgetData>? payments;
  final Currency defaultCurrency;
  final List<String> bookmarkedCurrencies;
  final Map<String, String> defaultEntries;
  final String? themeId;
  final String? spendingChartType;

  static Preference defaults() =>
      const Preference(defaultCurrency: Currency.defaults);

  factory Preference.fromFirestore(DocumentSnapshot doc) =>
      Preference.fromMap(doc.data() as Map<String, dynamic>? ?? {});

  factory Preference.fromMap(Map<String, dynamic> data) {
    final rawCurrency = data['default_currency'];
    final currency = rawCurrency is Map<String, dynamic>
        ? Currency.fromMap(rawCurrency)
        : Currency.defaults;

    return Preference(
      accounts: _budgetDataList(data['accounts']),
      categories: _budgetDataList(data['categories']),
      subCategories: _budgetDataList(data['subCategories']),
      vendors: _budgetDataList(data['vendors']),
      payments: _budgetDataList(data['payments']),
      defaultCurrency: currency,
      bookmarkedCurrencies: (data['frequent_currencies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      defaultEntries: _decodeDefaultEntries(data['default_entries']),
      themeId: data['themeId'] as String?,
      spendingChartType: data['spendingChartType'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        if (accounts != null)
          'accounts': accounts!.map((b) => b.toMap()).toList(),
        if (categories != null)
          'categories': categories!.map((b) => b.toMap()).toList(),
        if (subCategories != null)
          'subCategories': subCategories!.map((b) => b.toMap()).toList(),
        if (vendors != null)
          'vendors': vendors!.map((b) => b.toMap()).toList(),
        if (payments != null)
          'payments': payments!.map((b) => b.toMap()).toList(),
        'default_currency': defaultCurrency.toFirestore(),
        'frequent_currencies': bookmarkedCurrencies,
        'default_entries': defaultEntries, // Map — normalised format
        if (themeId != null) 'themeId': themeId,
        if (spendingChartType != null) 'spendingChartType': spendingChartType,
      };

  static List<BudgetData>? _budgetDataList(dynamic raw) {
    if (raw == null) return null;
    return (raw as List<dynamic>)
        .map((e) => BudgetData.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Reads Swift's flat alternating array OR an already-normalised Firestore Map.
  static Map<String, String> _decodeDefaultEntries(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      return Map<String, String>.fromEntries(
        raw.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())),
      );
    }
    if (raw is List) {
      final result = <String, String>{};
      for (var i = 0; i + 1 < raw.length; i += 2) {
        result[raw[i].toString()] = raw[i + 1].toString();
      }
      return result;
    }
    return {};
  }
}
```

- [ ] **Step 5.4: Run test — expect PASS**

```bash
flutter test test/core/models/preference_test.dart
```

Expected: All 10 tests pass.

- [ ] **Step 5.5: Analyze and commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/core/models/preference.dart test/core/models/preference_test.dart
git commit -m "feat: add Preference model with Swift-compatible defaultEntries decoding"
```

---

## Task 6: SyncStatus enum and pure helper function

**Files:**
- Create: `lib/core/sync/sync_status.dart`
- Create: `test/core/sync/sync_status_test.dart`

- [ ] **Step 6.1: Write the failing test**

```dart
// test/core/sync/sync_status_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/sync/sync_status.dart';

void main() {
  group('syncStatusFromFlags', () {
    test('hasPendingWrites → pending', () {
      expect(
        syncStatusFromFlags(hasPendingWrites: true, isFromCache: false),
        SyncStatus.pending,
      );
    });

    test('isFromCache → offline', () {
      expect(
        syncStatusFromFlags(hasPendingWrites: false, isFromCache: true),
        SyncStatus.offline,
      );
    });

    test('neither → synced', () {
      expect(
        syncStatusFromFlags(hasPendingWrites: false, isFromCache: false),
        SyncStatus.synced,
      );
    });

    test('hasPendingWrites takes priority over isFromCache', () {
      // Firestore can have pending writes while from cache simultaneously.
      expect(
        syncStatusFromFlags(hasPendingWrites: true, isFromCache: true),
        SyncStatus.pending,
      );
    });
  });
}
```

- [ ] **Step 6.2: Run test — expect FAIL**

```bash
flutter test test/core/sync/sync_status_test.dart
```

Expected: compilation error.

- [ ] **Step 6.3: Implement `SyncStatus`**

```dart
// lib/core/sync/sync_status.dart
enum SyncStatus { synced, pending, offline }

SyncStatus syncStatusFromFlags({
  required bool hasPendingWrites,
  required bool isFromCache,
}) {
  if (hasPendingWrites) return SyncStatus.pending;
  if (isFromCache) return SyncStatus.offline;
  return SyncStatus.synced;
}
```

- [ ] **Step 6.4: Run test — expect PASS**

```bash
flutter test test/core/sync/sync_status_test.dart
```

Expected: All 4 tests pass.

- [ ] **Step 6.5: Analyze and commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/core/sync/sync_status.dart test/core/sync/sync_status_test.dart
git commit -m "feat: add SyncStatus enum and pure helper function"
```

---

## Task 7: Enable offline persistence in `main.dart`

**Files:**
- Modify: `lib/main.dart`

No test needed — this is a platform configuration call with a silent catch. Correctness is verified by checking the web app works offline.

- [ ] **Step 7.1: Update `main.dart`**

Replace the entire file:

```dart
// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kIsWeb) {
    // IndexedDB-backed offline cache for web. Silent catch: some browsers
    // block IndexedDB (private mode, extensions), which is acceptable.
    FirebaseFirestore.instance
        .enablePersistence(const PersistenceSettings(synchronizeTabs: true))
        .catchError((_) {});
  }
  runApp(const ProviderScope(child: App()));
}
```

- [ ] **Step 7.2: Analyze and commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/main.dart
git commit -m "feat: enable Firestore offline persistence on web"
```

---

## Task 8: Firestore providers

**Files:**
- Create: `lib/core/store/firestore_providers.dart`

These providers open Firestore listeners. They are not unit-tested here (require a real or emulated Firestore connection). Integration testing happens manually by running the app.

- [ ] **Step 8.1: Implement `firestore_providers.dart`**

```dart
// lib/core/store/firestore_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/preference.dart';
import '../models/transaction.dart';

/// Raw Firebase auth stream. Used by other providers to get the current uid.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// All transactions for the signed-in user, ordered by date descending.
/// Returns an empty list when unauthenticated.
final transactionsStreamProvider = StreamProvider<List<Transaction>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('transactions')
      .where('user_id', isEqualTo: uid)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map(Transaction.fromFirestore).toList());
});

/// Raw preference DocumentSnapshot — metadata preserved for syncStatusProvider.
/// Returns a null stream when unauthenticated.
final preferenceSnapshotProvider = StreamProvider<DocumentSnapshot?>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('preference')
      .doc(uid)
      .snapshots()
      .cast<DocumentSnapshot?>();
});

/// Decoded Preference. Derives from preferenceSnapshotProvider.
/// Always has a value (Preference.defaults() when loading or doc absent).
final preferenceStreamProvider = Provider<Preference>((ref) {
  final snapshot = ref.watch(preferenceSnapshotProvider).valueOrNull;
  if (snapshot == null || !snapshot.exists) return Preference.defaults();
  return Preference.fromFirestore(snapshot);
});
```

- [ ] **Step 8.2: Analyze and commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/core/store/firestore_providers.dart
git commit -m "feat: add Firestore stream providers (transactions, preference)"
```

---

## Task 9: Derived providers + tests

**Files:**
- Create: `lib/core/store/derived_providers.dart`
- Create: `test/core/store/derived_providers_test.dart`

- [ ] **Step 9.1: Write the failing test**

```dart
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
}
```

- [ ] **Step 9.2: Run test — expect FAIL**

```bash
flutter test test/core/store/derived_providers_test.dart
```

Expected: compilation error — `derived_providers.dart` not found.

- [ ] **Step 9.3: Implement `derived_providers.dart`**

Note: Transactions with `amount > 0` are treated as income; `amount < 0` as expense. This matches the sign convention assumed from the Firestore schema. Verify against real data in Phase 3.

```dart
// lib/core/store/derived_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_stats.dart';
import '../models/transaction.dart';
import '../sync/sync_status.dart';
import 'firestore_providers.dart';

/// The month currently displayed across all screens. Defaults to now.
final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Transactions in the selected month, filtered in-memory — no network call.
final filteredTransactionsProvider = Provider<List<Transaction>>((ref) {
  final all = ref.watch(transactionsStreamProvider).valueOrNull ?? [];
  final month = ref.watch(selectedMonthProvider);
  return all
      .where((t) => t.date.year == month.year && t.date.month == month.month)
      .toList();
});

/// Dashboard stats computed from filtered transactions — pure, no network call.
/// Income = positive amounts. Expense = negative amounts (shown as absolute).
final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final txns = ref.watch(filteredTransactionsProvider);
  if (txns.isEmpty) return DashboardStats.empty;

  double income = 0;
  double expense = 0;
  final breakdown = <String, double>{};

  for (final t in txns) {
    if (t.amount >= 0) {
      income += t.amount;
    } else {
      final abs = t.amount.abs();
      expense += abs;
      breakdown[t.category] = (breakdown[t.category] ?? 0) + abs;
    }
  }

  return DashboardStats(
    totalIncome: income,
    totalExpense: expense,
    categoryBreakdown: breakdown,
  );
});

/// Sync status derived from the raw Firestore snapshot metadata.
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final snapshot = ref.watch(preferenceSnapshotProvider).valueOrNull;
  if (snapshot == null) return SyncStatus.synced;
  return syncStatusFromFlags(
    hasPendingWrites: snapshot.metadata.hasPendingWrites,
    isFromCache: snapshot.metadata.isFromCache,
  );
});
```

- [ ] **Step 9.4: Add `DashboardStats.empty` equality support for the test**

The test compares `stats` to `DashboardStats.empty` using `equals()`. Add `==` and `hashCode` to `DashboardStats`:

Open `lib/core/models/dashboard_stats.dart` and replace the file:

```dart
// lib/core/models/dashboard_stats.dart
import 'package:flutter/foundation.dart';

@immutable
class DashboardStats {
  const DashboardStats({
    required this.totalIncome,
    required this.totalExpense,
    required this.categoryBreakdown,
  });

  final double totalIncome;
  final double totalExpense;
  final Map<String, double> categoryBreakdown;

  double get balance => totalIncome - totalExpense;

  static const DashboardStats empty = DashboardStats(
    totalIncome: 0,
    totalExpense: 0,
    categoryBreakdown: {},
  );

  @override
  bool operator ==(Object other) =>
      other is DashboardStats &&
      other.totalIncome == totalIncome &&
      other.totalExpense == totalExpense &&
      mapEquals(other.categoryBreakdown, categoryBreakdown);

  @override
  int get hashCode => Object.hash(totalIncome, totalExpense, categoryBreakdown);
}
```

- [ ] **Step 9.5: Run test — expect PASS**

```bash
flutter test test/core/store/derived_providers_test.dart
```

Expected: All 5 tests pass.

- [ ] **Step 9.6: Analyze and commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/core/store/derived_providers.dart \
        lib/core/models/dashboard_stats.dart \
        test/core/store/derived_providers_test.dart
git commit -m "feat: add derived providers (filtered transactions, dashboard stats, sync status)"
```

---

## Task 10: Transaction mutations

**Files:**
- Create: `lib/core/store/transaction_mutations.dart`

Mutations rely on the Firestore stream echo for UI consistency — no manual cache patching needed. The Firestore SDK queues writes offline and retries on reconnect.

- [ ] **Step 10.1: Implement `transaction_mutations.dart`**

```dart
// lib/core/store/transaction_mutations.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction.dart';

CollectionReference<Map<String, dynamic>> _txCollection() =>
    FirebaseFirestore.instance.collection('transactions');

Future<void> addTransaction(Transaction t) =>
    _txCollection().doc(t.id).set(t.toFirestore());

Future<void> updateTransaction(Transaction t) =>
    _txCollection().doc(t.id).set(t.toFirestore(), SetOptions(merge: true));

Future<void> deleteTransaction(String id) =>
    _txCollection().doc(id).delete();
```

- [ ] **Step 10.2: Analyze and commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/core/store/transaction_mutations.dart
git commit -m "feat: add transaction mutations (add, update, delete)"
```

---

## Task 11: Preference mutations

**Files:**
- Create: `lib/core/store/preference_mutations.dart`

- [ ] **Step 11.1: Implement `preference_mutations.dart`**

```dart
// lib/core/store/preference_mutations.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/currency.dart';

DocumentReference<Map<String, dynamic>> _prefDoc(String uid) =>
    FirebaseFirestore.instance.collection('preference').doc(uid);

Future<void> updateTheme(String uid, String themeId) =>
    _prefDoc(uid).set({'themeId': themeId}, SetOptions(merge: true));

Future<void> updateSpendingChartType(String uid, String chartType) =>
    _prefDoc(uid).set({'spendingChartType': chartType}, SetOptions(merge: true));

Future<void> updateDefaultCurrency(String uid, Currency currency) =>
    _prefDoc(uid).set(
      {'default_currency': currency.toFirestore()},
      SetOptions(merge: true),
    );

/// Writes entries as a Firestore Map (normalised format), regardless of how
/// they were originally stored by the Swift app.
Future<void> updateDefaultEntries(String uid, Map<String, String> entries) =>
    _prefDoc(uid).set({'default_entries': entries}, SetOptions(merge: true));
```

- [ ] **Step 11.2: Analyze and commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/core/store/preference_mutations.dart
git commit -m "feat: add preference mutations (theme, chart type, currency, default entries)"
```

---

## Task 12: Rewire ThemeProvider

**Files:**
- Modify: `lib/core/theme/theme_provider.dart`

The `themeProvider` API (`Provider<AppTheme>`) stays unchanged — `app.dart` continues using `ref.watch(themeProvider)` without modification. The `StateNotifier` is removed; the source of truth moves to Firestore via `preferenceStreamProvider`.

- [ ] **Step 12.1: Replace `theme_provider.dart`**

```dart
// lib/core/theme/theme_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../store/firestore_providers.dart';
import 'app_theme.dart';

/// Active theme, derived from the user's Firestore preference.
/// Defaults to amber when preference is loading or themeId is absent.
final themeProvider = Provider<AppTheme>((ref) {
  final pref = ref.watch(preferenceStreamProvider);
  return themeById(pref.themeId ?? 'amber');
});
```

- [ ] **Step 12.2: Run all tests**

```bash
flutter analyze --fatal-infos && flutter test
```

Expected: All tests pass. The existing `theme_registry_test.dart` still passes because `themeRegistry` and `themeById` in `app_theme.dart` are unchanged.

- [ ] **Step 12.3: Commit**

```bash
git add lib/core/theme/theme_provider.dart
git commit -m "feat: rewire ThemeProvider to read themeId from Firestore preference"
```

---

## Task 13: Sync status indicator in AppShell

**Files:**
- Modify: `lib/app/app_shell.dart`

`AppShell` becomes a `ConsumerWidget`. A small `_SyncDot` widget reads `syncStatusProvider` and renders nothing when synced, an amber dot when pending, and a grey dot when offline. A `Tooltip` wraps it for accessibility.

- [ ] **Step 13.1: Replace `app_shell.dart`**

```dart
// lib/app/app_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/store/derived_providers.dart';
import '../core/sync/sync_status.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Transactions',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  static const _routes = [
    '/app/dashboard',
    '/app/transactions',
    '/app/settings',
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _routes.length; i++) {
      if (location.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  void _onTap(BuildContext context, int index) => context.go(_routes[index]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _selectedIndex(context);
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final syncStatus = ref.watch(syncStatusProvider);

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) => _onTap(context, i),
              labelType: NavigationRailLabelType.all,
              trailing: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _SyncDot(syncStatus),
              ),
              destinations: _destinations
                  .map((d) => NavigationRailDestination(
                        icon: d.icon,
                        selectedIcon: d.selectedIcon ?? d.icon,
                        label: Text(d.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _SyncDot(syncStatus),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: _destinations,
      ),
    );
  }
}

class _SyncDot extends StatelessWidget {
  const _SyncDot(this.status);

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      SyncStatus.synced => const SizedBox.shrink(),
      SyncStatus.pending => Tooltip(
          message: 'Saving…',
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      SyncStatus.offline => const Tooltip(
          message: 'Offline',
          child: Icon(Icons.cloud_off_outlined, size: 18),
        ),
    };
  }
}
```

- [ ] **Step 13.2: Run all tests**

```bash
flutter analyze --fatal-infos && flutter test
```

Expected: All tests pass. The existing `app_shell_test.dart` may need updating if it checked for `StatelessWidget` — verify and update if needed.

- [ ] **Step 13.3: Check and fix `app_shell_test.dart` if needed**

Open `test/app/app_shell_test.dart`. If it instantiates `AppShell` outside a `ProviderScope`, wrap with `ProviderScope`:

```dart
// Before:
await tester.pumpWidget(MaterialApp(home: AppShell(child: Text('test'))));

// After:
await tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(home: AppShell(child: const Text('test'))),
  ),
);
```

Run `flutter test` again after any fix.

- [ ] **Step 13.4: Update MASTER_IMPLEMENTATION_TRACKER.md**

Open `MASTER_IMPLEMENTATION_TRACKER.md` and update:

1. Change `Current phase:` to `Phase 2 — Data Layer`
2. Change Phase 2 row from `⬜ Not started` to `✅ Complete`
3. Update module status rows:

| Module | Status |
|---|---|
| Firestore streams | ✅ `lib/core/store/firestore_providers.dart` |
| Sync status | ✅ `lib/core/sync/sync_status.dart` |
| Data models | ✅ `lib/core/models/` |
| Derived providers | ✅ `lib/core/store/derived_providers.dart` |
| Transaction mutations | ✅ `lib/core/store/transaction_mutations.dart` |
| Preference mutations | ✅ `lib/core/store/preference_mutations.dart` |

- [ ] **Step 13.5: Analyze, test, and commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/app/app_shell.dart test/app/app_shell_test.dart MASTER_IMPLEMENTATION_TRACKER.md
git commit -m "feat: add sync status indicator to AppShell; complete Phase 2 data layer"
```

---

## Self-Review Checklist (run after all tasks)

- [ ] `flutter analyze --fatal-infos` passes clean
- [ ] `flutter test` — all tests pass
- [ ] `flutter run -d chrome` — app loads, sign-in works, sync dot hidden when synced
- [ ] Sign in, navigate dashboard/transactions/settings — no errors in console
- [ ] Make a Firestore change from another device or the Firebase Console — UI updates without refresh
