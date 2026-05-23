# GlintBudget Flutter — Phase 3: Feature Parity Design

**Date:** 2026-05-24
**Project:** GlintBudgetOne
**Status:** Approved — ready for implementation planning
**Phase:** 3 — Feature Parity
**Spec:** Extends `2026-05-24-phase2-data-layer-design.md`

---

## 1. Goals

Replace all three placeholder screens with real content. Add a modal Add/Edit transaction form. All screens are read-only until Phase 3; after Phase 3, users can view, add, edit, and delete transactions and manage settings.

- **Dashboard:** month summary cards (income/expense/balance), category spending chart (bar or pie based on preference), month-filtered transaction list, month picker, FAB to add
- **Transactions:** all transactions grouped by date, live text search, swipe-to-delete, tap-to-edit, FAB to add
- **Add/Edit:** full-screen form outside AppShell, handles both create and edit
- **Settings:** user profile card, theme selector, default currency, default entries, sign out
- **Settings sub-screens:** DefaultEntriesScreen, CurrencySelectionScreen

---

## 2. Architecture

Same data layer from Phase 2 (no new Firestore listeners). Two new derived providers added to `derived_providers.dart`: `searchQueryProvider` and `searchedTransactionsProvider`. No new mutations beyond what Phase 2 provides (`addTransaction`, `updateTransaction`, `deleteTransaction`, `updateTheme`, `updateDefaultCurrency`, `updateDefaultEntries`).

Charts: `fl_chart ^0.68.0` — well-maintained, high pub score, required for bar/pie chart rendering.

Transaction ID generation: `FirebaseFirestore.instance.collection('transactions').doc().id` — Firestore auto-ID, no extra package needed.

---

## 3. Navigation / Router Changes

```
/signin                          → SignInScreen (unchanged)
/app/add                         → AddTransactionScreen  ← NEW (outside ShellRoute)
ShellRoute (AppShell)
  /app/dashboard                 → DashboardScreen       ← REPLACE placeholder
  /app/transactions              → TransactionsScreen    ← REPLACE placeholder
  /app/settings                  → SettingsScreen        ← REPLACE placeholder
    /app/settings/default-entries → DefaultEntriesScreen  ← NEW (inside ShellRoute)
    /app/settings/currency        → CurrencySelectionScreen ← NEW (inside ShellRoute)
```

`/app/add` is **outside** the ShellRoute — no nav bar or bottom bar while the form is open.

GoRouter `extra` carries a `Transaction?`:
- `context.push('/app/add')` → create mode (`existing == null`)
- `context.push('/app/add', extra: t)` → edit mode (`existing == t`)

AppShell route matching already uses `startsWith`, so `/app/settings/default-entries` correctly highlights the Settings tab.

---

## 4. New Providers (`lib/core/store/derived_providers.dart` additions)

```
searchQueryProvider       StateProvider<String>
  defaults to ''
  controls live text search in Transactions screen

searchedTransactionsProvider  Provider<List<Transaction>>
  watches transactionsStreamProvider (ALL transactions, not month-filtered)
  watches searchQueryProvider
  if query empty → returns all; otherwise filters on vendor, category,
  subCategory, account, notes (case-insensitive contains)
```

---

## 5. Currencies (`lib/core/currencies.dart`)

Hardcoded list of 30 common currencies. Each is a `Currency` constant.

```dart
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

---

## 6. Shared Widget (`lib/core/widgets/transaction_tile.dart`)

Used by Dashboard and Transactions screens. Accepts a `Transaction` and optional `onTap`.

```
leading:   Text(transaction.icon, fontSize 24)
title:     transaction.subCategory (fallback: category)
subtitle:  transaction.vendor
trailing:  amount (green if >= 0, colorScheme.error if < 0)
           payment method below amount
