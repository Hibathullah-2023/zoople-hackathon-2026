import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/kerala_locations.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../models/user_model.dart';

/// End user home screen with anonymous status, quick actions,
/// community impact stats, and Kerala heat map.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final reportService = context.read<ReportService>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ─── App Bar ───
          SliverAppBar(
            floating: true,
            pinned: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                Icon(
                  Icons.shield,
                  color: AppColors.primaryFixedDim,
                  size: 24,
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.secondary, AppColors.tertiary],
                  ).createShader(bounds),
                  child: const Text(
                    'Nizhal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.vpn_key, color: AppColors.onSurfaceVariant),
                onPressed: () {},
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── Anonymous Status Hero ───
                _buildAnonymousStatusCard(authService),
                const SizedBox(height: 20),

                // ─── Quick Actions ───
                _buildQuickActions(context),
                const SizedBox(height: 20),

                // ─── Floating Stats ───
                _buildFloatingStats(reportService),
                const SizedBox(height: 20),

                // ─── Community Impact ───
                _buildCommunityImpact(reportService),
                const SizedBox(height: 20),

                // ─── Kerala Heat Map Preview ───
                _buildHeatMapPreview(),
                const SizedBox(height: 20),

                // ─── Security Note ───
                _buildSecurityNote(),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Anonymous status hero card
  Widget _buildAnonymousStatusCard(AuthService authService) {
    return StreamBuilder<UserModel?>(
      stream: authService.userProfileStream(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isAnonymous = user?.isAnonymous ?? true;
        final anonymousId = user?.anonymousId ?? 'NX-****';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: const Border(
              top: BorderSide(color: AppColors.divider, width: 1),
            ),
          ),
          child: Stack(
            children: [
              // Shimmer overlay
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _ShimmerOverlay(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT STATUS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tertiary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAnonymous ? 'Identity Masked' : 'Identity Visible',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'User ID: $anonymousId • Signal Encrypted',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      isAnonymous ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Quick action bento grid
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.add_circle,
                iconBgColor: AppColors.errorContainer.withValues(alpha: 0.2),
                iconColor: AppColors.error,
                title: 'Report Incident',
                subtitle: 'Secure & Anonymous',
                onTap: () => context.go('/report'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.receipt_long,
                iconBgColor: AppColors.secondaryContainer.withValues(alpha: 0.2),
                iconColor: AppColors.secondary,
                title: 'Track Reports',
                subtitle: 'Real-time Status',
                onTap: () => context.go('/track'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.psychology,
                iconBgColor: AppColors.tertiaryContainer.withValues(alpha: 0.2),
                iconColor: AppColors.tertiary,
                title: 'Rehab AI Chat',
                subtitle: 'Supportive Chatbot',
                onTap: () => context.push('/rehab/chat'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.healing,
                iconBgColor: AppColors.primaryContainer.withValues(alpha: 0.2),
                iconColor: AppColors.primaryFixedDim,
                title: 'Nearby Centres',
                subtitle: 'Helplines & Clinics',
                onTap: () => context.push('/rehab/centres'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Floating daily stats
  Widget _buildFloatingStats(ReportService reportService) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: reportService.globalAggregatesStream(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final totalReports = data?['totalReports'] ?? 0;
        final resolvedReports = data?['resolvedReports'] ?? 0;
        final activeUsers = data?['activeUsers'] ?? 0;

        return Row(
          children: [
            Expanded(
              child: _StatChip(
                label: 'Reports',
                value: '$totalReports',
                icon: Icons.description_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatChip(
                label: 'Resolved',
                value: '$resolvedReports',
                icon: Icons.check_circle_outline,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatChip(
                label: 'Users',
                value: '$activeUsers',
                icon: Icons.people_outline,
                color: AppColors.tertiary,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Community impact trends section
  Widget _buildCommunityImpact(ReportService reportService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Community Impact',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              'Last 30 Days',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ImpactCard(
          label: 'Reports Resolved',
          value: '—',
          trend: '↑ 12%',
          trendLabel: 'vs last month',
          accentColor: AppColors.secondary,
        ),
        const SizedBox(height: 8),
        _ImpactCard(
          label: 'Active Investigations',
          value: '—',
          trend: '↑ 8%',
          trendLabel: 'This week',
          accentColor: AppColors.tertiary,
        ),
      ],
    );
  }

  /// Kerala heat map preview card
  Widget _buildHeatMapPreview() {
    return GestureDetector(
      onTap: () => context.push('/map'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surfaceContainerLow, AppColors.surfaceContainerLowest],
          ),
          borderRadius: BorderRadius.circular(16),
          border: const Border(
            top: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map, color: AppColors.tertiary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Kerala Incident Map',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tertiary,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Simple district-level heat map representation
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: KeralaLocations.districts.map((district) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant, width: 0.5),
                ),
                child: Text(
                  district,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),
          Text(
            'City-level incident density across Kerala',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    ),
  );
}

  /// Security note footer
  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.security, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your data is protected with end-to-end encryption.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Widgets ───

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: const Border(
              top: BorderSide(color: AppColors.cardBorderTop, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  final String trendLabel;
  final Color accentColor;

  const _ImpactCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.trendLabel,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                trend,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
              Text(
                trendLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Subtle shimmer animation overlay
class _ShimmerOverlay extends StatefulWidget {
  @override
  State<_ShimmerOverlay> createState() => _ShimmerOverlayState();
}

class _ShimmerOverlayState extends State<_ShimmerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 + 2 * _controller.value, 0),
              end: Alignment(1 + 2 * _controller.value, 0),
              colors: [
                Colors.transparent,
                AppColors.secondary.withValues(alpha: 0.05),
                Colors.transparent,
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: Container(
            color: Colors.transparent,
          ),
        );
      },
    );
  }
}
