import 'package:flutter/material.dart';
import '../../../core/models/dashboard_stats.dart';

class SummaryCardsRow extends StatelessWidget {
  const SummaryCardsRow({super.key, required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _SummaryCard(
            label: 'Income',
            value: stats.totalIncome,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Expense',
            value: stats.totalExpense,
            color: colorScheme.error,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Balance',
            value: stats.balance,
            color: stats.balance >= 0 ? Colors.green.shade700 : colorScheme.error,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(
                value.toStringAsFixed(2),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