onTap:     callback supplied by parent
```

Amounts formatted as `+1,234.56` / `-1,234.56` using `NumberFormat` from `intl` (already available transitively, or add `intl ^0.19.0`).

---

## 7. Dashboard Screen (`lib/features/dashboard/dashboard_screen.dart`)

```
ConsumerWidget
│
├── Column
│   ├── MonthPickerRow          ← row with chevron buttons + "Month Year" label
│   ├── SummaryCardsRow         ← 3 cards: Income, Expense, Balance
│   ├── SpendingChart           ← bar or pie (based on spendingChartType pref)
│   └── Expanded ListView       ← filteredTransactionsProvider rows, grouped by date
│
└── FloatingActionButton        → context.push('/app/add')
```

### 7.1 MonthPickerRow
- Watches `selectedMonthProvider`
- Left chevron: `ref.read(selectedMonthProvider.notifier).state = DateTime(year, month - 1)`
- Right chevron: same with `month + 1`; disabled if month == current month
- Label: `DateFormat('MMMM yyyy').format(selectedMonth)`

### 7.2 SummaryCardsRow
- 3 `Card` widgets in a `Row`
- Data from `dashboardStatsProvider`
- Income card: green label
- Expense card: `colorScheme.error` label
- Balance card: green if >= 0, error if < 0

### 7.3 SpendingChart
- Reads `dashboardStatsProvider.categoryBreakdown` (Map<String, double>)
- Reads `preferenceStreamProvider.spendingChartType`
- `'bar'` → `BarChart` from fl_chart, horizontal bars, top 6 categories
- `'pie'` → `PieChart` from fl_chart, sections per category
- Empty state: `Text('No spending this month')` when breakdown is empty

### 7.4 Transaction list
- `filteredTransactionsProvider` (already month-filtered)
- Grouped by date using `_groupByDate` helper
- Each section: date header (`Text('Mon 24 May')`) + `TransactionTile` rows
- `TransactionTile.onTap` → `context.push('/app/add', extra: transaction)`

---

## 8. Transactions Screen (`lib/features/transactions/transactions_screen.dart`)

```
ConsumerWidget
│
├── Column
│   ├── SearchBar               ← TextField, updates searchQueryProvider
│   └── Expanded ListView       ← searchedTransactionsProvider, grouped by date
│       └── Dismissible(key: ValueKey(t.id))
│           confirmDismiss: show dialog
│           onDismissed: deleteTransaction(t.id)
│           child: TransactionTile(onTap: push /app/add with extra)
│
└── FloatingActionButton        → context.push('/app/add')
```

Search bar clears on X button. Debounce: none needed (Riverpod StateProvider is synchronous).

`confirmDismiss`: show `AlertDialog` with "Delete?" confirmation. Returns `true` to confirm, `false` to cancel. This prevents accidental deletes.

Dismiss direction: `DismissDirection.endToStart` (swipe left).

---

## 9. Add/Edit Transaction Screen (`lib/features/add_transaction/add_transaction_screen.dart`)

Full-screen form outside AppShell. `StatefulWidget` (form state is local).

```
Scaffold
├── AppBar
│   title: 'Add Transaction' or 'Edit Transaction'
│   leading: IconButton(close/cancel) → Navigator.pop
│   actions: [TextButton('Save', onPressed: _save)]
│
└── SingleChildScrollView
    └── Padding
        └── Column
            ├── _AmountRow          ← sign toggle (+ / -) + TextField (numeric)
            ├── _DateField          ← tap to open showDatePicker
            ├── _IconField          ← TextField for emoji (maxLength: 2)
            ├── _DropdownField('Category', categories)
            ├── _DropdownField('Sub-category', subCats filtered by category)
            ├── _DropdownField('Vendor', vendors)
            ├── _DropdownField('Account', accounts)
            ├── _DropdownField('Payment', payments)
            ├── _DropdownField('Currency', kCurrencies mapped to strings)
            └── TextField('Notes', multiline)
```

### 9.1 Amount row
- Toggle button: `+` (income, amount >= 0) or `-` (expense, amount < 0)
- TextField: numeric, no sign — stored internally as absolute value
- On save: apply sign based on toggle

### 9.2 Dropdown fields
- Options come from `preferenceStreamProvider` (accounts, categories, etc.)
- If preference list is empty for a field, show freeform `TextField` fallback
- Sub-category list filtered client-side: `prefs.subCategories?.where((s) => s.parent == selectedCategory)`
- Display format: `emoji + ' ' + name` if emoji is non-null

### 9.3 Save logic
```
_save():
  validate: amount != 0
  if creating:
    id = FirebaseFirestore.instance.collection('transactions').doc().id
    uid = ref.read(authNotifierProvider).user.uid
  t = Transaction(id, uid, category, subCategory, date, account,
                  vendor, payment, currency.code, notes, signedAmount, icon)
  if creating: await addTransaction(t)
  else: await updateTransaction(t)
  if mounted: Navigator.pop(context)
