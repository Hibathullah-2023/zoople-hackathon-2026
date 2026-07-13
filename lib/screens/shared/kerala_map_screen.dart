import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/kerala_locations.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';
import '../../services/auth_service.dart';

/// Interactive OpenStreetMap displaying incident density across Kerala.
class KeralaMapScreen extends StatefulWidget {
  const KeralaMapScreen({super.key});

  @override
  State<KeralaMapScreen> createState() => _KeralaMapScreenState();
}

class _KeralaMapScreenState extends State<KeralaMapScreen> {
  final MapController _mapController = MapController();
  final List<CircleMarker> _densityCircles = [];
  final List<Marker> _mapMarkers = [];
  bool _isLoading = true;
  String? _userRole;
  final Set<String> _myReportIds = {};

  // Center on Kerala
  static const LatLng _keralaCenter = LatLng(
    KeralaLocations.keralaCenterLat,
    KeralaLocations.keralaCenterLng,
  );

  @override
  void initState() {
    super.initState();
    _loadIncidentDensity();
  }

  Future<void> _loadIncidentDensity() async {
    try {
      final reportService = context.read<ReportService>();
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;

      if (currentUser != null) {
        _userRole = (await authService.getCurrentUserProfile())?.role;

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

      // Fetch all reports to aggregate location density
      final reports = await reportService.allReportsStream().first;

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
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load home map density: $e');
      if (mounted) {
        setState(() => _isLoading = false);
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
                _detailRow('Priority', report.priority.toUpperCase()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Kerala Incident Heat Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadIncidentDensity();
            },
          ),
        ],
      ),
      body: Stack(
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
          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // Map legend panel
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _LegendItem(color: Colors.red, label: 'Critical (10+)'),
                  _LegendItem(color: Colors.orange, label: 'High (5-9)'),
                  _LegendItem(color: Colors.yellow, label: 'Moderate (2-4)'),
                  _LegendItem(color: Colors.green, label: 'Low (0-1)'),
                ],
              ),
            ),
          ),
        ],
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
          style: const TextStyle(fontSize: 10, color: AppColors.onSurface),
        ),
      ],
    );
  }
}
