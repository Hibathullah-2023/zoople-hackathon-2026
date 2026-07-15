import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/report_model.dart';
import '../../models/status_log_model.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';

/// Authority case detail — view case, update status, mark fake.
class AuthorityCaseDetailScreen extends StatelessWidget {
  final String reportId;
  const AuthorityCaseDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context) {
    final reportService = context.read<ReportService>();
    final authService = context.read<AuthService>();
    final uid = authService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Case Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/authority');
            }
          },
        ),
      ),
      body: StreamBuilder<ReportModel?>(
        stream: reportService.reportStream(reportId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final report = snapshot.data;
          if (report == null) {
            return const Center(child: Text('Case not found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Case Header ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      Text(
                        report.reportId,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tertiary,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Badge(
                            label: report.priority.toUpperCase(),
                            color: _priorityColor(report.priority),
                          ),
                          const SizedBox(width: 8),
                          _Badge(
                            label: report.status
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            color: _statusColor(report.status),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Description ───
                _Section(
                  label: 'INCIDENT DESCRIPTION',
                  child: Text(
                    report.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ─── Details ───
                _Section(
                  label: 'CASE DETAILS',
                  child: Column(
                    children: [
                      _DetailRow(
                        'Category',
                        AppConstants.categoryLabels[report.category] ??
                            report.category,
                      ),
                      _DetailRow('District', report.district ?? '—'),
                      _DetailRow('City', report.city ?? '—'),
                      _DetailRow('Address', report.locationAddress ?? '—'),
                      _DetailRow('Photos', '${report.mediaCount} attached'),
                      _DetailRow('Submitted', _formatDate(report.createdAt)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ─── Evidence Photos & Download ───
                if (report.mediaUrls.isNotEmpty) ...[
                  _Section(
                    label: 'ATTACHED EVIDENCE',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: report.mediaUrls.length,
                            itemBuilder: (context, index) {
                              final url = report.mediaUrls[index];
                              return Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      );
                                    },
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              for (final url in report.mediaUrls) {
                                final uri = Uri.parse(url);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              }
                            },
                            icon: const Icon(
                              Icons.download,
                              color: AppColors.secondary,
                              size: 18,
                            ),
                            label: Text(
                              'Download Evidence (${report.mediaUrls.length} photo${report.mediaUrls.length > 1 ? 's' : ''})',
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.secondary),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ─── Reporter Identity Restricted notice for Authorities ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.visibility_off,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Reporter identity is restricted (visible to Admin only).',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ─── Keywords ───
                if (report.keywords.isNotEmpty) ...[
                  _Section(
                    label: 'KEYWORDS',
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: report.keywords.map((k) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            k,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ─── Status Timeline ───
                const Text(
                  'Status Timeline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<StatusLogModel>>(
                  stream: reportService.statusLogStream(reportId),
                  builder: (context, logSnap) {
                    final logs = logSnap.data ?? [];
                    if (logs.isEmpty) {
                      return const Text(
                        'No updates yet.',
                        style: TextStyle(color: AppColors.onSurfaceVariant),
                      );
                    }

                    return Column(
                      children: logs.map((log) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _statusColor(log.newStatus),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log.newStatus
                                            .replaceAll('_', ' ')
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                      if (log.note != null)
                                        Text(
                                          log.note!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.onSurfaceVariant
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatTime(log.changedAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ─── Action Buttons ───
                if (report.status != AppConstants.statusResolved &&
                    report.status != AppConstants.statusClosed &&
                    report.status != AppConstants.statusFake) ...[
                  // Update to In Progress
                  if (report.status == AppConstants.statusAssigned)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await reportService.updateReportStatus(
                            reportId: report.reportId,
                            newStatus: AppConstants.statusInProgress,
                            changedBy: uid,
                            changedByRole: 'authority',
                            note: 'Investigation started',
                          );
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Investigation'),
                      ),
                    ),

                  // Resolve
                  if (report.status == AppConstants.statusInProgress) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await reportService.updateReportStatus(
                            reportId: report.reportId,
                            newStatus: AppConstants.statusResolved,
                            changedBy: uid,
                            changedByRole: 'authority',
                            note: 'Case resolved',
                          );
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Mark Resolved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Mark as Fake
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.surfaceContainerHigh,
                            title: const Text('Mark as Fake?'),
                            content: const Text(
                              'This will increment the reporter\'s fake count. At 3 strikes, auto-suspension.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Confirm',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          await reportService.markAsFake(
                            reportId: report.reportId,
                            markedBy: uid,
                            markedByRole: 'authority',
                          );
                        }
                      },
                      icon: const Icon(Icons.report, color: AppColors.error),
                      label: const Text(
                        'Mark as Fake',
                        style: TextStyle(color: AppColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

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

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
