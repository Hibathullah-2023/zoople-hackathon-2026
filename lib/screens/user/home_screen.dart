import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../constants/app_colors.dart';
import '../../constants/kerala_locations.dart';
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
  GoogleMapController? _mapController;
  final Set<Circle> _densityCircles = {};
  bool _isMapLoading = true;
  String _currentDistrict = 'Ernakulam'; // Default fallback

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
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position =
            await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
            );
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
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

  Future<void> _loadIncidentDensity() async {
    try {
      final reportService = context.read<ReportService>();
      reportService.allReportsStream().first.then((reports) {
        final Map<String, int> districtCounts = {};

        for (final report in reports) {
          if (report.district != null) {
            districtCounts[report.district!] =
                (districtCounts[report.district!] ?? 0) + 1;
          }
        }

        final Set<Circle> circles = {};

        districtCounts.forEach((district, count) {
          final centerCoords = KeralaLocations.districtCenters[district];
          if (centerCoords != null) {
            final latLng = LatLng(centerCoords[0], centerCoords[1]);
            double radius = 10000 + (count * 2000).toDouble();
            if (radius > 40000) radius = 40000;

            Color circleColor = Colors.green;
            if (count >= 10) {
              circleColor = Colors.red;
            } else if (count >= 5) {
              circleColor = Colors.orange;
            } else if (count >= 2) {
              circleColor = Colors.yellow;
            }

            circles.add(
              Circle(
                circleId: CircleId(district),
                center: latLng,
                radius: radius,
                fillColor: circleColor.withValues(alpha: 0.35),
                strokeColor: circleColor,
                strokeWidth: 2,
                consumeTapEvents: true,
                onTap: () {
                  _showDistrictDetails(district, count);
                },
              ),
            );
          }
        });

        if (mounted) {
          setState(() {
            _densityCircles.clear();
            _densityCircles.addAll(circles);
            _isMapLoading = false;
          });
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isMapLoading = false);
      }
    }
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

  void _showDistrictDetails(String district, int count) {
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
              Text(
                '$district District',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.warning, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(
                    'Total Reported Incidents: $count',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Status: ${count >= 10
                    ? "Critical Density"
                    : count >= 5
                    ? "High Density"
                    : "Moderate Density"}',
                style: TextStyle(
                  color: count >= 10
                      ? AppColors.priorityCritical
                      : count >= 5
                      ? AppColors.priorityHigh
                      : AppColors.priorityLow,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final reportService = context.read<ReportService>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.shield, color: AppColors.primary, size: 24),
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
                    GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(10.5276, 76.2144),
                        zoom: 7.2,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _mapController?.setMapStyle(_darkMapStyle);
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(_keralaCenter, 7.2),
                        );
                      },
                      circles: _densityCircles,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      myLocationEnabled: false,
                    ),
                    if (_isMapLoading)
                      const Center(child: CircularProgressIndicator()),
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
              itemCount: _emergencyContacts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final office = _emergencyContacts[index];
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
                          Container(
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
                            ),
                          ),
                          const Spacer(),
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

  // Dark Map Style JSON string to customize Google Maps
  static const String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#121e30"
        }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#746855"
        }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#242f3e"
        }
      ]
    },
    {
      "featureType": "administrative.locality",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#d59563"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#d59563"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#172b38"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#6b9a76"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#243548"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#182635"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#9ca5b3"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#2c3e50"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#1f2d3d"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#f3c159"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#09121f"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#515c6d"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#17263c"
        }
      ]
    }
  ]
  ''';
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
