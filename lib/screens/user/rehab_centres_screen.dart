import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../constants/app_colors.dart';
import '../../constants/kerala_locations.dart';

class RehabCentresScreen extends StatefulWidget {
  const RehabCentresScreen({super.key});

  @override
  State<RehabCentresScreen> createState() => _RehabCentresScreenState();
}

class _RehabCentresScreenState extends State<RehabCentresScreen> {
  String? _selectedDistrict;
  String? _detectedDistrict;

  @override
  void initState() {
    super.initState();
    _detectCurrentDistrict();
  }

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
                  _detectedDistrict = district;
                  _selectedDistrict = district;
                });
              }
              break;
            }
          }
        }
      }
    } catch (_) {}
  }

  // Canned list of rehabilitation centres in Kerala
  final List<Map<String, String>> _centres = [
    {
      'name': 'Government De-Addiction Centre, TVM',
      'district': 'Thiruvananthapuram',
      'city': 'Thiruvananthapuram',
      'address': 'General Hospital Campus, Thiruvananthapuram',
      'phone': '+914712307874',
    },
    {
      'name': 'Government De-addiction Centre, Ernakulam',
      'district': 'Ernakulam',
      'city': 'Kochi',
      'address': 'General Hospital, Ernakulam',
      'phone': '+914842361251',
    },
    {
      'name': 'Government De-addiction Centre, Kozhikode',
      'district': 'Kozhikode',
      'city': 'Kozhikode',
      'address': 'Mental Health Centre Campus, Kuthiravattom, Kozhikode',
      'phone': '+914952741385',
    },
    {
      'name': 'Government De-Addiction Centre, Thrissur',
      'district': 'Thrissur',
      'city': 'Thrissur',
      'address': 'District Hospital, Thrissur',
      'phone': '+914872333060',
    },
    {
      'name': 'Government De-Addiction Centre, Kollam',
      'district': 'Kollam',
      'city': 'Kollam',
      'address': 'District Hospital, Kollam',
      'phone': '+914742795017',
    },
    {
      'name': 'Government De-Addiction Centre, Palakkad',
      'district': 'Palakkad',
      'city': 'Palakkad',
      'address': 'District Hospital, Palakkad',
      'phone': '+914912534430',
    },
    {
      'name': 'Government De-Addiction Centre, Kannur',
      'district': 'Kannur',
      'city': 'Kannur',
      'address': 'District Hospital, Kannur',
      'phone': '+914972734342',
    },
    {
      'name': 'Punarnava De-Addiction Centre',
      'district': 'Kottayam',
      'city': 'Kottayam',
      'address': 'Medical College Road, Kottayam',
      'phone': '+914812563612',
    },
  ];

  Future<void> _makeCall(String phone) async {
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> sortedCentres =
        List<Map<String, String>>.from(_centres)..sort((a, b) {
          if (_detectedDistrict != null) {
            final matchA = a['district'] == _detectedDistrict ? 0 : 1;
            final matchB = b['district'] == _detectedDistrict ? 0 : 1;
            return matchA.compareTo(matchB);
          }
          return 0;
        });

    // Filter centres based on selected district
    final filteredCentres = _selectedDistrict == null
        ? sortedCentres
        : sortedCentres
              .where((c) => c['district'] == _selectedDistrict)
              .toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Rehabilitation Centres')),
      body: Column(
        children: [
          // District Filter dropdown
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedDistrict,
              dropdownColor: AppColors.surfaceContainerHigh,
              decoration: const InputDecoration(
                labelText: 'Filter by District',
                prefixIcon: Icon(Icons.map_outlined),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Districts'),
                ),
                ...KeralaLocations.districts.map((d) {
                  return DropdownMenuItem<String>(value: d, child: Text(d));
                }),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedDistrict = val;
                });
              },
            ),
          ),

          // Centres List
          Expanded(
            child: filteredCentres.isEmpty
                ? Center(
                    child: Text(
                      'No centres found in this district.',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredCentres.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final centre = filteredCentres[index];
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
                            Text(
                              centre['name']!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'District: ${centre['district']!} • ${centre['city']!}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              centre['address']!,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _makeCall(centre['phone']!),
                                  icon: const Icon(Icons.phone, size: 16),
                                  label: const Text('Call Centre'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
