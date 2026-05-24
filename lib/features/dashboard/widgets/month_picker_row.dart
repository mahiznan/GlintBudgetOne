import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/store/derived_providers.dart';

class MonthPickerRow extends ConsumerWidget {
  const MonthPickerRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMonthProvider);
    final now = DateTime.now();
    final isCurrentMonth =
        selected.year == now.year && selected.month == now.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              ref.read(selectedMonthProvider.notifier).state =
                  DateTime(selected.year, selected.month - 1);
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(selected),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isCurrentMonth
                ? null
                : () {
                    ref.read(selectedMonthProvider.notifier).state =
                        DateTime(selected.year, selected.month + 1);
                  },
          ),
        ],
      ),
    );
  }
}
