import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/kerala_locations.dart';
import '../../services/report_service.dart';

/// Interactive Google Map displaying incident density across Kerala.
class KeralaMapScreen extends StatefulWidget {
  const KeralaMapScreen({super.key});

  @override
  State<KeralaMapScreen> createState() => _KeralaMapScreenState();
}

class _KeralaMapScreenState extends State<KeralaMapScreen> {
  GoogleMapController? _mapController;
  final Set<Circle> _densityCircles = {};
  bool _isLoading = true;

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

      // Fetch all reports to aggregate location density
      // In a production app, we would query aggregated counts from Firestore.
      // For MVP, we stream/fetch reports and compute densities dynamically.
      reportService.allReportsStream().first.then((reports) {
        final Map<String, int> districtCounts = {};

        // Count reports per district
        for (final report in reports) {
          if (report.district != null) {
            districtCounts[report.district!] =
                (districtCounts[report.district!] ?? 0) + 1;
          }
        }

        final Set<Circle> circles = {};

        // Generate map circles based on density
        districtCounts.forEach((district, count) {
          final centerCoords = KeralaLocations.districtCenters[district];
          if (centerCoords != null) {
            final latLng = LatLng(centerCoords[0], centerCoords[1]);

            // Set circle size and color based on density
            double radius = 10000 + (count * 2000).toDouble(); // meters
            if (radius > 40000) radius = 40000; // Cap max radius

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
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target:
                  _kSimpleCenter, // fallback target if controller not loaded
              zoom: 7.2,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              // Apply Dark Theme to map for Nizhal styling matching app aesthetics
              _mapController?.setMapStyle(_darkMapStyle);
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(_keralaCenter, 7.2),
              );
            },
            circles: _densityCircles,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
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

  static const LatLng _kSimpleCenter = LatLng(10.5276, 76.2144);

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
