import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'budget_data.dart';
import 'currency.dart';

@immutable
class Preference {
  const Preference({
    this.accounts,
    this.categories,
    this.subCategories,
    this.vendors,
    this.payments,
    required this.defaultCurrency,
    this.bookmarkedCurrencies = const [],
    this.defaultEntries = const {},
    this.themeId,
    this.spendingChartType,
  });

  final List<BudgetData>? accounts;
  final List<BudgetData>? categories;
  final List<BudgetData>? subCategories;
  final List<BudgetData>? vendors;
  final List<BudgetData>? payments;
  final Currency defaultCurrency;
  final List<String> bookmarkedCurrencies;
  final Map<String, String> defaultEntries;
  final String? themeId;
  final String? spendingChartType;

  static Preference defaults() =>
      const Preference(defaultCurrency: Currency.defaults);

  factory Preference.fromFirestore(DocumentSnapshot doc) =>
      Preference.fromMap(doc.data() as Map<String, dynamic>? ?? {});

  factory Preference.fromMap(Map<String, dynamic> data) {
    final rawCurrency = data['default_currency'];
    final currency = rawCurrency is Map<String, dynamic>
        ? Currency.fromMap(rawCurrency)
        : Currency.defaults;

    return Preference(
      accounts: _budgetDataList(data['accounts']),
      categories: _budgetDataList(data['categories']),
      subCategories: _budgetDataList(data['subCategories']),
      vendors: _budgetDataList(data['vendors']),
      payments: _budgetDataList(data['payments']),
      defaultCurrency: currency,
      bookmarkedCurrencies: (data['frequent_currencies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      defaultEntries: _decodeDefaultEntries(data['default_entries']),
      themeId: data['themeId'] as String?,
      spendingChartType: data['spendingChartType'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        if (accounts != null)
          'accounts': accounts!.map((b) => b.toMap()).toList(),
        if (categories != null)
          'categories': categories!.map((b) => b.toMap()).toList(),
        if (subCategories != null)
          'subCategories': subCategories!.map((b) => b.toMap()).toList(),
        if (vendors != null)
          'vendors': vendors!.map((b) => b.toMap()).toList(),
        if (payments != null)
          'payments': payments!.map((b) => b.toMap()).toList(),
        'default_currency': defaultCurrency.toFirestore(),
        'frequent_currencies': bookmarkedCurrencies,
        'default_entries': defaultEntries, // Map — normalised format
        if (themeId != null) 'themeId': themeId,
        if (spendingChartType != null) 'spendingChartType': spendingChartType,
      };

  static List<BudgetData>? _budgetDataList(dynamic raw) {
    if (raw == null || raw is! List) return null;
    return raw
        .map((e) => e is Map<String, dynamic> ? BudgetData.fromMap(e) : null)
        .whereType<BudgetData>()
        .toList();
  }

  // Reads Swift's flat alternating array OR an already-normalised Firestore Map.
  static Map<String, String> _decodeDefaultEntries(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      return Map<String, String>.fromEntries(
        raw.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())),
      );
    }
    if (raw is List) {
      final result = <String, String>{};
      for (var i = 0; i + 1 < raw.length; i += 2) {
        result[raw[i].toString()] = raw[i + 1].toString();
      }
      return result;
    }
    return {};
  }
}
