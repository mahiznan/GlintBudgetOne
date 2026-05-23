# GlintBudget Flutter — Phase 2: Data Layer Design

**Date:** 2026-05-24  
**Project:** GlintBudgetOne  
**Status:** Approved — ready for implementation planning  
**Phase:** 2 — Data Layer  
**Spec:** Extends `2026-05-23-flutter-migration-design.md`

---

## 1. Goals

Real-time data flows. UI reflects changes from any device instantly with no extra network calls after login.

- Firestore stream providers (`transactionsStreamProvider`, `preferenceStreamProvider`)
- Derived providers: filtered transactions, dashboard stats, sync status
- Optimistic-free mutations (stream echo handles consistency)
- Theme and chart type persisted to Firestore (read+write)
- Sync status indicator in app shell
- Offline persistence on all platforms (iOS, Android, Web)

---

## 2. Architecture: Approach

Pure Riverpod `StreamProvider`s. No repository abstraction layer, no `AsyncNotifier`. All Firestore access is in top-level providers. Mutations are standalone `async` functions. Matches the approved spec from `2026-05-23-flutter-migration-design.md` exactly.

---

## 3. Data Models (`lib/core/models/`)

Plain Dart classes. Each has a `fromFirestore(DocumentSnapshot)` factory and a `toFirestore()` method. No code generation.

### 3.1 `transaction.dart`

| Dart field | Firestore field | Type notes |
|---|---|---|
| `id` | doc ID (also stored as field) | `String` (UUID string) |
| `userId` | `user_id` | `String` |
| `category` | `category` | `String` |
| `subCategory` | `sub_category` | `String` |
| `date` | `date` | Firestore `Timestamp` → `DateTime` |
| `account` | `account` | `String` |
| `vendor` | `vendor` | `String` |
| `payment` | `payment` | `String` |
| `currency` | `currency` | `String` |
| `notes` | `notes` | `String` |
| `amount` | `amount` | `double` |
| `icon` | `icon` | `String` |

### 3.2 `budget_data.dart`

| Dart field | Firestore field | Type notes |
|---|---|---|
| `name` | `name` | `String` |
| `emoji` | `emoji` | `String?` |
| `type` | `type` | `String` (raw value: `"vendor"`, `"account"`, `"category"`, `"sub_category"`, `"payment"`) |
| `parent` | `parent` | `String?` |

### 3.3 `currency.dart`

| Dart field | Firestore field |
|---|---|
| `name` | `name` |
| `code` | `code` |
| `symbol` | `symbol` |

### 3.4 `dashboard_stats.dart`

Value class, no Firestore mapping needed — computed in-memory.

| Field | Type |
|---|---|
| `totalIncome` | `double` |
| `totalExpense` | `double` |
| `balance` | `double` (income − expense) |
| `categoryBreakdown` | `Map<String, double>` (category → total expense) |

### 3.5 `preference.dart`

| Dart field | Firestore field | Type notes |
|---|---|---|
| `accounts` | `accounts` | `List<BudgetData>?` |
| `categories` | `categories` | `List<BudgetData>?` |
| `subCategories` | `subCategories` | `List<BudgetData>?` |
| `vendors` | `vendors` | `List<BudgetData>?` |
| `payments` | `payments` | `List<BudgetData>?` |
| `defaultCurrency` | `default_currency` | `Currency` |
| `bookmarkedCurrencies` | `frequent_currencies` | `List<String>` |
| `defaultEntries` | `default_entries` | See §3.4.1 |
| `themeId` | `themeId` | `String?` — null defaults to `'amber'` |
| `spendingChartType` | `spendingChartType` | `String?` — null defaults to `'bar'` |

#### 3.4.1 `defaultEntries` encoding

- **Read:** The Swift app writes this field as a flat alternating array: `["vendor", "Fairprice", "category", "Food", ...]`. The Dart `fromFirestore` checks the type:
  - If `List` → walk in steps of 2, build `Map<String, String>` from adjacent pairs
  - If `Map` → cast directly to `Map<String, String>` (handles documents already normalised)
- **Write:** Always write as a standard Firestore Map: `{"vendor": "Fairprice", "category": "Food"}`. Each Flutter write normalises the document to the Map format going forward.

---

## 4. Providers (`lib/core/store/`)

### 4.1 `firestore_providers.dart`

```
authStateProvider               StreamProvider<User?>
  FirebaseAuth.instance.authStateChanges()

transactionsStreamProvider      StreamProvider<List<Transaction>>
  watches authStateProvider for uid (returns [] when unauthenticated)
  Firestore: collection('transactions')
    .where('user_id', isEqualTo: uid)
    .orderBy('date', descending: true)
    .snapshots()
  maps each QuerySnapshot → List<Transaction.fromFirestore()>

preferenceSnapshotProvider      StreamProvider<DocumentSnapshot?>
  watches authStateProvider for uid (returns null stream when unauthenticated)
  Firestore: doc('preference', uid).snapshots()
  emits the raw DocumentSnapshot — metadata preserved for syncStatusProvider

preferenceStreamProvider        Provider<Preference>
  watches preferenceSnapshotProvider
  maps raw DocumentSnapshot → Preference.fromFirestore()
  if snapshot is null or doc does not exist → emits Preference.defaults()
```

