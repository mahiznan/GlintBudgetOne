# GlintBudget Flutter — Global Engineering Rules

These rules apply to all contributors and all AI sessions on this project.

---

## 1. Performance First

Before implementing anything, analyze:
- Widget rebuild frequency (use `const` constructors wherever possible)
- Firestore read/write count (target: 2 stream listeners per session)
- Memory allocation patterns
- App startup impact

Never introduce an abstraction or dependency that increases rebuild frequency, Firestore costs, or startup latency without documented justification.

---

## 2. Firestore Rules

- **Never call `getDocs()` or `getDoc()` in UI code.** All data comes from Riverpod providers backed by Firestore streams.
- **Never read Firestore on navigation or filter changes.** Filtering is done in-memory from the stream cache.
- **Field names are owned by the iOS SwiftUI app** at `/Users/rajeshkumar/workspace/GlintBudget`. Never change them from this repo.
- Mutations: `setDoc`, `updateDoc`, `deleteDoc` — always optimistic (update local state first).

---

## 3. Module Isolation

- `features/*` may import from `core/*` only.
- `core/*` must never import from `features/*`.
- `features/a` must never import from `features/b`.
- `app/` may import from both `core/` and `features/`.
- Violations of these rules are bugs, not style issues.

---

## 4. Theme System

- Adding a theme = one new file in `lib/core/theme/themes/` + one line in `themeRegistry`.
- No other files change when adding a theme.
- Never hardcode colors in feature code — always use `Theme.of(context).colorScheme`.

---

## 5. Dependency Management

- Never add a dependency without checking: maintenance status, pub score, bundle size impact.
- Always prefer Flutter SDK / Dart core capabilities first.
- Remove unused dependencies immediately when removing features.
- Keep `pubspec.yaml` lean.

---

## 6. Testing Requirements

- Every new class with business logic gets a unit test before implementation (TDD).
- Every new screen gets a smoke widget test.
- Run `flutter test` before every commit.
- Run `flutter analyze --fatal-infos` before every commit.
- Tests live in `test/` mirroring the `lib/` structure.

---

## 7. Git & CI Rules

- Commit messages: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `perf:` prefixes.
- Never commit: `GoogleService-Info.plist`, `google-services.json`.
- `firebase_options.dart` IS committed (public-facing config).
- Every push to `main` triggers a web deploy — keep `main` green.
- Feature branches → PR → review → merge.

---

## 8. Code Quality Standards

- No `print()` in production code — use `debugPrint()` for dev-only logging.
- All `Widget build()` methods must be pure (no side effects).
- Use `const` constructors wherever possible.
- `ConsumerWidget` / `ConsumerStatefulWidget` for Riverpod; plain `StatelessWidget` / `StatefulWidget` for pure UI with no providers.
- No `dynamic` types without justification.

---

## 9. Prohibited Patterns

- No `getDocs()` or `getDoc()` in UI or feature code
- No cross-feature imports
- No `core/` importing from `features/`
- No hardcoded color hex values in feature code
- No `setState()` for data that belongs in a Riverpod provider
- No skipping tests to ship faster
- No adding themes anywhere except `lib/core/theme/themes/`

---

## 10. Store Submission Checklist (before Phase 4)

- [ ] Startup time < 2s on mid-range device
- [ ] No memory leaks (use Flutter DevTools Memory tab)
- [ ] Safe area insets respected on all screens
- [ ] Keyboard does not cover input fields
- [ ] All text scales correctly with system font size
- [ ] Offline mode shows correct sync status indicators
- [ ] Privacy policy URL configured in both stores
- [ ] Crash reporting integrated and tested
