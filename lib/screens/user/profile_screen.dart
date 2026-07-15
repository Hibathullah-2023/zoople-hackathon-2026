import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/accessibility_service.dart';

/// Profile screen with anonymity toggle, password change, and settings.
/// Shared across all roles.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: StreamBuilder<UserModel?>(
        stream: authService.userProfileStream(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // ─── Avatar & Info ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            (user.displayName?.isNotEmpty == true
                                    ? user.displayName![0]
                                    : user.email[0])
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.displayName ?? 'Anonymous User',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.anonymousId,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.tertiary,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user.role.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Anonymity Toggle (Citizens only) ───
                if (user.role == 'user') ...[
                  _SettingCard(
                    icon: user.isAnonymous
                        ? Icons.visibility_off
                        : Icons.visibility,
                    iconColor: AppColors.secondary,
                    title: 'Anonymous Mode',
                    subtitle: user.isAnonymous
                        ? 'Your identity is hidden from admin & authorities'
                        : 'Your identity may be visible to admin & authorities',
                    trailing: Switch(
                      value: user.isAnonymous,
                      activeThumbColor: AppColors.secondary,
                      onChanged: (val) async {
                        await authService.toggleAnonymity(val);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ─── Text Size Control Card ───
                Consumer<AccessibilityService>(
                  builder: (context, accessibility, child) {
                    return _SettingCard(
                      icon: Icons.text_fields,
                      iconColor: AppColors.tertiary,
                      title: 'Text Size Adjustment',
                      subtitle:
                          'Current text size scale: ${(accessibility.textScale * 100).round()}%',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove,
                              color: AppColors.secondary,
                            ),
                            onPressed: accessibility.textScale > 0.8
                                ? () => accessibility.decreaseTextSize()
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add,
                              color: AppColors.secondary,
                            ),
                            onPressed: accessibility.textScale < 1.4
                                ? () => accessibility.increaseTextSize()
                                : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // ─── Settings List ───
                _SettingCard(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  onTap: () => _showChangePasswordDialog(context),
                ),
                const SizedBox(height: 8),
                _SettingCard(
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions',
                  onTap: () => context.push('/terms'),
                ),
                const SizedBox(height: 8),
                _SettingCard(
                  icon: Icons.info_outline,
                  title: 'About Nizhal',
                  subtitle: 'Version 1.0.0',
                ),
                const SizedBox(height: 24),

                // ─── Logout ───
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await authService.logout();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(color: AppColors.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.3),
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

  void _showChangePasswordDialog(BuildContext context) {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: currentPwController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: newPwController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: confirmPwController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (currentPwController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter current password'),
                  ),
                );
                return;
              }
              if (newPwController.text.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('New password must be at least 8 characters'),
                  ),
                );
                return;
              }
              if (newPwController.text.contains(' ')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('New password must not contain spaces'),
                  ),
                );
                return;
              }
              if (newPwController.text != confirmPwController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              try {
                await context.read<AuthService>().updatePassword(
                  currentPassword: currentPwController.text,
                  newPassword: newPwController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password updated!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  // Strip the "Exception: " prefix from error message
                  final msg = e.toString().replaceAll('Exception: ', '');
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingCard({
    required this.icon,
    this.iconColor = AppColors.onSurfaceVariant,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
              if (trailing == null && onTap != null)
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.onSurfaceVariant,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