### 4.2 `derived_providers.dart`

```
selectedMonthProvider         StateProvider<DateTime>
  defaults to DateTime.now()
  controls the active period filter

filteredTransactionsProvider  Provider<List<Transaction>>
  watches transactionsStreamProvider + selectedMonthProvider
  filters in-memory by year+month of date field
  zero network calls

dashboardStatsProvider        Provider<DashboardStats>
  watches filteredTransactionsProvider
  computes: totalIncome, totalExpense, balance, categoryBreakdown (Map<String,double>)
  zero network calls

syncStatusProvider            Provider<SyncStatus>
  watches preferenceSnapshotProvider (raw snapshot — metadata intact)
  hasPendingWrites == true  → SyncStatus.pending
  isFromCache == true       → SyncStatus.offline
  otherwise                 → SyncStatus.synced
```

`DashboardStats` is a simple value class in `lib/core/models/dashboard_stats.dart`.

### 4.3 Sync status (`lib/core/sync/sync_status.dart`)

```dart
enum SyncStatus { synced, pending, offline }
```

---

## 5. Mutations (`lib/core/store/`)

Standalone `async` functions. No optimistic cache patching — the open stream listener re-emits on confirmed write automatically. Firestore SDK handles offline queuing and retry.

### 5.1 `transaction_mutations.dart`

```
addTransaction(String uid, Transaction t)
  doc('transactions', t.id).set(t.toFirestore())

updateTransaction(String uid, Transaction t)
  doc('transactions', t.id).set(t.toFirestore(), merge: true)

deleteTransaction(String uid, String id)
  doc('transactions', id).delete()
```

### 5.2 `preference_mutations.dart`

All use `merge: true` — only touched fields are written; safe against concurrent writes from other devices.

```
updateTheme(String uid, String themeId)
  doc('preference', uid).set({'themeId': themeId}, merge: true)

updateSpendingChartType(String uid, String chartType)
  doc('preference', uid).set({'spendingChartType': chartType}, merge: true)

updateDefaultCurrency(String uid, Currency c)
  doc('preference', uid).set({'default_currency': c.toFirestore()}, merge: true)

updateDefaultEntries(String uid, Map<String,String> entries)
  doc('preference', uid).set({'default_entries': entries}, merge: true)
  // entries written as Firestore Map (normalised format)
```

---

## 6. Theme Provider Rewire

`lib/core/theme/theme_provider.dart` is updated:

- **Before:** `StateNotifier` with local in-memory state
- **After:** `Provider<AppTheme>` that watches `preferenceStreamProvider`, reads `themeId` (null → `'amber'`), looks up in `themeRegistry`
- `setTheme(String id)` calls `updateTheme(uid, id)` — stream echo updates UI automatically
- No local state duplication

---

## 7. Sync Status Indicator in App Shell

`AppShell` converts from `StatelessWidget` to `ConsumerWidget`. Watches `syncStatusProvider`.

| Status | Indicator |
|---|---|
| `synced` | No indicator (clean UI) |
| `pending` | Amber dot + "Saving…" tooltip |
| `offline` | Grey dot + "Offline" tooltip |

- **Phone layout:** dot appears in `AppBar` trailing area
- **Wide (rail) layout:** dot appears at the bottom of `NavigationRail`

---

## 8. Offline Persistence

`main.dart` — after `Firebase.initializeApp()`, before `runApp()`:

```dart
if (kIsWeb) {
  FirebaseFirestore.instance
      .enablePersistence(const PersistenceSettings(synchronizeTabs: true))
      .catchError((_) {}); // silent — some browsers block IndexedDB
}
// Mobile: persistence is on by default, no code needed
```

---

## 9. File Map

```
lib/
  core/
    models/
      transaction.dart         NEW
      preference.dart          NEW
      budget_data.dart         NEW
      currency.dart            NEW
      dashboard_stats.dart     NEW  (value class, computed in-memory)
    store/
      firestore_providers.dart  NEW
      derived_providers.dart    NEW
      transaction_mutations.dart NEW
      preference_mutations.dart  NEW
    sync/
      sync_status.dart          NEW
    theme/
      theme_provider.dart       MODIFIED (rewire to preferenceStreamProvider)
  app/
    app_shell.dart              MODIFIED (sync status indicator, ConsumerWidget)
  main.dart                     MODIFIED (web offline persistence)
```

---

## 10. Constraints

- Firestore collection names (`transactions`, `preference`) and all field names are owned by the SwiftUI source of truth — do not rename.
- `defaultEntries` read handles both legacy flat-array and normalised Map format; writes always use Map.
- All mutations use `merge: true` — never overwrite the full document.
- `core/` must not import from `features/`.
- No cross-feature imports.
