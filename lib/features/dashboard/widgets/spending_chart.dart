import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SpendingChart extends StatelessWidget {
  const SpendingChart({
    super.key,
    required this.breakdown,
    required this.chartType,
  });

  final Map<String, double> breakdown;
  final String chartType;

  static const _colors = [
    Colors.blue,
    Colors.orange,
    Colors.green,
    Colors.purple,
    Colors.red,
    Colors.teal,
  ];

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('No spending this month')),
      );
    }

    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();

    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: chartType == 'pie' ? _buildPie(top) : _buildBar(context, top),
      ),
    );
  }

  Widget _buildBar(BuildContext context, List<MapEntry<String, double>> top) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: top.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                color: _colors[e.key % _colors.length],
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= top.length) return const SizedBox.shrink();
                final label = top[idx].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label.length > 8 ? '${label.substring(0, 7)}.' : label,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildPie(List<MapEntry<String, double>> top) {
    final total = top.fold(0.0, (s, e) => s + e.value);
    return PieChart(
      PieChartData(
        sections: top.asMap().entries.map((e) {
          final pct = total > 0 ? (e.value.value / total * 100) : 0;
          return PieChartSectionData(
            color: _colors[e.key % _colors.length],
            value: e.value.value,
            title: '${pct.toStringAsFixed(0)}%',
            radius: 70,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        sectionsSpace: 2,
      ),
    );
  }
}
