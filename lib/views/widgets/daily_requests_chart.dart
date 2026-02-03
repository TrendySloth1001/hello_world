import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DailyRequestsChart extends StatefulWidget {
  final List<dynamic> dailyRequests;

  const DailyRequestsChart({super.key, required this.dailyRequests});

  @override
  State<DailyRequestsChart> createState() => _DailyRequestsChartState();
}

class _DailyRequestsChartState extends State<DailyRequestsChart> {
  bool _showBarChart = true;

  @override
  Widget build(BuildContext context) {
    if (widget.dailyRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Daily Requests (Last 7 Days)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.bar_chart,
                      color: _showBarChart ? Colors.blue : Colors.grey,
                    ),
                    onPressed: () => setState(() => _showBarChart = true),
                    tooltip: 'Bar Chart',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.show_chart,
                      color: !_showBarChart ? Colors.blue : Colors.grey,
                    ),
                    onPressed: () => setState(() => _showBarChart = false),
                    tooltip: 'Line Chart',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: _showBarChart ? _buildBarChart() : _buildLineChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return RotatedBox(
      quarterTurns: 1,
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.blueGrey.withOpacity(0.8),
              rotateAngle: -90, // Rotate tooltip back
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final date = widget.dailyRequests[group.x.toInt()]['date'];
                return BarTooltipItem(
                  '$date\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: (rod.toY).toStringAsFixed(0),
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            // Original Bottom (Dates) -> Now Left
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 &&
                      value.toInt() < widget.dailyRequests.length) {
                    final dateStr = widget.dailyRequests[value.toInt()]['date'];
                    final date = DateTime.parse(dateStr);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: Text(
                          DateFormat('MM/dd').format(date),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 40,
              ),
            ),
            // Original Left (Counts) -> Now Top (or flip to Bottom/Right?)
            // Let's hide Left titles (now Top) and show Right titles (now Bottom) or keep as is?
            // If rotated 90 deg clockwise:
            // Left Axis is now at the Top.
            // Right Axis is now at the Bottom.
            // Bottom Axis is now at the Left.
            // Top Axis is now at the Right.

            // We want Counts on the Bottom (which is Right Axis after rotation).
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  // Only show integers
                  if (value % 1 != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: RotatedBox(
                      quarterTurns: -1,
                      child: Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
              ), // Hide original left (now top)
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false, // Originally horizontal lines?
            // After rotation, horizontal grid lines become vertical.
            // We probably want usage distinct lines.
            drawHorizontalLine: true,
            getDrawingHorizontalLine: (value) {
              return FlLine(color: Colors.white10, strokeWidth: 1);
            },
            getDrawingVerticalLine: (value) {
              return FlLine(color: Colors.white10, strokeWidth: 1);
            },
          ),
          barGroups: widget.dailyRequests.asMap().entries.map((entry) {
            final index = entry.key;
            final count = (entry.value['count'] as num).toDouble();
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: count,
                  color: Colors.blueAccent,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.white10, strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 &&
                    value.toInt() < widget.dailyRequests.length) {
                  final dateStr = widget.dailyRequests[value.toInt()]['date'];
                  final date = DateTime.parse(dateStr);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('MM/dd').format(date),
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const Text('');
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                );
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
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: widget.dailyRequests.asMap().entries.map((entry) {
              return FlSpot(
                entry.key.toDouble(),
                (entry.value['count'] as num).toDouble(),
              );
            }).toList(),
            isCurved: true,
            color: Colors.greenAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.greenAccent.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
