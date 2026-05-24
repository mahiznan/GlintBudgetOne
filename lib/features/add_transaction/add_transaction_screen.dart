import 'package:flutter/material.dart';
import '../../core/models/transaction.dart';

class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({super.key, this.existing});
  final Transaction? existing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(existing == null ? 'Add Transaction' : 'Edit Transaction'),
      ),
      body: const Center(child: Text('Form coming soon')),
    );
  }
}
