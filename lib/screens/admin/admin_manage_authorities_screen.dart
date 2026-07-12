import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/kerala_locations.dart';
import '../../models/authority_model.dart';
import '../../services/auth_service.dart';

/// Admin manage authorities screen — CRUD authorities with jurisdiction/specialization filters.
class AdminManageAuthoritiesScreen extends StatefulWidget {
  const AdminManageAuthoritiesScreen({super.key});

  @override
  State<AdminManageAuthoritiesScreen> createState() =>
      _AdminManageAuthoritiesScreenState();
}

class _AdminManageAuthoritiesScreenState
    extends State<AdminManageAuthoritiesScreen> {
  String? _jurisdictionFilter;
  String? _specializationFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Manage Authorities')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAuthorityDialog(context),
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          // ─── Inline Filters for Jurisdiction & Specialization ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _jurisdictionFilter,
                    dropdownColor: AppColors.surfaceContainerHigh,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Jurisdiction',
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
                          'All Jurisdictions',
                          style: TextStyle(color: AppColors.onSurfaceVariant),
                        ),
                      ),
                      ...KeralaLocations.districts.map((d) {
                        return DropdownMenuItem<String>(
                          value: d,
                          child: Text(
                            d,
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _jurisdictionFilter = val;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _specializationFilter,
                    dropdownColor: AppColors.surfaceContainerHigh,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Specialization',
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
                          'All Specializations',
                          style: TextStyle(color: AppColors.onSurfaceVariant),
                        ),
                      ),
                      const DropdownMenuItem<String>(
                        value: 'narcotics',
                        child: Text(
                          'Narcotics',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const DropdownMenuItem<String>(
                        value: 'patrol',
                        child: Text(
                          'Patrol',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const DropdownMenuItem<String>(
                        value: 'investigation',
                        child: Text(
                          'Investigation',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _specializationFilter = val;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.authoritiesCollection)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                final authorities = docs
                    .map((d) => AuthorityModel.fromFirestore(d))
                    .toList();

                // Apply local filtering
                final filteredAuthorities = authorities.where((auth) {
                  if (_jurisdictionFilter != null &&
                      auth.jurisdiction != _jurisdictionFilter)
                    return false;
                  if (_specializationFilter != null &&
                      auth.specialization != _specializationFilter)
                    return false;
                  return true;
                }).toList();

                if (filteredAuthorities.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.badge,
                          size: 64,
                          color: AppColors.onSurfaceVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No matching authorities found',
                          style: TextStyle(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filteredAuthorities.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _AuthorityCard(
                      authority: filteredAuthorities[index],
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

  void _showAddAuthorityDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
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
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: badgeController,
                  decoration: const InputDecoration(
                    labelText: 'Badge ID (e.g. KP-9882)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedJurisdiction,
                  dropdownColor: AppColors.surfaceContainerHigh,
                  decoration: const InputDecoration(
                    labelText: 'Jurisdiction (District)',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
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
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'narcotics',
                      child: Text('Narcotics'),
                    ),
                    DropdownMenuItem(value: 'patrol', child: Text('Patrol')),
                    DropdownMenuItem(
                      value: 'investigation',
                      child: Text('Investigation'),
                    ),
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
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty ||
                    passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields.'),
                    ),
                  );
                  return;
                }
                if (passwordController.text.length < 8) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 8 characters.'),
                    ),
                  );
                  return;
                }
                if (passwordController.text.contains(' ')) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Password must not contain spaces.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                try {
                  await context.read<AuthService>().createAuthorityAccount(
                    email: emailController.text.trim(),
                    name: nameController.text.trim(),
                    password: passwordController.text,
                    badgeId: badgeController.text.trim().isNotEmpty
                        ? badgeController.text.trim()
                        : null,
                    jurisdiction: selectedJurisdiction,
                    specialization: selectedSpecialization,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Authority account created.'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                          fontSize: 11,
                          color: AppColors.tertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '${authority.assignedCaseCount} cases',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ─── Active/Inactive Switch Toggle ───
          Switch(
            value: authority.isActive,
            activeColor: AppColors.secondary,
            onChanged: (val) async {
              try {
                await context.read<AuthService>().updateAuthority(
                  authorityDocId: authority.uid,
                  isActive: val,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update status: $e')),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 4),
          // ─── Edit Button ───
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AppColors.secondary,
            tooltip: 'Edit Authority',
            onPressed: () => _showEditDialog(context),
          ),
          // ─── Delete Button ───
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.error,
            tooltip: 'Delete Authority',
            onPressed: () => _showDeleteConfirmation(context),
          ),
        ],
      ),
    );
  }

  /// Show edit dialog pre-filled with authority's current data
  void _showEditDialog(BuildContext context) {
    final nameController = TextEditingController(text: authority.name);
    final badgeController = TextEditingController(
      text: authority.badgeId ?? '',
    );
    String? selectedJurisdiction = authority.jurisdiction;
    String? selectedSpecialization = authority.specialization;
    bool isActive = authority.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          title: const Text('Edit Authority'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: badgeController,
                  decoration: const InputDecoration(
                    labelText: 'Badge ID',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedJurisdiction,
                  dropdownColor: AppColors.surfaceContainerHigh,
                  decoration: const InputDecoration(
                    labelText: 'Jurisdiction (District)',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
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
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'narcotics',
                      child: Text('Narcotics'),
                    ),
                    DropdownMenuItem(value: 'patrol', child: Text('Patrol')),
                    DropdownMenuItem(
                      value: 'investigation',
                      child: Text('Investigation'),
                    ),
                  ],
                  onChanged: (val) =>
                      setDialogState(() => selectedSpecialization = val),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Active Status'),
                  value: isActive,
                  activeColor: AppColors.secondary,
                  onChanged: (val) => setDialogState(() => isActive = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await context.read<AuthService>().updateAuthority(
                    authorityDocId: authority.uid,
                    name: nameController.text.trim(),
                    badgeId: badgeController.text.trim().isNotEmpty
                        ? badgeController.text.trim()
                        : null,
                    jurisdiction: selectedJurisdiction,
                    specialization: selectedSpecialization,
                    isActive: isActive,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Authority updated.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Delete Authority'),
        content: Text(
          'Are you sure you want to delete "${authority.name}"?\n\nThis will remove their profile and unassign any pending cases. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<AuthService>().deleteAuthority(
                  authority.uid,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Authority deleted.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
