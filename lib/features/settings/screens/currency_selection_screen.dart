import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/currencies.dart';
import '../../../core/store/firestore_providers.dart';
import '../../../core/store/preference_mutations.dart';

class CurrencySelectionScreen extends ConsumerWidget {
  const CurrencySelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pref = ref.watch(preferenceStreamProvider);
    final authState = ref.watch(authNotifierProvider);
    final uid = authState is AuthAuthenticated ? authState.user.uid : null;
    final currentCode = pref.defaultCurrency.code;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Currency')),
      body: ListView.builder(
        itemCount: kCurrencies.length,
        itemBuilder: (context, index) {
          final currency = kCurrencies[index];
          final isSelected = currency.code == currentCode;
          return ListTile(
            leading: Text(
              currency.symbol,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            title: Text(currency.code),
            subtitle: Text(currency.name),
            trailing: isSelected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: uid == null
                ? null
                : () async {
                    await updateDefaultCurrency(uid, currency);
                    if (context.mounted) Navigator.of(context).pop();
                  },
          );
        },
      ),
    );
  }
}
