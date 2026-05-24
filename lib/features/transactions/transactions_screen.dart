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
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: TransactionTile(
                            transaction: tx,
                            onTap: () =>
                                context.push('/app/add', extra: tx),
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

class _DateHeaderItem extends _Item {
  _DateHeaderItem(this.date);
  final DateTime date;
}

class _TxItem extends _Item {
  _TxItem(this.transaction);
  final Transaction transaction;
}

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
          setState(() {});
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
