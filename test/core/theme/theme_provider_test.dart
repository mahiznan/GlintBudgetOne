import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/currency.dart';
import 'package:glintbudgetone/core/models/preference.dart';
import 'package:glintbudgetone/core/store/firestore_providers.dart';
import 'package:glintbudgetone/core/theme/app_theme.dart';
import 'package:glintbudgetone/core/theme/theme_provider.dart';

void main() {
  group('themeProvider', () {
    test('returns amber theme when themeId is amber', () {
      final container = ProviderContainer(overrides: [
        preferenceStreamProvider.overrideWith(
          (ref) => const Preference(
            themeId: 'amber',
            defaultCurrency: Currency.defaults,
          ),
        ),
      ]);
      addTearDown(container.dispose);

      final theme = container.read(themeProvider);
      expect(theme, isA<AppTheme>());
      expect(theme.id, equals('amber'));
    });

    test('returns forest theme when themeId is forest', () {
      final container = ProviderContainer(overrides: [
        preferenceStreamProvider.overrideWith(
          (ref) => const Preference(
            themeId: 'forest',
            defaultCurrency: Currency.defaults,
          ),
        ),
      ]);
      addTearDown(container.dispose);

      final theme = container.read(themeProvider);
      expect(theme, isA<AppTheme>());
      expect(theme.id, equals('forest'));
    });

    test('falls back to amber when themeId is null', () {
      final container = ProviderContainer(overrides: [
        preferenceStreamProvider.overrideWith(
          (ref) => Preference.defaults(),
        ),
      ]);
      addTearDown(container.dispose);

      final theme = container.read(themeProvider);
      expect(theme, isA<AppTheme>());
      expect(theme.id, equals('amber'));
    });

    test('falls back to amber when themeId is unknown', () {
      final container = ProviderContainer(overrides: [
        preferenceStreamProvider.overrideWith(
          (ref) => const Preference(
            themeId: 'nonexistent',
            defaultCurrency: Currency.defaults,
          ),
        ),
      ]);
      addTearDown(container.dispose);

      final theme = container.read(themeProvider);
      expect(theme, isA<AppTheme>());
      expect(theme.id, equals('amber'));
    });
  });
}
