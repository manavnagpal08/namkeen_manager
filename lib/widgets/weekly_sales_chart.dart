import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
// import '../core/namkeen_theme.dart'; // Unused

class WeeklySalesChart extends StatelessWidget {
  final List<OrderModel> orders;

  const WeeklySalesChart({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Sales per Day for last 7 days
    final now = DateTime.now();
    final Map<int, double> salesPerDay = {};
    for (int i = 0; i < 7; i++) {
      salesPerDay[i] = 0;
    }

    // Filter last 7 days
    for (var order in orders) {
      final diff = now.difference(order.date).inDays;
      if (diff >= 0 && diff < 7) {
        // 0 = Today, 6 = 7 days ago
        // We want to map it to graph index 0..6 where 6 is Today
        final index = 6 - diff;
        salesPerDay[index] = (salesPerDay[index] ?? 0) + order.totalAmount;
      }
    }

    double maxY = 100;
    salesPerDay.forEach((key, value) {
      if (value > maxY) maxY = value;
    });

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
              // tooltipBgColor: Colors.blueGrey, // Removed deprecated property
              getTooltipColor: (_) => const Color(0xFF4FA8C5), // Match bar color
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                 return BarTooltipItem(
                   '₹${rod.toY.round()}',
                   const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                 );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final style = TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 10);
                  final date = now.subtract(Duration(days: 6 - value.toInt()));
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4,
                    child: Text(DateFormat('E').format(date), style: style),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: salesPerDay[i] ?? 0,
                  color: const Color(0xFF4FA8C5), // Nice Blue
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY * 1.1,
                    color: Colors.grey.withOpacity(0.1),
                  ),
                ),
              ],
            );
          }),
          gridData: const FlGridData(show: false),
        ),
    );
  }
}
