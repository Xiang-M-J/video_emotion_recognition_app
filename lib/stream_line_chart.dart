import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:verapp/utils/emotion_labels.dart';

class EmotionLineChartStream extends StatelessWidget {
  final Stream<List<(double, int)>> dataStream;
  final double height;

  const EmotionLineChartStream(
      {super.key, required this.dataStream, required this.height});

  String formatTime(double time) {
    int totalSeconds = (time).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<(double, int)>>(
      stream: dataStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('暂无数据'));
        }

        final data = snapshot.data!;
        final spots = data.map((e) => FlSpot(e.$1, e.$2.toDouble())).toList();
        final minTime = data.first.$1;
        final maxTime = data.last.$1;
        final currentValue = emoLabels[data.last.$2];

        return Column(
          children: [
            Text('当前情感：$currentValue', style: const TextStyle(fontSize: 18)),
            // const SizedBox(height: 12),
            SizedBox(
              height: height,
              child: LineChart(
                LineChartData(
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: max(maxTime - minTime, 1),
                        getTitlesWidget: (value, meta) {
                          if (value == minTime || value == maxTime) {
                            return Text(formatTime(value),
                                style: const TextStyle(fontSize: 12));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.black87,
                      tooltipRoundedRadius: 4,
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          final value = spot.y.toInt(); // 点的值
                          
                          return LineTooltipItem(
                            emoLabels[value],
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      width: 1.5,
                      color: Colors.blueGrey,
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: Colors.blue, // 点的填充色
                            strokeWidth: 1, // 描边宽度
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(show: false),
                      color: Colors.blue,
                    ),
                  ],
                  minY: 0,
                  maxY: 7,
                ),
                duration: Duration.zero,
              ),
            ),
          ],
        );
      },
    );
  }
}
