# GlintBudget Flutter Migration — Design Spec

**Date:** 2026-05-23  
**Project:** GlintBudgetOne  
**Status:** Approved — ready for implementation planning

---

## 1. Overview

GlintBudget is a personal expense tracker. This spec covers the migration from two separate codebases (SwiftUI iOS app + React web app) to a single Flutter codebase targeting iOS, Android, and Web.

### Strategic decisions

| Dimension | Decision |
|---|---|
| iOS SwiftUI app | Replaced by Flutter (new App Store bundle ID, clean slate) |
| React web app | Stays live at `budget.learnerandtutor.com` during migration; Flutter web takes over at `www.learnerandtutor.com`, then React is retired |
| Flutter web domain | `www.learnerandtutor.com` |
| State management | Riverpod |
| Design language | Material 3 + GlintBudget brand tokens (amber `#f59e0b`) |
| Navigation | Adaptive — `NavigationBar` (phone), `NavigationRail` (tablet/web) |
| MVP scope | Web app feature parity first, then iOS-only features (Reports, Trackers) |
| Firebase project | Same existing Firebase project — no schema changes |

---

## 2. Project Structure

Feature modules + shared core. Each feature is self-contained and depends only on `core/`.

```
glintbudgetone/
└── lib/
    ├── core/
    │   ├── firebase/            # Firebase client (lazy, single instance)
    │   ├── auth/                # AuthNotifier, auth state, Google sign-in
    │   ├── models/              # Transaction, Preference, BudgetData, Currency
    │   ├── sync/                # SyncStatus (derived from Firestore metadata)
    │   ├── store/               # AppStore (Riverpod providers — stream-backed)
    │   └── theme/
    │       ├── app_theme.dart   # AppTheme interface + ThemeRegistry + ThemeProvider
    │       └── themes/
    │           ├── amber_theme.dart    # default (#f59e0b)
    │           ├── forest_theme.dart
    │           ├── ocean_theme.dart
    │           ├── lime_theme.dart
    │           └── # …future themes added here only
    ├── features/
    │   ├── dashboard/           # providers + screens + widgets
    │   ├── transactions/        # providers + screens + widgets
    │   └── settings/            # providers + screens + widgets
    ├── app/                     # AppRouter, AppShell, adaptive nav scaffold
    └── main.dart                # Firebase.initializeApp() + ProviderScope + runApp
```

### Dependency rules

- `features/*` may depend on `core/*` only.
- `app/` may depend on `features/*` and `core/*`.
- `core/` must not depend on `features/*`.
- No cross-feature imports (`features/a` must not import `features/b`).
- Future features (Reports, Trackers) are added as new folders under `features/` — no existing code changes.

---

## 3. Modular Theme System

Adding a theme requires one new file and one line in the registry. No other code changes.

```dart
// core/theme/app_theme.dart

abstract class AppTheme {
  String get id;
  String get label;
  Color get seed;
  ThemeData get light;
  ThemeData get dark;
}

final themeRegistry = <String, AppTheme>{
  'amber':  AmberTheme(),
  'forest': ForestTheme(),
  'ocean':  OceanTheme(),
  'lime':   LimeTheme(),
  // add a new theme: one file under themes/ + one line here
};
```

- Settings screen iterates `themeRegistry.values` — no screen changes needed when adding themes.
- Active theme ID persisted in Firestore `preference/{uid}.themeId` — same field as web app.
- `ThemeProvider` (Riverpod `StateNotifierProvider`) reads the active ID, looks it up in the registry, and supplies `ThemeData` to `MaterialApp`.

---

## 4. Data Models

Dart models mirror the existing Firestore schema exactly. No Firestore schema changes.

```dart
// core/models/transaction.dart
class Transaction {
  final String id, userId, category, subCategory;
  final String account, vendor, payment, currency, notes, icon;
  final double amount;
  final DateTime date;
}

// core/models/preference.dart
class Preference {
  final String id;
  final List<BudgetData> accounts, categories, subCategories, vendors, payments;
  final Currency defaultCurrency;
  final List<String> bookmarkedCurrencies;
  final Map<String, String>? defaultEntries;
  final String? themeId;
  final String? spendingChartType;
}

// core/models/budget_data.dart
class BudgetData {
  final String name, type;
  final String? emoji, parent;
}

// core/models/currency.dart
class Currency {
  final String name, code, symbol;
}
```

**Firestore field mapping** follows the same rules as the web app:
- `sub_category` (Firestore) ↔ `subCategory` (Dart)
- `date` stored as Firestore `Timestamp`
- `default_currency`, `frequent_currencies`, `default_entries` field names unchanged
- `default_entries` encoded as flat alternating array by Swift Codable — same decode logic applies in Dart

---

## 5. Real-Time Data Architecture (Riverpod Provider Graph)

Firebase is initialized once in `main.dart`. `FirebaseFirestore.instance` is used directly — no wrapper providers.

### Provider graph

