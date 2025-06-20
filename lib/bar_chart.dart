import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:verapp/utils/emotion_labels.dart';

class EmotionBarChart extends StatelessWidget {
  final List<List<double>> data;

  EmotionBarChart({super.key, required this.data});

  final List<Color> barColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }
    return BarChart(
      BarChartData(
        maxY: 1.2,
        minY: 0.0,
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 0.25, // 设置一个较小的间隔，但配合 getTitlesWidget 精确控制显示
              getTitlesWidget: (value, meta) {
                if (value == 0.25 ||
                    (value < 0.51 && value > 0.49) ||
                    (value < 0.76 && value > 0.74) ||
                    (value < 1.01 && value > 0.99)) {
                  return Text(
                    value.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 14),
                  );
                }
                return const SizedBox.shrink(); // 其他刻度不显示
              },
              reservedSize: 30,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                int index = value.toInt();
                if (index >= 0 && index < 7) {
                  return Text(emoLabels[index]);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barGroups: List.generate(data[0].length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data[0][index],
                color: barColors[index],
                width: 18,
                borderRadius: BorderRadius.circular(4),
                rodStackItems: [],
              ),
            ],
            showingTooltipIndicators: [0],
            barsSpace: 4,
          );
        }),
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 0,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                data[0][groupIndex].toStringAsFixed(2),
                const TextStyle(
                  color: Colors.black,
                  // fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
