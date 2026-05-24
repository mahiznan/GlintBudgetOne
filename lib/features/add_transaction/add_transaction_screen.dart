import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../core/currencies.dart';
import '../../core/models/budget_data.dart';
import '../../core/models/currency.dart';
import '../../core/models/preference.dart';
import '../../core/models/transaction.dart';
import '../../core/store/firestore_providers.dart';
import '../../core/store/transaction_mutations.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.existing});
  final Transaction? existing;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _iconController = TextEditingController();

  bool _isExpense = true;
  DateTime _date = DateTime.now();
  String? _category;
  String? _subCategory;
  String? _vendor;
  String? _account;
  String? _payment;
  Currency? _currency;
  bool _saving = false;
  bool _defaultsFilled = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    if (t != null) {
      _amountController.text = t.amount.abs().toStringAsFixed(2);
      _isExpense = t.amount < 0;
      _date = t.date;
      _category = t.category.isNotEmpty ? t.category : null;
      _subCategory = t.subCategory.isNotEmpty ? t.subCategory : null;
      _vendor = t.vendor.isNotEmpty ? t.vendor : null;
      _account = t.account.isNotEmpty ? t.account : null;
      _payment = t.payment.isNotEmpty ? t.payment : null;
      _iconController.text = t.icon;
      _notesController.text = t.notes;
      _currency = kCurrencies.firstWhere(
        (c) => c.code == t.currency,
        orElse: () => Currency.defaults,
      );
      _defaultsFilled = true;
    }
  }

  void _applyDefaults(Preference pref) {
    if (_defaultsFilled || widget.existing != null) return;
    _defaultsFilled = true;
    final d = pref.defaultEntries;
    _category ??= d['category'];
    _subCategory ??= d['sub_category'];
    _vendor ??= d['vendor'];
    _account ??= d['account'];
    _payment ??= d['payment'];
    _currency ??= pref.defaultCurrency;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amountText = _amountController.text.trim();
    final absAmount = double.tryParse(amountText);
    if (absAmount == null || absAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount greater than 0')),
      );
      return;
    }
    final authState = ref.read(authNotifierProvider);
    if (authState is! AuthAuthenticated) return;
    final uid = authState.user.uid;
    final signedAmount = _isExpense ? -absAmount : absAmount;
    final id = widget.existing?.id ??
        FirebaseFirestore.instance.collection('transactions').doc().id;
    final t = Transaction(
      id: id,
      userId: uid,
      category: _category ?? '',
      subCategory: _subCategory ?? '',
      date: _date,
      account: _account ?? '',
      vendor: _vendor ?? '',
      payment: _payment ?? '',
      currency: (_currency ?? Currency.defaults).code,
      notes: _notesController.text.trim(),
      amount: signedAmount,
      icon: _iconController.text.trim(),
    );
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await addTransaction(t);
      } else {
        await updateTransaction(t);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pref = ref.watch(preferenceStreamProvider);
    _applyDefaults(pref);

    final subCats = pref.subCategories
            ?.where((s) => _category == null || s.parent == _category)
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
            widget.existing == null ? 'Add Transaction' : 'Edit Transaction'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Expense')),
                    ButtonSegment(value: false, label: Text('Income')),
                  ],
                  selected: {_isExpense},
                  onSelectionChanged: (s) =>
                      setState(() => _isExpense = s.first),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(_formatDate(_date)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const Divider(),
            const SizedBox(height: 8),
            TextField(
              controller: _iconController,
              maxLength: 2,
              decoration: const InputDecoration(
                labelText: 'Icon (emoji)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            _DropdownField(
              label: 'Category',
              value: _category,
              options: pref.categories ?? [],
              onChanged: (v) => setState(() {
                _category = v;
                _subCategory = null;
              }),
            ),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'Sub-category',
              value: _subCategory,
              options: subCats,
              onChanged: (v) => setState(() => _subCategory = v),
            ),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'Vendor',
              value: _vendor,
              options: pref.vendors ?? [],
              onChanged: (v) => setState(() => _vendor = v),
            ),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'Account',
              value: _account,
              options: pref.accounts ?? [],
              onChanged: (v) => setState(() => _account = v),
            ),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'Payment',
              value: _payment,
              options: pref.payments ?? [],
              onChanged: (v) => setState(() => _payment = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Currency>(
              initialValue: _currency ?? pref.defaultCurrency,
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              items: kCurrencies
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.code}  ${c.symbol}'),
                      ))
                  .toList(),
              onChanged: (c) => setState(() => _currency = c),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<BudgetData> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return TextField(
        controller: TextEditingController(text: value),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      );
    }
    final validValue = options.any((o) => o.name == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: validValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('None')),
        ...options.map((o) => DropdownMenuItem(
              value: o.name,
              child: Text(
                o.emoji != null ? '${o.emoji} ${o.name}' : o.name,
              ),
            )),
      ],
      onChanged: onChanged,
    );
  }
}
