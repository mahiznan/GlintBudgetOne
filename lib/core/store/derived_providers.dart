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
  // Loading state has no metadata — treat as synced to avoid startup flash
  if (snapshot == null) return SyncStatus.synced;
  return syncStatusFromFlags(
    hasPendingWrites: snapshot.metadata.hasPendingWrites,
    isFromCache: snapshot.metadata.isFromCache,
  );
});

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
