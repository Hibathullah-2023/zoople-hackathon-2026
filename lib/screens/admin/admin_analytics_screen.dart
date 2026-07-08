import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../services/report_service.dart';

/// Admin analytics dashboard with charts and trends.
class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportService = context.read<ReportService>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Analytics')),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: reportService.globalAggregatesStream(),
        builder: (context, snapshot) {
          final data = snapshot.data;
          final categoryBreakdown =
              Map<String, int>.from(data?['categoryBreakdown'] ?? {});
          final priorityBreakdown =
              Map<String, int>.from(data?['priorityBreakdown'] ?? {});
          final totalReports = data?['totalReports'] ?? 0;
          final resolvedReports = data?['resolvedReports'] ?? 0;
          final pendingReports = data?['pendingReports'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Summary Cards ───
                Row(
                  children: [
                    _SummaryCard(
                      label: 'Total',
                      value: '$totalReports',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      label: 'Resolved',
                      value: '$resolvedReports',
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      label: 'Pending',
                      value: '$pendingReports',
                      color: AppColors.error,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Category Chart ───
                const Text(
                  'Cases by Category',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: categoryBreakdown.isEmpty
                      ? const Center(
                          child: Text('No data yet',
                              style: TextStyle(
                                  color: AppColors.onSurfaceVariant)))
                      : PieChart(
                          PieChartData(
                            sections: _buildPieSections(categoryBreakdown),
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                if (categoryBreakdown.isNotEmpty)
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: categoryBreakdown.entries.map((e) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _categoryColor(e.key),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${e.key}: ${e.value}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 24),

                // ─── Priority Chart ───
                const Text(
                  'Cases by Priority',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: priorityBreakdown.isEmpty
                      ? const Center(
                          child: Text('No data yet',
                              style: TextStyle(
                                  color: AppColors.onSurfaceVariant)))
                      : BarChart(
                          BarChartData(
                            barGroups:
                                _buildBarGroups(priorityBreakdown),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              leftTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    const labels = [
                                      'Critical',
                                      'High',
                                      'Medium',
                                      'Low'
                                    ];
                                    if (value.toInt() < labels.length) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8),
                                        child: Text(
                                          labels[value.toInt()],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color:
                                                AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, int> data) {
    final total = data.values.fold(0, (a, b) => a + b);
    return data.entries.map((e) {
      final pct = total > 0 ? (e.value / total * 100) : 0;
      return PieChartSectionData(
        value: e.value.toDouble(),
        title: '${pct.round()}%',
        color: _categoryColor(e.key),
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<BarChartGroupData> _buildBarGroups(Map<String, int> data) {
    final priorities = ['critical', 'high', 'medium', 'low'];
    final colors = [
      AppColors.priorityCritical,
      AppColors.priorityHigh,
      AppColors.priorityMedium,
      AppColors.priorityLow,
    ];

    return priorities.asMap().entries.map((entry) {
      final count = data[entry.value] ?? 0;
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: colors[entry.key],
            width: 28,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'trafficking':
        return AppColors.priorityCritical;
      case 'manufacturing':
        return AppColors.priorityHigh;
      case 'drug_sale':
        return AppColors.priorityMedium;
      case 'drug_use':
        return AppColors.secondary;
      case 'possession':
        return AppColors.tertiary;
      default:
        return AppColors.outline;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
