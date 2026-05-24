import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/store/derived_providers.dart';
import '../../core/store/firestore_providers.dart';
import '../../core/widgets/transaction_tile.dart';
import 'widgets/month_picker_row.dart';
import 'widgets/spending_chart.dart';
import 'widgets/summary_cards_row.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final txns = ref.watch(filteredTransactionsProvider);
    final pref = ref.watch(preferenceStreamProvider);
    final grouped = _groupByDate(txns);
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

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

class _DateHeaderItem extends _Item {
  _DateHeaderItem(this.date);
  final DateTime date;
}

class _TxItem extends _Item {
  _TxItem(this.transaction);
  final Transaction transaction;
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
