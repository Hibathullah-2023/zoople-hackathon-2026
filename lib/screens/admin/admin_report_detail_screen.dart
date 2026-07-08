import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/report_model.dart';
import '../../models/authority_model.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';

/// Admin report detail — view case details, assign to authority, mark fake.
/// Identity-blind: admin cannot see reporter PII.
class AdminReportDetailScreen extends StatelessWidget {
  final String reportId;
  const AdminReportDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context) {
    final reportService = context.read<ReportService>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Case Details')),
      body: StreamBuilder<ReportModel?>(
        stream: reportService.reportStream(reportId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final report = snapshot.data;
          if (report == null) {
            return const Center(child: Text('Report not found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Report ID & Status ───
                Row(
                  children: [
                    Text(
                      report.reportId,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.tertiary,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    _Badge(
                      label: report.priority.toUpperCase(),
                      color: _priorityColor(report.priority),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ─── Description ───
                _Section(
                  label: 'DESCRIPTION',
                  child: Text(
                    report.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Details Grid ───
                _Section(
                  label: 'CASE DETAILS',
                  child: Column(
                    children: [
                      _DetailRow('Category',
                          AppConstants.categoryLabels[report.category] ?? report.category),
                      _DetailRow('Status',
                          report.status.replaceAll('_', ' ').toUpperCase()),
                      _DetailRow('District', report.district ?? '—'),
                      _DetailRow('City', report.city ?? '—'),
                      _DetailRow('Address', report.locationAddress ?? '—'),
                      _DetailRow('Photos', '${report.mediaCount} attached'),
                      _DetailRow(
                          'Submitted',
                          '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year}'),
                      _DetailRow(
                          'Anonymous',
                          report.isAnonymous ? 'Yes' : 'No'),
                      if (report.priorityBypassed)
                        _DetailRow('Bypass', 'Auto-routed to authority'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Keywords (for admin reference) ───
                if (report.keywords.isNotEmpty)
                  _Section(
                    label: 'DETECTED KEYWORDS',
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: report.keywords.map((k) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppColors.error.withValues(alpha: 0.1),
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
                const SizedBox(height: 16),

                // ─── Reporter Identity Notice ───
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
                      const Icon(Icons.visibility_off,
                          color: AppColors.secondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Reporter identity is encrypted and hidden. Only the reporter can view their own identity.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Action Buttons ───
                if (report.status != AppConstants.statusFake &&
                    report.status != AppConstants.statusResolved &&
                    report.status != AppConstants.statusClosed) ...[
                  // Assign to Authority
                  if (report.assignedAuthorityUid == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showAssignDialog(context, report),
                        icon: const Icon(Icons.assignment_ind),
                        label: const Text('Assign to Authority'),
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Mark as Fake
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showMarkFakeDialog(context, report),
                      icon:
                          const Icon(Icons.report, color: AppColors.error),
                      label: const Text(
                        'Mark as Fake',
                        style: TextStyle(color: AppColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color:
                                AppColors.error.withValues(alpha: 0.3)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Update Status
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showStatusUpdateDialog(context, report),
                      icon: const Icon(Icons.update),
                      label: const Text('Update Status'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
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
      case 'critical': return AppColors.priorityCritical;
      case 'high': return AppColors.priorityHigh;
      case 'medium': return AppColors.priorityMedium;
      case 'low': return AppColors.priorityLow;
      default: return AppColors.outline;
    }
  }

  void _showAssignDialog(BuildContext context, ReportModel report) async {
    final authorities = await FirebaseFirestore.instance
        .collection(AppConstants.authoritiesCollection)
        .where('isActive', isEqualTo: true)
        .get();

    if (!context.mounted) return;

    final authorityList = authorities.docs
        .map((d) => AuthorityModel.fromFirestore(d))
        .toList();

    if (authorityList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active authorities available.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Assign to Authority'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: authorityList.length,
            itemBuilder: (_, i) {
              final auth = authorityList[i];
              return ListTile(
                leading: const Icon(Icons.badge,
                    color: AppColors.secondary),
                title: Text(auth.name),
                subtitle: Text(
                    '${auth.jurisdiction ?? 'General'} • ${auth.assignedCaseCount} cases'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final adminUid =
                      context.read<AuthService>().currentUser?.uid ?? '';
                  await context.read<ReportService>().assignToAuthority(
                        reportId: report.reportId,
                        authorityUid: auth.uid,
                        adminUid: adminUid,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Assigned to ${auth.name}')),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showMarkFakeDialog(BuildContext context, ReportModel report) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        icon: const Icon(Icons.warning, color: AppColors.error, size: 40),
        title: const Text('Mark as Fake Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will increment the reporter\'s fake count. At 3 fake reports, the user will be auto-suspended.',
              style: TextStyle(
                  color: AppColors.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: noteController,
              decoration:
                  const InputDecoration(labelText: 'Reason (optional)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final adminUid =
                  context.read<AuthService>().currentUser?.uid ?? '';
              await context.read<ReportService>().markAsFake(
                    reportId: report.reportId,
                    markedBy: adminUid,
                    markedByRole: 'admin',
                    note: noteController.text.trim().isNotEmpty
                        ? noteController.text.trim()
                        : null,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report marked as fake.')),
                );
              }
            },
            child: const Text('Confirm',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showStatusUpdateDialog(BuildContext context, ReportModel report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppConstants.statusPipeline.map((s) {
            return ListTile(
              title: Text(s.replaceAll('_', ' ').toUpperCase()),
              leading: Radio<String>(
                value: s,
                groupValue: report.status,
                onChanged: (val) async {
                  if (val == null) return;
                  Navigator.pop(ctx);
                  final adminUid =
                      context.read<AuthService>().currentUser?.uid ?? '';
                  await context.read<ReportService>().updateReportStatus(
                        reportId: report.reportId,
                        newStatus: val,
                        changedBy: adminUid,
                        changedByRole: 'admin',
                      );
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
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
            width: 90,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant
                        .withValues(alpha: 0.7))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.onSurface)),
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
