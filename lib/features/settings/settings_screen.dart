import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../core/store/firestore_providers.dart';
import '../../core/store/preference_mutations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final pref = ref.watch(preferenceStreamProvider);
    final currentTheme = ref.watch(themeProvider);

    final user =
        authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (user != null) _UserProfileCard(user: user),
            const SizedBox(height: 16),
            const _SectionHeader('Theme'),
            _ThemeSelector(
              currentId: currentTheme.id,
              onSelect: (id) {
                if (user == null) return;
                updateTheme(user.uid, id);
              },
            ),
            const SizedBox(height: 16),
            const _SectionHeader('Preferences'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Default Currency'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pref.defaultCurrency.code,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => context.push('/app/settings/currency'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Default Entries'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push('/app/settings/default-entries'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _SectionHeader('Account'),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Sign out'),
                textColor: Theme.of(context).colorScheme.error,
                onTap: () =>
                    ref.read(authNotifierProvider.notifier).signOut(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard({required this.user});
  final AuthUser user;

  String _initials() {
    final name = user.displayName ?? user.email;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              onBackgroundImageError:
                  user.photoUrl != null ? (_, __) {} : null,
              child: user.photoUrl == null
                  ? Text(_initials(),
                      style: const TextStyle(fontSize: 20))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? user.email,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.displayName != null)
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.currentId, required this.onSelect});
  final String currentId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: themeRegistry.entries.map((entry) {
            final isSelected = entry.key == currentId;
            return GestureDetector(
              onTap: () => onSelect(entry.key),
              child: Tooltip(
                message: entry.value.label,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: entry.value.seed,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color:
                                Theme.of(context).colorScheme.onSurface,
                            width: 3,
                          )
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 20)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
