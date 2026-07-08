import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';

import '../../services/pdf_service.dart';

/// Admin dashboard — real-time list of all reports with filters.
/// Identity-blind: admin cannot see reporter PII.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String? _statusFilter;
  String? _priorityFilter;
  String? _categoryFilter;
  List<ReportModel> _currentReports = [];

  @override
  Widget build(BuildContext context) {
    final reportService = context.read<ReportService>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings,
                color: AppColors.primaryFixedDim, size: 22),
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
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Active Filters ───
          if (_statusFilter != null ||
              _priorityFilter != null ||
              _categoryFilter != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 6,
                children: [
                  if (_statusFilter != null)
                    _FilterChip(
                      label: _statusFilter!,
                      onRemove: () =>
                          setState(() => _statusFilter = null),
                    ),
                  if (_priorityFilter != null)
                    _FilterChip(
                      label: _priorityFilter!,
                      onRemove: () =>
                          setState(() => _priorityFilter = null),
                    ),
                  if (_categoryFilter != null)
                    _FilterChip(
                      label:
                          AppConstants.categoryLabels[_categoryFilter] ??
                              _categoryFilter!,
                      onRemove: () =>
                          setState(() => _categoryFilter = null),
                    ),
                  TextButton(
                    onPressed: () => setState(() {
                      _statusFilter = null;
                      _priorityFilter = null;
                      _categoryFilter = null;
                    }),
                    child: const Text('Clear All',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          // ─── Report List ───
          Expanded(
            child: StreamBuilder<List<ReportModel>>(
              stream: reportService.allReportsStream(
                statusFilter: _statusFilter,
                priorityFilter: _priorityFilter,
                categoryFilter: _categoryFilter,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reports = snapshot.data ?? [];
                _currentReports = reports;
                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox,
                            size: 64,
                            color: AppColors.onSurfaceVariant
                                .withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        const Text(
                          'No reports found',
                          style:
                              TextStyle(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _AdminReportCard(
                      report: report,
                      onTap: () =>
                          context.go('/admin/report/${report.reportId}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Reports',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Status filter
                  const Text('Status',
                      style: TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: AppConstants.statusPipeline.map((s) {
                      return ChoiceChip(
                        label: Text(s.replaceAll('_', ' ')),
                        selected: _statusFilter == s,
                        onSelected: (sel) {
                          setModalState(() {});
                          setState(
                              () => _statusFilter = sel ? s : null);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Priority filter
                  const Text('Priority',
                      style: TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: AppConstants.priorities.map((p) {
                      return ChoiceChip(
                        label: Text(p),
                        selected: _priorityFilter == p,
                        onSelected: (sel) {
                          setModalState(() {});
                          setState(
                              () => _priorityFilter = sel ? p : null);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Category filter
                  const Text('Category',
                      style: TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: AppConstants.categories.map((c) {
                      return ChoiceChip(
                        label: Text(
                            AppConstants.categoryLabels[c] ?? c),
                        selected: _categoryFilter == c,
                        onSelected: (sel) {
                          setModalState(() {});
                          setState(
                              () => _categoryFilter = sel ? c : null);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminReportCard extends StatelessWidget {
  final ReportModel report;
  final VoidCallback onTap;

  const _AdminReportCard({required this.report, required this.onTap});

  Color _priorityColor(String p) {
    switch (p) {
      case 'critical': return AppColors.priorityCritical;
      case 'high': return AppColors.priorityHigh;
      case 'medium': return AppColors.priorityMedium;
      case 'low': return AppColors.priorityLow;
      default: return AppColors.outline;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'submitted': return AppColors.statusSubmitted;
      case 'under_review': return AppColors.statusUnderReview;
      case 'assigned': return AppColors.statusAssigned;
      case 'in_progress': return AppColors.statusInProgress;
      case 'resolved': return AppColors.statusResolved;
      case 'closed': return AppColors.statusClosed;
      case 'fake': return AppColors.statusFake;
      default: return AppColors.outline;
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
                      color: AppColors.tertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _priorityColor(report.priority)
                          .withValues(alpha: 0.15),
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
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(report.status)
                          .withValues(alpha: 0.15),
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
                AppConstants.categoryLabels[report.category] ??
                    report.category,
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
                    Icon(Icons.location_on,
                        size: 14,
                        color: AppColors.onSurfaceVariant
                            .withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      '${report.city ?? ''} ${report.district ?? ''}'
                          .trim(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(Icons.photo,
                      size: 14,
                      color: AppColors.onSurfaceVariant
                          .withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(
                    '${report.mediaCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  if (report.priorityBypassed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            AppColors.error.withValues(alpha: 0.1),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label.replaceAll('_', ' '),
        style: const TextStyle(fontSize: 12, color: AppColors.secondary),
      ),
      backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
      deleteIcon:
          const Icon(Icons.close, size: 16, color: AppColors.secondary),
      onDeleted: onRemove,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
    );
  }
}
