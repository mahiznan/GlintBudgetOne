# GlintBudget Flutter — Master Implementation Tracker

**Last updated:** 2026-05-24  
**Current phase:** Phase 3 — Feature Parity

---

## Architecture Overview

Single Flutter codebase for iOS, Android, Web. Feature modules + shared core. Riverpod state management. GoRouter adaptive navigation. Real-time Firestore streams (Phase 2+). Material 3 + modular theme registry.

**Spec:** `docs/superpowers/specs/2026-05-23-flutter-migration-design.md`

---

## Phase Status

| Phase | Status | Notes |
|---|---|---|
| Phase 1 — Skeleton | ✅ Complete | |
| Phase 2 — Data Layer | ✅ Complete | |
| Phase 3 — Feature Parity | ✅ Complete | |
| Phase 4 — iOS-only + App Store | ⬜ Not started | |

---

## Module Status

| Module | Status | Location |
|---|---|---|
| Auth (state + notifier) | ✅ | `lib/core/auth/` |
| Theme registry (4 themes) | ✅ | `lib/core/theme/` |
| App shell (adaptive nav) | ✅ | `lib/app/app_shell.dart` |
| App router | ✅ | `lib/app/app_router.dart` |
| Sign-in screen | ✅ | `lib/features/auth/sign_in_screen.dart` |
| Data models | ✅ | `lib/core/models/` |
| Firestore stream providers | ✅ | `lib/core/store/firestore_providers.dart` |
| Derived providers | ✅ | `lib/core/store/derived_providers.dart` |
| Transaction mutations | ✅ | `lib/core/store/transaction_mutations.dart` |
| Preference mutations | ✅ | `lib/core/store/preference_mutations.dart` |
| Sync status | ✅ | `lib/core/sync/sync_status.dart` |
| Dashboard screen | ✅ | `lib/features/dashboard/` |
| Transactions screen | ✅ | `lib/features/transactions/` |
| Settings screen | ✅ | `lib/features/settings/` |
| Add/Edit transaction form | ✅ | `lib/features/add_transaction/` |
| Currency list | ✅ | `lib/core/currencies.dart` |
| Shared transaction tile | ✅ | `lib/core/widgets/transaction_tile.dart` |
| Default entries sub-screen | ✅ | `lib/features/settings/screens/` |
| Currency selection sub-screen | ✅ | `lib/features/settings/screens/` |
| Dashboard widgets | ✅ | `lib/features/dashboard/widgets/` |

---

## Deployment History

| Date | Target | URL | Notes |
|---|---|---|---|
| 2026-05-24 | Web | www.learnerandtutor.com | Phase 1 skeleton live |

---

## Technical Decisions

| Decision | Rationale |
|---|---|
| Riverpod (not Bloc/Provider) | Compile-time safe, excellent for async stream data |
| GoRouter ShellRoute | Native URL routing for web + shared nav shell |
| Firestore streams (not getDocs) | Real-time updates from any channel; SDK handles offline |
| `firebase_options.dart` committed | Public-facing config; not a security risk |
| New iOS bundle ID | Clean App Store slate; no migration from SwiftUI app users |
| Flutter web → www.learnerandtutor.com | React stays at budget.learnerandtutor.com during transition |
| Firebase iOS via SPM | FlutterFire 3.x + Flutter 3.22+ uses Swift Package Manager for Firebase iOS SDKs |
| SDK lower bound >=3.10.0 | Required for dot-shorthand syntax used in generated Flutter code |

---

## Known Issues

_None._

---

## Performance Benchmarks

_To be recorded after Phase 1 deployment._

- [ ] Initial web load time (Lighthouse)
- [ ] App startup time (iOS, Android)
- [ ] Bundle size (web gzipped)
