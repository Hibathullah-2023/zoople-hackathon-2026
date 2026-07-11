import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/report_model.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../services/pdf_service.dart';

/// Admin dashboard — curve graph of reports by time, inline filters,
/// and list of new/reported cases.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String? _statusFilter;
  String? _priorityFilter;
  String? _categoryFilter;
  List<ReportModel> _allReports = [];
  List<ReportModel> _currentReports = [];

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

  @override
  Widget build(BuildContext context) {
    final reportService = context.read<ReportService>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.admin_panel_settings,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text('Admin Dashboard'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {
              if (_currentReports.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No reports to export.')),
                );
                return;
              }
              PdfService().generateAndPrintReport(
                reports: _currentReports,
                statusFilter: _statusFilter,
                priorityFilter: _priorityFilter,
                categoryFilter: _categoryFilter,
              );
            },
          ),
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

          _allReports = snapshot.data ?? [];

          // Apply local filtering
          _currentReports = _allReports.where((r) {
            if (_statusFilter != null && r.status != _statusFilter)
              return false;
            if (_priorityFilter != null && r.priority != _priorityFilter)
              return false;
            if (_categoryFilter != null && r.category != _categoryFilter)
              return false;
            return true;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Curve Graph (Reporting by Time) ───
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cases Reported over Time',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCurveGraph(_allReports),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ─── Always Visible Inline Dropdown Filters ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        dropdownColor: AppColors.surfaceContainerHigh,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          labelStyle: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'All Status',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          ...AppConstants.statusPipeline.map((s) {
                            return DropdownMenuItem<String>(
                              value: s,
                              child: Text(
                                s.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _statusFilter = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _priorityFilter,
                        dropdownColor: AppColors.surfaceContainerHigh,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          labelStyle: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'All Priority',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          ...AppConstants.priorities.map((p) {
                            return DropdownMenuItem<String>(
                              value: p,
                              child: Text(
                                p.toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _priorityFilter = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _categoryFilter,
                        dropdownColor: AppColors.surfaceContainerHigh,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'All Category',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          ...AppConstants.categories.map((c) {
                            return DropdownMenuItem<String>(
                              value: c,
                              child: Text(
                                AppConstants.categoryLabels[c] ?? c,
                                style: const TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _categoryFilter = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ─── Case List Title ───
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Reports & Incidents',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ),

              // ─── Case List ───
              Expanded(
                child: _currentReports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 54,
                              color: AppColors.onSurfaceVariant.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No reports found',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _currentReports.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final report = _currentReports[index];
                          return _AdminReportCard(
                            report: report,
                            onTap: () =>
                                context.go('/admin/report/${report.reportId}'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminReportCard extends StatelessWidget {
  final ReportModel report;
  final VoidCallback onTap;

  const _AdminReportCard({required this.report, required this.onTap});

  Color _priorityColor(String p) {
    switch (p) {
      case 'critical':
        return AppColors.priorityCritical;
      case 'high':
        return AppColors.priorityHigh;
      case 'medium':
        return AppColors.priorityMedium;
      case 'low':
        return AppColors.priorityLow;
      default:
        return AppColors.outline;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'submitted':
        return AppColors.statusSubmitted;
      case 'under_review':
        return AppColors.statusUnderReview;
      case 'assigned':
        return AppColors.statusAssigned;
      case 'in_progress':
        return AppColors.statusInProgress;
      case 'resolved':
        return AppColors.statusResolved;
      case 'closed':
        return AppColors.statusClosed;
      case 'fake':
        return AppColors.statusFake;
      default:
        return AppColors.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: _priorityColor(report.priority),
                width: 4,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    report.reportId,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _priorityColor(
                        report.priority,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      report.priority.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _priorityColor(report.priority),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(
                        report.status,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      report.status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(report.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppConstants.categoryLabels[report.category] ?? report.category,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                report.description.length > 100
                    ? '${report.description.substring(0, 100)}...'
                    : report.description,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (report.district != null) ...[
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${report.city ?? ''} ${report.district ?? ''}'.trim(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(
                    Icons.photo,
                    size: 14,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${report.mediaCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  if (report.priorityBypassed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'BYPASSED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
