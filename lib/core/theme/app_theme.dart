import 'package:flutter/material.dart';
import 'themes/amber_theme.dart';
import 'themes/forest_theme.dart';
import 'themes/lime_theme.dart';
import 'themes/ocean_theme.dart';

export 'themes/amber_theme.dart';
export 'themes/forest_theme.dart';
export 'themes/lime_theme.dart';
export 'themes/ocean_theme.dart';

abstract class AppTheme {
  String get id;
  String get label;
  Color get seed;

  ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.light,
      );

  ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
      );
}

final Map<String, AppTheme> themeRegistry = {
  'amber':  AmberTheme(),
  'forest': ForestTheme(),
  'ocean':  OceanTheme(),
  'lime':   LimeTheme(),
};

AppTheme themeById(String id) => themeRegistry[id] ?? themeRegistry['amber']!;
