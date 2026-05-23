import 'package:flutter/foundation.dart';

@immutable
class DashboardStats {
  const DashboardStats({
    required this.totalIncome,
    required this.totalExpense,
    required this.categoryBreakdown,
  });

  final double totalIncome;
  final double totalExpense;
  final Map<String, double> categoryBreakdown;

  double get balance => totalIncome - totalExpense;

  static const DashboardStats empty = DashboardStats(
    totalIncome: 0,
    totalExpense: 0,
    categoryBreakdown: {},
  );

  @override
  bool operator ==(Object other) =>
      other is DashboardStats &&
      other.totalIncome == totalIncome &&
      other.totalExpense == totalExpense &&
      mapEquals(other.categoryBreakdown, categoryBreakdown);

  @override
  int get hashCode => Object.hashAll([
        totalIncome,
        totalExpense,
        ...categoryBreakdown.entries.expand((e) => [e.key, e.value]),
      ]);
}