```
Firebase.initializeApp()  [main.dart]
        ↓
authStateProvider         [StreamProvider]
  FirebaseAuth.instance.authStateChanges()
        ↓ uid available → open listeners
        ↓
transactionsStreamProvider   [StreamProvider<List<Transaction>>]
  collection('transactions').where('user_id', uid).snapshots()

preferenceStreamProvider     [StreamProvider<Preference>]
  doc('preference', uid).snapshots()
        ↓ streams emit on any change (this device, iOS app, another browser tab)
        ↓
filteredTransactionsProvider  [Provider — computed, no network]
  period filter applied in-memory from transactionsStreamProvider

dashboardStatsProvider        [Provider — computed, no network]
  totals, chart data, category breakdown — pure computation

syncStatusProvider            [Provider — computed from snapshot.metadata]
  hasPendingWrites / isFromCache → SyncStatus enum
        ↓
UI widgets (ConsumerWidget)
  DashboardScreen, TransactionListScreen, TransactionFormScreen, SettingsScreen
```

### Key principle

- UI **never reads from Firestore directly**. All reads come from providers.
- Period navigation, search, and filters are computed from the in-memory stream — zero network calls after login.
- **2 stream listeners opened per session** (transactions + preference), both opened once on login and held open. Changes from any source propagate automatically. Compare to the React web app which fires a new `getDocs()` call on every period navigation.

---

## 6. Mutation Flow (Optimistic Updates)

```
User taps Save
  → Step A: optimistic update to local stream cache (UI reflects instantly)
  → Step B: setDoc / updateDoc / deleteDoc to Firestore
             ↳ if offline → Firestore SDK queues locally, writes on reconnect
  → Step C: stream echo — Firestore listener receives confirmed write → stream re-emits → UI stays consistent
```

No custom sync queue or retry engine is needed. The Firestore SDK's built-in offline persistence handles queuing and exponential back-off retry natively.

---

## 7. Sync Status

Derived from `DocumentSnapshot.metadata` — no custom tracking needed.

| Status | Condition |
|---|---|
| 🔵 Synced | `!hasPendingWrites && !isFromCache` |
| 🟡 Pending | `hasPendingWrites == true` |
| ⚡ Offline | `isFromCache == true` |

Sync status indicator is displayed in the app shell (TopBar / nav area) so users always know the state of their data.

---

## 8. Adaptive Navigation

```dart
// app/app_shell.dart
LayoutBuilder(builder: (context, constraints) {
  if (constraints.maxWidth < 600) {
    return Scaffold(
      body: currentFeatureScreen,
      bottomNavigationBar: NavigationBar(...),  // phone
    );
  }
  return Scaffold(
    body: Row(children: [
      NavigationRail(...),                       // tablet / web
      Expanded(child: currentFeatureScreen),
    ]),
  );
})
```

Three top-level destinations: **Dashboard**, **Transactions**, **Settings**.  
Future destinations (Reports, Trackers) are added to the destinations list — no structural changes.

---

## 9. CI/CD Pipeline

### Workflow 1 — PR Validation (every PR to main)

```
flutter analyze → flutter test → flutter build web --dry-run → ✓ merge allowed
```

### Workflow 2 — Deploy Web (push to main)

```
flutter build web --release --web-renderer canvaskit --dart-define=ENV=prod
  → inject .htaccess (SPA fallback + cache headers + compression)
  → FTP upload build/web/ → cPanel via SamKirkland/FTP-Deploy-Action
  → live at www.learnerandtutor.com
```

### Workflow 3 — Mobile Release (manual trigger / version tag)

| Platform | Command | Output | Distribution |
|---|---|---|---|
| Android | `flutter build appbundle --release` | `.aab` signed with keystore | Manual Play Console upload initially |
| iOS | `flutter build ipa --release` (macOS runner) | `.ipa` signed with cert + profile | TestFlight initially |

### Domain split

| App | Domain | Repo | Status |
|---|---|---|---|
| React web | `budget.learnerandtutor.com` | GlintBudgetUI | Unchanged during migration |
| Flutter web | `www.learnerandtutor.com` | GlintBudgetOne | New deployment |

### GitHub Secrets — GlintBudgetOne repo

**Reuse from GlintBudgetUI:**
- `FTP_HOST`, `FTP_USERNAME`, `FTP_PASSWORD`
- `FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_PROJECT_ID`
- `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_STORAGE_BUCKET`

**New secrets to add:**
- `FTP_SERVER_DIR_FLUTTER` (e.g. `/www.learnerandtutor.com/`)
- `ANDROID_KEYSTORE`, `ANDROID_KEYSTORE_PASSWORD`
- `IOS_CERTIFICATE`, `IOS_PROVISIONING_PROFILE`

---

## 10. Local Development Setup

### Prerequisites (install once)

| Tool | Purpose |
|---|---|
| Flutter SDK (stable) | Build and run |
| Xcode (latest stable) | iOS builds |
| CocoaPods | iOS native dependencies |
| Android Studio + SDK | Android builds |
| Firebase CLI (`npm install -g firebase-tools`) | Firebase project access |
| FlutterFire CLI (`dart pub global activate flutterfire_cli`) | Generate platform config |

### One-time setup after cloning

