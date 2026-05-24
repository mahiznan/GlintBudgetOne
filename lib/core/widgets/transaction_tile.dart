import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  final Transaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.amount < 0;
    final absAmount = transaction.amount.abs().toStringAsFixed(2);
    final amountText = isExpense ? '-$absAmount' : '+$absAmount';
    final amountColor = isExpense
        ? Theme.of(context).colorScheme.error
        : Colors.green.shade700;
    final title = transaction.subCategory.isNotEmpty
        ? transaction.subCategory
        : transaction.category;

    return ListTile(
      leading: Text(
        transaction.icon.isNotEmpty ? transaction.icon : '💰',
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(title),
      subtitle: Text(transaction.vendor),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amountText,
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            transaction.payment,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
