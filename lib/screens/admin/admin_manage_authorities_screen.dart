import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/kerala_locations.dart';
import '../../models/authority_model.dart';
import '../../services/auth_service.dart';

/// Admin manage authorities screen — CRUD authorities.
/// Admin-only: creates authority accounts.
class AdminManageAuthoritiesScreen extends StatelessWidget {
  const AdminManageAuthoritiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Manage Authorities')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAuthorityDialog(context),
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(AppConstants.authoritiesCollection)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge,
                      size: 64,
                      color: AppColors.onSurfaceVariant
                          .withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  const Text(
                    'No authorities yet',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap + to add an authority',
                    style: TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final auth = AuthorityModel.fromFirestore(docs[index]);
              return _AuthorityCard(authority: auth);
            },
          );
        },
      ),
    );
  }

  void _showAddAuthorityDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final badgeController = TextEditingController();
    String? selectedJurisdiction;
    String? selectedSpecialization;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          title: const Text('Add Authority'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Name *',
                      prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: badgeController,
                  decoration: const InputDecoration(
                      labelText: 'Badge ID',
                      prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedJurisdiction,
                  dropdownColor: AppColors.surfaceContainerHigh,
                  decoration: const InputDecoration(
                      labelText: 'Jurisdiction',
                      prefixIcon: Icon(Icons.map_outlined)),
                  items: KeralaLocations.districts.map((d) {
                    return DropdownMenuItem(value: d, child: Text(d));
                  }).toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedJurisdiction = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedSpecialization,
                  dropdownColor: AppColors.surfaceContainerHigh,
                  decoration: const InputDecoration(
                      labelText: 'Specialization',
                      prefixIcon: Icon(Icons.work_outline)),
                  items: const [
                    DropdownMenuItem(
                        value: 'narcotics', child: Text('Narcotics')),
                    DropdownMenuItem(
                        value: 'patrol', child: Text('Patrol')),
                    DropdownMenuItem(
                        value: 'investigation',
                        child: Text('Investigation')),
                  ],
                  onChanged: (val) =>
                      setDialogState(() => selectedSpecialization = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Name and email are required.')),
                  );
                  return;
                }

                Navigator.pop(ctx);

                try {
                  await context
                      .read<AuthService>()
                      .createAuthorityAccount(
                        email: emailController.text.trim(),
                        name: nameController.text.trim(),
                        badgeId: badgeController.text.trim().isNotEmpty
                            ? badgeController.text.trim()
                            : null,
                        jurisdiction: selectedJurisdiction,
                        specialization: selectedSpecialization,
                      );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Authority account created.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorityCard extends StatelessWidget {
  final AuthorityModel authority;
  const _AuthorityCard({required this.authority});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: authority.isActive
                  ? AppColors.secondary.withValues(alpha: 0.15)
                  : AppColors.outline.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                authority.name.isNotEmpty
                    ? authority.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: authority.isActive
                      ? AppColors.secondary
                      : AppColors.outline,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authority.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  authority.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                Row(
                  children: [
                    if (authority.jurisdiction != null) ...[
                      Text(
                        authority.jurisdiction!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.tertiary),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '${authority.assignedCaseCount} cases',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (authority.isActive
                      ? AppColors.secondary
                      : AppColors.error)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              authority.isActive ? 'ACTIVE' : 'INACTIVE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: authority.isActive
                    ? AppColors.secondary
                    : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
