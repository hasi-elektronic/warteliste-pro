import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// Wiederverwendbare Chart-Widgets fuer die Statistik-Ansicht.
///
/// Alle Widgets nutzen fl_chart mit einheitlichem Styling,
/// Tooltips und dem Teal-Farbschema der App.

// ──────────────────────────────────────────────
// Farbpalette fuer Charts
// ──────────────────────────────────────────────

const List<Color> _chartColors = [
  Color(0xFF009688), // Teal
  Color(0xFF00BCD4), // Cyan
  Color(0xFFFFA726), // Orange
  Color(0xFF66BB6A), // Green
  Color(0xFFAB47BC), // Purple
  Color(0xFFEF5350), // Red
  Color(0xFF42A5F5), // Blue
  Color(0xFFFFCA28), // Yellow
  Color(0xFF8D6E63), // Brown
  Color(0xFF78909C), // Blue Grey
  Color(0xFFEC407A), // Pink
  Color(0xFF26A69A), // Teal Accent
];

const List<String> _monatLabels = [
  'Jan',
  'Feb',
  'Mär',
  'Apr',
  'Mai',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Okt',
  'Nov',
  'Dez',
];

// ──────────────────────────────────────────────
// MonthlyBarChart
// ──────────────────────────────────────────────

/// Balkendiagramm mit 12 Balken (Jan-Dez).
///
/// [data] ist eine Map mit Monat (1-12) als Key und Anzahl als Value.
class MonthlyBarChart extends StatelessWidget {
  final Map<int, int> data;
  final Color color;
  final void Function(int month)? onBarTap;

  const MonthlyBarChart({
    super.key,
    required this.data,
    this.color = AppTheme.primaryColor,
    this.onBarTap,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = data.values.fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = maxValue == 0 ? 10.0 : (maxValue * 1.3).ceilToDouble();

    return AspectRatio(
      aspectRatio: 2.0,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchCallback: (event, response) {
              if (event is FlTapUpEvent &&
                  response != null &&
                  response.spot != null &&
                  onBarTap != null) {
                final monthIndex = response.spot!.touchedBarGroupIndex;
                if (monthIndex >= 0 && monthIndex < 12) {
                  onBarTap!(monthIndex + 1);
                }
              }
            },
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final monat = _monatLabels[group.x];
                return BarTooltipItem(
                  '$monat\n${rod.toY.toInt()}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min || value != value.roundToDouble()) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= 12) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _monatLabels[idx],
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 20 ? (maxY / 5).ceilToDouble() : 2,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(12, (index) {
            final value = (data[index + 1] ?? 0).toDouble();
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: value,
                  color: color,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: color.withValues(alpha: 0.06),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// DisorderPieChart
// ──────────────────────────────────────────────

/// Kreisdiagramm fuer die Stoerungsbild-Verteilung mit farbiger Legende.
class DisorderPieChart extends StatelessWidget {
  final Map<String, int> data;
  final void Function(String disorder)? onItemTap;

  const DisorderPieChart({super.key, required this.data, this.onItemTap});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'Keine Daten vorhanden',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final total = data.values.fold<int>(0, (a, b) => a + b);
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 2.2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 28,
              sections: List.generate(sortedEntries.length, (index) {
                final entry = sortedEntries[index];
                final percentage = total > 0 ? (entry.value / total) * 100 : 0;
                final color = _chartColors[index % _chartColors.length];
                return PieChartSectionData(
                  value: entry.value.toDouble(),
                  color: color,
                  radius: 40,
                  title: percentage >= 8
                      ? '${percentage.toStringAsFixed(0)}%'
                      : '',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: List.generate(sortedEntries.length, (index) {
            final entry = sortedEntries[index];
            final color = _chartColors[index % _chartColors.length];
            return GestureDetector(
              onTap: onItemTap != null ? () => onItemTap!(entry.key) : null,
              child: _LegendItem(
                color: color,
                label: entry.key.isEmpty ? 'Unbekannt' : entry.key,
                count: entry.value,
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// InsurancePieChart
// ──────────────────────────────────────────────

/// Einfaches 2-Segment-Kreisdiagramm fuer KK vs Privat.
class InsurancePieChart extends StatelessWidget {
  final int kk;
  final int privat;
  final void Function(String versicherung)? onItemTap;

  const InsurancePieChart({
    super.key,
    required this.kk,
    required this.privat,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = kk + privat;
    if (total == 0) {
      return const Center(
        child: Text(
          'Keine Daten vorhanden',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 2.2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 28,
              sections: [
                PieChartSectionData(
                  value: kk.toDouble(),
                  color: AppTheme.primaryColor,
                  radius: 42,
                  title: '$kk',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PieChartSectionData(
                  value: privat.toDouble(),
                  color: AppTheme.accentColor,
                  radius: 42,
                  title: '$privat',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onItemTap != null ? () => onItemTap!('KK') : null,
              child: _LegendItem(
                color: AppTheme.primaryColor,
                label: 'Krankenkasse',
                count: kk,
              ),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: onItemTap != null ? () => onItemTap!('Privat') : null,
              child: _LegendItem(
                color: AppTheme.accentColor,
                label: 'Privat',
                count: privat,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// AuslastungLineChart
// ──────────────────────────────────────────────

/// Liniendiagramm fuer die monatliche Auslastung (0-100%).
///
/// [percentages] ist eine Map mit Monat (1-12) als Key und Prozent als Value.
class AuslastungLineChart extends StatelessWidget {
  final Map<int, double> percentages;

  const AuslastungLineChart({super.key, required this.percentages});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.0,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final monat = _monatLabels[spot.x.toInt()];
                  return LineTooltipItem(
                    '$monat\n${spot.y.toStringAsFixed(1)}%',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 25,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '${value.toInt()}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= 12) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _monatLabels[idx],
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(12, (index) {
                return FlSpot(
                  index.toDouble(),
                  percentages[index + 1] ?? 0,
                );
              }),
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppTheme.primaryColor,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AppTheme.primaryColor,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Legende
// ──────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
