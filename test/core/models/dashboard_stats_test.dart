// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/models/dashboard_stats.dart';

void main() {
  group('DashboardStats', () {
    test('balance is totalIncome minus totalExpense', () {
      const stats = DashboardStats(
        totalIncome: 1000.0,
        totalExpense: 350.0,
        categoryBreakdown: {},
      );
      expect(stats.balance, closeTo(650.0, 0.001));
    });

    test('empty has all zero values', () {
      expect(DashboardStats.empty.totalIncome, 0.0);
      expect(DashboardStats.empty.totalExpense, 0.0);
      expect(DashboardStats.empty.balance, 0.0);
      expect(DashboardStats.empty.categoryBreakdown, isEmpty);
    });

    test('categoryBreakdown holds per-category totals', () {
      const stats = DashboardStats(
        totalIncome: 0,
        totalExpense: 150.0,
        categoryBreakdown: {'Food': 80.0, 'Transport': 70.0},
      );
      expect(stats.categoryBreakdown['Food'], 80.0);
      expect(stats.categoryBreakdown['Transport'], 70.0);
    });
  });
}
