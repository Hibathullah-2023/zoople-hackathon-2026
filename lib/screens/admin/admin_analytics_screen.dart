import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';
import '../../services/auth_service.dart';

/// Admin Home Page / Dashboard screen showing the Curve Graph first,
/// then Predictive Trend Analysis, Recent Reports list, and overall charts.
class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  Widget _buildCurveGraph(List<ReportModel> reports) {
    if (reports.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Center(
          child: Text(
            'No data available for graph',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
      );
    }

    final sortedReports = List<ReportModel>.from(reports)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final Map<String, int> dailyCounts = {};
    for (final r in sortedReports) {
      final dateKey =
          "${r.createdAt.year}-${r.createdAt.month.toString().padLeft(2, '0')}-${r.createdAt.day.toString().padLeft(2, '0')}";
      dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
    }

    final dailyEntries = dailyCounts.entries.toList();
    final lastEntries = dailyEntries.length > 7
        ? dailyEntries.sublist(dailyEntries.length - 7)
        : dailyEntries;

    final List<FlSpot> spots = [];
    for (int i = 0; i < lastEntries.length; i++) {
      spots.add(FlSpot(i.toDouble(), lastEntries[i].value.toDouble()));
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.only(right: 20, left: 10, top: 15, bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < lastEntries.length) {
                    final dateStr = lastEntries[idx].key;
                    final parts = dateStr.split('-');
                    if (parts.length == 3) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "${parts[1]}/${parts[2]}",
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
              isCurved: true,
              color: AppColors.secondary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.secondary.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictiveCard(List<ReportModel> reports) {
    if (reports.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Center(
          child: Text(
            'No data for trend analysis yet.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
      );
    }

    final sorted = List<ReportModel>.from(reports)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final Map<String, int> monthlyCounts = {};
    for (final r in sorted) {
      final key =
          "${r.createdAt.year}-${r.createdAt.month.toString().padLeft(2, '0')}";
      monthlyCounts[key] = (monthlyCounts[key] ?? 0) + 1;
    }

    final months = monthlyCounts.keys.toList()..sort();
    final counts = months.map((m) => monthlyCounts[m]!).toList();

    double slope = 0.1;
    double intercept = counts.isNotEmpty ? counts.last.toDouble() : 5.0;

    if (counts.length >= 2) {
      double sumX = 0;
      double sumY = 0;
      double sumXY = 0;
      double sumXX = 0;
      int n = counts.length;

      for (int i = 0; i < n; i++) {
        sumX += i;
        sumY += counts[i];
        sumXY += i * counts[i];
        sumXX += i * i;
      }

      final denominator = (n * sumXX - sumX * sumX);
      if (denominator != 0) {
        slope = (n * sumXY - sumX * sumY) / denominator;
        intercept = (sumY - slope * sumX) / n;
      }
    }

    final nextIndex = counts.length.toDouble();
    final predictedNext = (slope * nextIndex + intercept)
        .clamp(1.0, 100.0)
        .round();
    final trendDirection = slope > 0.05
        ? "Increasing"
        : (slope < -0.05 ? "Decreasing" : "Stable");
    final trendColor = slope > 0.05
        ? AppColors.error
        : (slope < -0.05 ? Colors.green : Colors.yellow);
    final trendIcon = slope > 0.05
        ? Icons.trending_up
        : (slope < -0.05 ? Icons.trending_down : Icons.trending_flat);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: AppColors.secondary),
              const SizedBox(width: 8),
              const Text(
                'Predictive Trend Analysis',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Based on reporting patterns over the last ${counts.length} active month(s), our linear regression model projects future incidents.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TREND DIRECTION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(trendIcon, color: trendColor, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        trendDirection,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: trendColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'PREDICTED (NEXT MONTH)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '~ $predictedNext cases',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              slope > 0.05
                  ? '⚠️ Warning: Upward case projection. We recommend increasing surveillance and allocating additional authorities to rising hotspots.'
                  : '✅ Notice: Containment trend is stable or decreasing. Continue supporting rehab centers and active local awareness campaigns.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportService = context.read<ReportService>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.onSurfaceVariant),
            onPressed: () async {
              await context.read<AuthService>().logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ReportModel>>(
        stream: reportService.allReportsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data ?? [];
          final categoryBreakdown = <String, int>{};
          final priorityBreakdown = <String, int>{};
          int totalReports = reports.length;
          int resolvedReports = 0;
          int pendingReports = 0;

          for (final r in reports) {
            categoryBreakdown[r.category] =
                (categoryBreakdown[r.category] ?? 0) + 1;
            priorityBreakdown[r.priority] =
                (priorityBreakdown[r.priority] ?? 0) + 1;
            if (r.status == 'resolved' || r.status == 'closed') {
              resolvedReports++;
            } else {
              pendingReports++;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Curve Graph (TIMELINE OF REPORTS) ───
                const Text(
                  'Incident Reports Timeline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _buildCurveGraph(reports),

                const SizedBox(height: 24),

                // ─── Predictive Analytics Card ───
                _buildPredictiveCard(reports),

                const SizedBox(height: 24),

                // ─── Recent Reports Section ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Reports',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/admin/cases'),
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (reports.isEmpty)
                  const Center(
                    child: Text(
                      'No reports available',
                      style: TextStyle(color: AppColors.onSurfaceVariant),
                    ),
                  )
                else
                  ...reports.take(5).map((report) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _RecentReportCard(
                        report: report,
                        onTap: () =>
                            context.go('/admin/report/${report.reportId}'),
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // ─── Summary Cards ───
                const Text(
                  'Case Summary Statistics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
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
                          child: Text(
                            'No data yet',
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        )
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
                      final label = AppConstants.categoryLabels[e.key] ?? e.key;
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
                            '$label: ${e.value}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
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
                          child: Text(
                            'No data yet',
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        )
                      : BarChart(
                          BarChartData(
                            barGroups: _buildBarGroups(priorityBreakdown),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    const labels = [
                                      'Critical',
                                      'High',
                                      'Medium',
                                      'Low',
                                    ];
                                    if (value.toInt() < labels.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          labels[value.toInt()],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.onSurfaceVariant,
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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

class _RecentReportCard extends StatelessWidget {
  final ReportModel report;
  final VoidCallback onTap;

  const _RecentReportCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color priorityColor;
    switch (report.priority.toLowerCase()) {
      case 'critical':
        priorityColor = AppColors.priorityCritical;
        break;
      case 'high':
        priorityColor = AppColors.priorityHigh;
        break;
      case 'medium':
        priorityColor = AppColors.priorityMedium;
        break;
      default:
        priorityColor = AppColors.priorityLow;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                report.priority.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: priorityColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.categoryLabels[report.category] ??
                        report.category,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    report.district ?? 'Unknown District',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  report.reportId,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.tertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  report.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color:
                        report.status == 'resolved' || report.status == 'closed'
                        ? AppColors.secondary
                        : AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