```bash
# 1. Install Dart/Flutter dependencies
flutter pub get

# 2. Generate Firebase config for all three platforms
firebase login
flutterfire configure --project=<firebase-project-id>
# Generates:
#   lib/firebase_options.dart
#   ios/Runner/GoogleService-Info.plist
#   android/app/google-services.json
#   (web config injected into web/index.html)

# 3. Install iOS native dependencies
cd ios && pod install && cd ..
```

> Re-run `pod install` any time `flutter pub get` adds a package with native iOS code.

### Files NOT committed to git

```
ios/Runner/GoogleService-Info.plist   # re-generated via flutterfire configure
android/app/google-services.json     # re-generated via flutterfire configure
lib/firebase_options.dart            # re-generated via flutterfire configure
```

Add these to `.gitignore`. CI/CD injects Firebase config via `--dart-define` secrets.

### Running each target locally

| Target | Command | Notes |
|---|---|---|
| iOS (terminal) | `flutter run -d ios` | Picks first available simulator |
| iOS (Xcode) | Open `ios/Runner.xcworkspace` → set signing team → ▶ Run | **Always open `.xcworkspace`, not `.xcodeproj`** |
| Android | `flutter run -d android` | Start emulator first in Android Studio |
| Web | `flutter run -d chrome` | Hot restart supported |
| All at once | `flutter run -d all` | Launches all available targets |

### Xcode signing setup (one-time)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** target → **Signing & Capabilities**
3. Set your Apple Development Team
4. Set Bundle ID (new ID, e.g. `com.yourname.glintbudget`)
5. Select simulator or connected device → ▶ Run

---

## 11. Phased Feature Rollout

### Phase 1 — Skeleton

**Goal:** All three targets compile, deploy, and authenticate. Pipeline proven.

- Flutter project scaffold in `GlintBudgetOne`
- Firebase + FlutterFire configured for iOS, Android, Web
- Google Sign-In working on all three platforms
- Adaptive nav shell (placeholder screens)
- Modular theme registry (4 themes wired)
- GitHub Actions: Workflow 1 (validate) + Workflow 2 (web deploy)
- Live at `www.learnerandtutor.com`
- `MASTER_IMPLEMENTATION_TRACKER.md` + `GLOBAL_ENGINEERING_RULES.md` created

### Phase 2 — Data Layer

**Goal:** Real-time data flows. UI reflects changes from any device instantly.

- Firestore stream providers (`transactionsStreamProvider`, `preferenceStreamProvider`)
- Optimistic mutations (add / edit / delete transaction, update preference)
- Sync status indicator in app shell
- Derived providers: filtered transactions, dashboard stats
- Offline persistence enabled (Firestore SDK)

### Phase 3 — Feature Parity

**Goal:** Every screen the React web app has. Ready for daily use on all platforms.

**Dashboard:** Hero stats row, spending chart (bar/line toggle), category breakdown, income/expense donut, daily transactions widget, quick stats, period navigation

**Transactions:** Transaction list with search, date range filter, add/edit/delete with confirm dialog, category & vendor picker, amount input, type toggle (income/expense)

**Settings:** Appearance (theme picker — iterates registry), currency + bookmarks, budget data management, default entries, sub-categories

Android CI workflow added. Manual Play Store upload.

### Phase 4 — iOS-Only Features + App Store

**Goal:** Full iOS app parity. Submit to App Store. Retire SwiftUI app and React web app.

- Reports feature (`features/reports/`)
- Trackers feature (`features/trackers/`)
- iOS CI workflow (macOS GitHub Actions runner)
- TestFlight distribution
- App Store submission (new bundle ID)
- SwiftUI app retired
- `budget.learnerandtutor.com` redirected to `www.learnerandtutor.com`
- `GlintBudgetUI` repo archived

---

## 12. Mandatory Documents

Two documents must be created in Phase 1 and kept updated throughout:

**`MASTER_IMPLEMENTATION_TRACKER.md`** — single source of truth for project status: architecture overview, module list, implementation status, completed/pending work, technical decisions, file references, PR references, deployment history, performance benchmarks, known issues, rollback notes.

**`GLOBAL_ENGINEERING_RULES.md`** — persistent engineering governance: performance-first principle, dependency minimization rule, module isolation rule, testing requirements, sync principles, offline-first requirements, code quality standards, Firestore optimization rules, naming conventions, prohibited patterns, anti-patterns.

---

## 13. Key Constraints (Do Not Violate)

- Firestore schema is **read-only from this repo** — field names are owned by the iOS SwiftUI app source of truth at `/Users/rajeshkumar/workspace/GlintBudget`.
- Firebase web config (`GoogleService-Info.plist`, `google-services.json`, `firebase_options.dart`) must not be committed to git.
- The existing `.htaccess` cache strategy must be preserved on the Flutter web deployment: hashed assets get `max-age=31536000, immutable`; `index.html` gets `no-cache, must-revalidate`.
- `core/` must never import from `features/`.
- Cross-feature imports are forbidden.
- Every new theme is a single file under `core/theme/themes/` + one line in `themeRegistry` — no other files change.
