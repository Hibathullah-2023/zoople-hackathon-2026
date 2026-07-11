import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/report_model.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';

/// My Reports screen — list of user's submitted reports with search by tracking ID.
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  ReportModel? _searchResult;
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchByTrackingId() async {
    final id = _searchController.text.trim();
    if (id.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchResult = null;
    });

    try {
      final report =
          await context.read<ReportService>().getReportByTrackingId(id);
      setState(() {
        _searchResult = report;
        if (report == null) _searchError = 'No report found with this ID.';
      });
    } catch (e) {
      setState(() => _searchError = 'Search failed. Please try again.');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final reportService = context.read<ReportService>();
    final uid = authService.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('My Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.onSurfaceVariant),
            onPressed: () async {
              await authService.logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/report'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ─── Search by Tracking ID ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _searchController,
                    style: const TextStyle(
                        color: AppColors.onSurface, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Enter Tracking ID (e.g., NZ-260708-12345)',
                      prefixIcon:
                          Icon(Icons.search, color: AppColors.onSurfaceVariant),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onFieldSubmitted: (_) => _searchByTrackingId(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _searchByTrackingId,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                    minimumSize: const Size(48, 48),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search, size: 20),
                ),
              ],
            ),
          ),

          // ─── Search Result ───
          if (_searchResult != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ReportListItem(
                report: _searchResult!,
                onTap: () =>
                    context.go('/track/${_searchResult!.reportId}'),
              ),
            ),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _searchError!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ),

          const Divider(height: 32),

          // ─── My Reports List ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your Reports',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: uid == null
                ? const Center(
                    child: Text('Please login to see your reports.'))
                : FutureBuilder<List<ReportModel>>(
                    future: reportService.getUserReports(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final reports = snapshot.data ?? [];
                      if (reports.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long,
                                  size: 64,
                                  color: AppColors.onSurfaceVariant
                                      .withValues(alpha: 0.3)),
                              const SizedBox(height: 12),
                              Text(
                                'No reports yet',
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: reports.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final report = reports[index];
                          return _ReportListItem(
                            report: report,
                            onTap: () =>
                                context.go('/track/${report.reportId}'),
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
}

class _ReportListItem extends StatelessWidget {
  final ReportModel report;
  final VoidCallback onTap;

  const _ReportListItem({required this.report, required this.onTap});

  Color _statusColor(String status) {
    switch (status) {
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
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: _statusColor(report.status),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.reportId,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppConstants.categoryLabels[report.category] ??
                          report.category,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year}',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(report.status)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  report.status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(report.status),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: AppColors.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
