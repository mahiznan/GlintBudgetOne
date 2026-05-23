// lib/core/theme/theme_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../store/firestore_providers.dart';
import 'app_theme.dart';

/// Active theme, derived from the user's Firestore preference.
/// Defaults to amber when preference is loading or themeId is absent.
final themeProvider = Provider<AppTheme>((ref) {
  final pref = ref.watch(preferenceStreamProvider);
  return themeById(pref.themeId ?? 'amber');
});
