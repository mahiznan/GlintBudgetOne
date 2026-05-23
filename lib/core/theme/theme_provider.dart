import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';

final themeProvider =
    StateNotifierProvider<ThemeNotifier, AppTheme>((ref) => ThemeNotifier());

class ThemeNotifier extends StateNotifier<AppTheme> {
  ThemeNotifier() : super(themeRegistry['amber']!);

  void setTheme(String id) => state = themeById(id);
}
