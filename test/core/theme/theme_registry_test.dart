import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/theme/app_theme.dart';

void main() {
  group('themeRegistry', () {
    test('contains exactly 4 themes', () {
      expect(themeRegistry.length, 4);
    });

    test('contains amber, forest, ocean, lime', () {
      expect(themeRegistry.keys, containsAll(['amber', 'forest', 'ocean', 'lime']));
    });

    test('each theme id matches its registry key', () {
      for (final entry in themeRegistry.entries) {
        expect(entry.value.id, entry.key);
      }
    });

    test('each theme produces valid ThemeData', () {
      for (final theme in themeRegistry.values) {
        expect(theme.light.useMaterial3, isTrue);
        expect(theme.dark.useMaterial3, isTrue);
      }
    });

    test('themeById returns amber for unknown id', () {
      final theme = themeById('nonexistent');
      expect(theme.id, 'amber');
    });

    test('themeById returns correct theme for known id', () {
      expect(themeById('forest').id, 'forest');
      expect(themeById('ocean').id, 'ocean');
    });
  });
}
