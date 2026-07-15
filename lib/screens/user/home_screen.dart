import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/kerala_locations.dart';
import '../../models/report_model.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';

/// End user home screen displaying the Kerala Incident Heat Map first,
/// global statistics, and authority/excise/police directory.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final List<CircleMarker> _densityCircles = [];
  final List<Marker> _mapMarkers = [];
  bool _isMapLoading = true;
  String _currentDistrict = 'Ernakulam'; // Default fallback
  String? _userRole;
  final Set<String> _myReportIds = {};
  StreamSubscription<List<ReportModel>>? _reportsSubscription;
  int _lastMonthCount = 0;

  // Center on Kerala
  static const LatLng _keralaCenter = LatLng(
    KeralaLocations.keralaCenterLat,
    KeralaLocations.keralaCenterLng,
  );

  final List<Map<String, String>> _emergencyContacts = [
    {
      'name': 'Excise Division Office, Ernakulam',
      'type': 'Excise Station',
      'address': 'Kathrikadavu, Kaloor, Kochi, Kerala 682017',
      'phone': '+914842401844',
      'query': 'Excise Division Office, Ernakulam',
      'district': 'Ernakulam',
    },
    {
      'name': 'SI Suresh Kumar (Narcotics Specialization)',
      'type': 'District Authority',
      'address': 'District Police Office, Ernakulam, Kerala 682011',
      'phone': '+919497996901',
      'query': 'District Police Office, Ernakulam',
      'district': 'Ernakulam',
    },
    {
      'name': 'City Police Commissioner Office, Thrissur',
      'type': 'Police Station',
      'address': 'Palace Road, Thrissur, Kerala 680020',
      'phone': '+914872423511',
      'query': 'City Police Office, Thrissur',
      'district': 'Thrissur',
    },
    {
      'name': 'DySP Madhavan Nair (Investigation Specialization)',
      'type': 'District Authority',
      'address': 'District Police Office, Thrissur, Kerala 680020',
      'phone': '+919497996902',
      'query': 'District Police Office, Thrissur',
      'district': 'Thrissur',
    },
    {
      'name': 'Excise Range Office, Kozhikode',
      'type': 'Excise Station',
      'address': 'Kutchery Road, Kozhikode, Kerala 673011',
      'phone': '+914952370162',
      'query': 'Excise Range Office, Kozhikode',
      'district': 'Kozhikode',
    },
    {
      'name': 'SI Fathima Rahma (Patrol Specialization)',
      'type': 'District Authority',
      'address': 'City Police Office, Kozhikode, Kerala 673001',
      'phone': '+919497996903',
      'query': 'City Police Office, Kozhikode',
      'district': 'Kozhikode',
    },
    {
      'name': 'City Police Office, Thiruvananthapuram',
      'type': 'Police Station',
      'address':
          'CV Raman Pillai Road, Thycaud, Thiruvananthapuram, Kerala 695014',
      'phone': '+914712331843',
      'query': 'City Police Commissioner, Thiruvananthapuram',
      'district': 'Thiruvananthapuram',
    },
  ];

  Future<void> _detectCurrentDistrict() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position =
            await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 10),
              ),
            );
        List<Placemark> placemarks = [];
        try {
          placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
        } catch (_) {}

        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          final cleanSubAdmin = (pm.subAdministrativeArea ?? '').toLowerCase();
          final cleanLocality = (pm.locality ?? '').toLowerCase();

          for (final district in KeralaLocations.districts) {
            if (cleanSubAdmin.contains(district.toLowerCase()) ||
                cleanLocality.contains(district.toLowerCase()) ||
                (pm.administrativeArea ?? '').toLowerCase().contains(
                  district.toLowerCase(),
                )) {
              if (mounted) {
                setState(() {
                  _currentDistrict = district;
                });
              }
              break;
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _detectCurrentDistrict().then((_) => _loadIncidentDensity());
  }

  @override
  void dispose() {
    _reportsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadIncidentDensity() async {
    try {
      final reportService = context.read<ReportService>();
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;

      if (currentUser != null) {
        final profile = await authService.getCurrentUserProfile();
        _userRole = profile?.role;

        final myReportDocs = await FirebaseFirestore.instance
            .collection(AppConstants.usersCollection)
            .doc(currentUser.uid)
            .collection('myReports')
            .get();
        _myReportIds.clear();
        for (final d in myReportDocs.docs) {
          _myReportIds.add(d.id);
        }
      }

      await _reportsSubscription?.cancel();
      _reportsSubscription = reportService.allReportsStream().listen((
        reportsList,
      ) {
        final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
        final reports = reportsList
            .where((r) => r.createdAt.isAfter(oneMonthAgo))
            .toList();

        final List<CircleMarker> circles = [];
        final List<Marker> markers = [];

        for (final report in reports) {
          if (report.location != null) {
            final latLng = LatLng(
              report.location!.latitude,
              report.location!.longitude,
            );
            final heatColor = _priorityColor(report.priority);

            // Heat Map Overlay: Transparent circle outer glow and core
            circles.add(
              CircleMarker(
                point: latLng,
                radius: 18,
                useRadiusInMeter: false,
                color: heatColor.withValues(alpha: 0.18),
                borderStrokeWidth: 0,
              ),
            );

            circles.add(
              CircleMarker(
                point: latLng,
                radius: 6,
                useRadiusInMeter: false,
                color: heatColor.withValues(alpha: 0.7),
                borderStrokeWidth: 1.5,
                borderColor: Colors.white,
              ),
            );

            // Interactive tap overlay marker
            markers.add(
              Marker(
                point: latLng,
                width: 40,
                height: 40,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showIncidentMapDetails(report),
                  child: Container(color: Colors.transparent),
                ),
              ),
            );
          }
        }

        if (mounted) {
          setState(() {
            _densityCircles.clear();
            _densityCircles.addAll(circles);
            _mapMarkers.clear();
            _mapMarkers.addAll(markers);
            _lastMonthCount = reports.length;
            _isMapLoading = false;
          });
        }
      });
    } catch (e) {
      debugPrint('Failed to load home map density: $e');
      if (mounted) {
        setState(() => _isMapLoading = false);
      }
    }
  }

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showIncidentMapDetails(ReportModel report) {
    final isOwnerOrAdmin =
        _userRole == 'admin' ||
        _userRole == 'authority' ||
        _myReportIds.contains(report.reportId);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isOwnerOrAdmin) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppConstants.categoryLabels[report.category] ??
                          report.category.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(
                          report.status,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        report.status.toUpperCase().replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _statusColor(report.status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _detailRow('District', report.district ?? 'Unknown'),
                _detailRow('Priority', report.priority.toUpperCase()),
                _detailRow(
                  'Date',
                  '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year}',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Description:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.description,
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/track/${report.reportId}');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.onSecondary,
                    ),
                    child: const Text('Track Report Status'),
                  ),
                ),
              ] else ...[
                const Text(
                  'Incident Report',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow(
                  'Category',
                  AppConstants.categoryLabels[report.category] ??
                      report.category.toUpperCase(),
                ),
                _detailRow('District', report.district ?? 'Unknown'),
                _detailRow(
                  'Date Reported',
                  '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year}',
                ),
                _detailRow('Priority', report.priority.toUpperCase()),
                _detailRow(
                  'Status',
                  (report.status == 'resolved' || report.status == 'closed')
                      ? '✅ Solved'
                      : (report.status == 'under_review' ||
                            report.status == 'assigned' ||
                            report.status == 'in_progress')
                      ? '⏳ Under Investigation / Pending'
                      : '❌ Unsolved',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock, color: AppColors.error, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Detailed view restricted to reporter or authorized personnel only.',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _makeCall(String phone) async {
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _openMapDirection(String query) async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final reportService = context.read<ReportService>();

    final sortedContacts = List<Map<String, String>>.from(
      _emergencyContacts,
    ).where((a) => a['district'] == _currentDistrict).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.jpeg',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Kerala Heat Map (First Visible) ───
            Container(
              height: 280,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _keralaCenter,
                        initialZoom: 7.6,
                        maxZoom: 13.0,
                        minZoom: 7.4,
                        cameraConstraint: CameraConstraint.contain(
                          bounds: LatLngBounds(
                            const LatLng(8.1, 74.8),
                            const LatLng(12.9, 77.6),
                          ),
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                          userAgentPackageName: 'org.nizhal.app',
                        ),
                        CircleLayer(circles: _densityCircles),
                        MarkerLayer(markers: _mapMarkers),
                      ],
                    ),
                    if (_isMapLoading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cases Reported in the Last One Month',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: $_lastMonthCount',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // Map legend panel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _LegendItem(color: Colors.red, label: 'Critical (10+)'),
                  _LegendItem(color: Colors.orange, label: 'High (5-9)'),
                  _LegendItem(color: Colors.yellow, label: 'Moderate (2-4)'),
                  _LegendItem(color: Colors.green, label: 'Low (0-1)'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── Daily Statistics ───
            StreamBuilder<Map<String, dynamic>?>(
              stream: reportService.globalAggregatesStream(),
              builder: (context, snapshot) {
                final data = snapshot.data;
                final totalReports = data?['totalReports'] ?? 0;
                final resolvedReports = data?['resolvedReports'] ?? 0;
                final activeUsers = data?['activeUsers'] ?? 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          label: 'Incidents',
                          value: '$totalReports',
                          icon: Icons.warning_amber_outlined,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatChip(
                          label: 'Solved',
                          value: '$resolvedReports',
                          icon: Icons.check_circle_outline,
                          color: AppColors.tertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatChip(
                          label: 'Daily Users',
                          value: '$activeUsers',
                          icon: Icons.people_outline,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // ─── Community Impact (Current District) ───
            StreamBuilder<Map<String, dynamic>?>(
              stream: reportService.globalAggregatesStream(),
              builder: (context, snapshot) {
                final data = snapshot.data;
                final districtBreakdown =
                    data?['districtBreakdown'] as Map<String, dynamic>? ?? {};
                final districtIncidents =
                    districtBreakdown[_currentDistrict] ?? 0;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.secondary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Community Impact: $_currentDistrict District',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total incidents reported in your district: $districtIncidents',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // ─── Office & Authorities Directory ───
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Nearby Contacts & Offices',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Addresses and direct contacts of excise, police offices, and jurisdiction authorities.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 8),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: sortedContacts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final office = sortedContacts[index];
                return Container(
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
                          Icon(
                            office['type'] == 'District Authority'
                                ? Icons.badge_outlined
                                : office['type'] == 'Excise Station'
                                ? Icons.local_police_outlined
                                : Icons.local_police,
                            color: AppColors.secondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  office['type']!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            office['district']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant.withValues(
                                alpha: 0.8,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        office['name']!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        office['address']!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openMapDirection(office['query']!),
                            icon: const Icon(Icons.directions, size: 16),
                            label: const Text('Directions'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _makeCall(office['phone']!),
                            icon: const Icon(Icons.phone, size: 16),
                            label: const Text('Call'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.5),
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
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
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
