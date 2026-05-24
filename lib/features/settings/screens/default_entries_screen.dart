import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/models/budget_data.dart';
import '../../../core/store/firestore_providers.dart';
import '../../../core/store/preference_mutations.dart';

class DefaultEntriesScreen extends ConsumerWidget {
  const DefaultEntriesScreen({super.key});

  static const _fields = [
    ('Vendor', 'vendor'),
    ('Account', 'account'),
    ('Category', 'category'),
    ('Sub-category', 'sub_category'),
    ('Payment', 'payment'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pref = ref.watch(preferenceStreamProvider);
    final authState = ref.watch(authNotifierProvider);
    final uid = authState is AuthAuthenticated ? authState.user.uid : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Default Entries')),
      body: ListView(
        children: _fields.map((field) {
          final (label, key) = field;
          final current = pref.defaultEntries[key];
          final options = switch (key) {
            'vendor' => pref.vendors,
            'account' => pref.accounts,
            'category' => pref.categories,
            'sub_category' => pref.subCategories,
            'payment' => pref.payments,
            _ => null,
          };

          return ListTile(
            title: Text(label),
            subtitle: Text(current ?? 'None'),
            trailing: const Icon(Icons.chevron_right),
            onTap: uid == null || (options?.isEmpty ?? true)
                ? null
                : () =>
                    _pickValue(context, ref, uid, label, key, current, options!),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickValue(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String label,
    String key,
    String? current,
    List<BudgetData> options,
  ) async {
    final pref = ref.read(preferenceStreamProvider);
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              'Select $label',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('None'),
            leading: current == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(ctx).pop(''),
          ),
          ...options.map((o) => ListTile(
                leading:
                    current == o.name ? const Icon(Icons.check) : null,
                title:
                    Text(o.emoji != null ? '${o.emoji} ${o.name}' : o.name),
                onTap: () => Navigator.of(ctx).pop(o.name),
              )),
        ],
      ),
    );

    if (selected == null) return;
    final updated = Map<String, String>.from(pref.defaultEntries);
    if (selected.isEmpty) {
      updated.remove(key);
    } else {
      updated[key] = selected;
    }
    await updateDefaultEntries(uid, updated);
  }
}
