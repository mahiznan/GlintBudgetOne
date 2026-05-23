import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/theme_provider.dart';
import 'app_router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final activeTheme = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'GlintBudget',
      theme: activeTheme.light,
      darkTheme: activeTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
