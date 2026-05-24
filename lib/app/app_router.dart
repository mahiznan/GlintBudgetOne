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