```

### 9.4 Pre-fill from defaults (create mode)
When `existing == null`, pre-fill from `preferenceStreamProvider.defaultEntries`:
- `defaultEntries['vendor']` → vendor field
- `defaultEntries['account']` → account field
- `defaultEntries['category']` → category field
- `defaultEntries['sub_category']` → subCategory field
- `defaultEntries['payment']` → payment field
- `defaultCurrency` → currency field

---

## 10. Settings Screen (`lib/features/settings/settings_screen.dart`)

```
ConsumerWidget
│
└── ListView
    ├── _UserProfileCard        ← avatar + name + email
    ├── SectionHeader('Appearance')
    ├── _ThemeSelector          ← 4 tappable color swatches
    ├── SectionHeader('Preferences')
    ├── ListTile('Default Currency', trailing: currency code)
    │     onTap → context.push('/app/settings/currency')
    ├── ListTile('Default Entries', trailing: Icon(chevron_right))
    │     onTap → context.push('/app/settings/default-entries')
    ├── SectionHeader('Account')
    └── ListTile('Sign out', textColor: colorScheme.error)
          onTap → ref.read(authNotifierProvider.notifier).signOut()
```

### 10.1 UserProfileCard
- `CachedNetworkImage` is not available — use `Image.network` with `errorBuilder`
- If `user.photoUrl` non-null: `CircleAvatar(backgroundImage: NetworkImage(url))`
- Fallback: `CircleAvatar(child: Text(initials))` where initials = first char of displayName or email
- Below avatar: `Text(user.displayName ?? user.email)` + `Text(user.email)`

### 10.2 ThemeSelector
- Row of 4 `InkWell`-wrapped circles (48px diameter), color = each theme's `.seed`
- Selected theme: border ring using `BoxDecoration(border: Border.all(...))`
- Current themeId from `preferenceStreamProvider.themeId ?? 'amber'`
- On tap: `updateTheme(uid, themeId)`

---

## 11. Default Entries Sub-Screen (`lib/features/settings/screens/default_entries_screen.dart`)

```
ConsumerWidget → ListView of 5 ListTiles
  each tile: field name + current value (or 'None')
  onTap → showModalBottomSheet with list of options
  on selection → updateDefaultEntries(uid, {...existing, fieldKey: newValue})
```

Fields:
| UI Label | Map key | Options from |
|---|---|---|
| Vendor | `vendor` | `pref.vendors` |
| Account | `account` | `pref.accounts` |
| Category | `category` | `pref.categories` |
| Sub-category | `sub_category` | `pref.subCategories` |
| Payment | `payment` | `pref.payments` |

---

## 12. Currency Selection Sub-Screen (`lib/features/settings/screens/currency_selection_screen.dart`)

```
ConsumerWidget → ListView of kCurrencies
  each row: symbol + code + name
  currently selected: checkmark icon
  onTap → updateDefaultCurrency(uid, currency) → Navigator.pop
```

---

## 13. Constraints

- `core/` must not import from `features/`. `TransactionTile` lives in `core/widgets/`.
- No cross-feature imports (dashboard ↔ transactions ↔ add_transaction ↔ settings must not import each other).
- No `getDocs`/`getDoc` anywhere — all reads from Riverpod providers.
- All Firestore field names remain as-is (owned by iOS app).
- `fl_chart` import only in files that render charts (`spending_chart.dart`).
- `intl` package: check if already transitive dep; if not, add `intl ^0.19.0`.

---

## 14. File Map

```
lib/
  core/
    currencies.dart              NEW — kCurrencies constant list
    widgets/
      transaction_tile.dart      NEW — shared tile widget
  features/
    dashboard/
      dashboard_screen.dart      REPLACE placeholder
      widgets/
        month_picker_row.dart    NEW
        summary_cards_row.dart   NEW
        spending_chart.dart      NEW (uses fl_chart)
    transactions/
      transactions_screen.dart   REPLACE placeholder
    add_transaction/
      add_transaction_screen.dart NEW
    settings/
      settings_screen.dart       REPLACE placeholder
      screens/
        default_entries_screen.dart  NEW
        currency_selection_screen.dart NEW
  app/
    app_router.dart              MODIFY — /app/add + settings sub-routes
  core/store/
    derived_providers.dart       MODIFY — searchQueryProvider + searchedTransactionsProvider
pubspec.yaml                     MODIFY — fl_chart, intl (if not transitive)
```
