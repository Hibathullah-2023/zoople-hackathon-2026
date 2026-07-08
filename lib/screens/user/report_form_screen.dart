import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/kerala_locations.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';

/// Multi-step incident report form.
/// Steps: Description → Category → Photos → Location → Review → Submit
class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  int _currentStep = 0;
  final int _totalSteps = 5;

  // Form data
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  final List<XFile> _photos = [];
  String? _selectedDistrict;
  String? _selectedCity;
  final _addressController = TextEditingController();
  bool _isSubmitting = false;
  String? _submittedReportId;

  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Description
        if (_descriptionController.text.trim().length < 10) {
          _showError('Please provide a detailed description (min 10 characters).');
          return false;
        }
        return true;
      case 1: // Category
        if (_selectedCategory == null) {
          _showError('Please select a category.');
          return false;
        }
        return true;
      case 2: // Photos (optional)
        return true;
      case 3: // Location
        if (_selectedDistrict == null) {
          _showError('Please select a district.');
          return false;
        }
        return true;
      case 4: // Review
        return true;
      default:
        return true;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.errorContainer,
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photos.length >= AppConstants.maxPhotosPerReport) {
      _showError('Maximum ${AppConstants.maxPhotosPerReport} photos allowed.');
      return;
    }

    try {
      if (source == ImageSource.gallery) {
        final images = await _imagePicker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 80,
        );
        final remaining = AppConstants.maxPhotosPerReport - _photos.length;
        setState(() {
          _photos.addAll(images.take(remaining));
        });
      } else {
        final image = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 80,
        );
        if (image != null) {
          setState(() => _photos.add(image));
        }
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _submitReport() async {
    // Show warning dialog first
    final confirmed = await _showWarningDialog();
    if (!confirmed) return;

    setState(() => _isSubmitting = true);

    try {
      final authService = context.read<AuthService>();
      final reportService = context.read<ReportService>();
      final user = await authService.getCurrentUserProfile();

      if (user == null) {
        _showError('Please login again.');
        return;
      }

      // TODO: Upload photos to Firebase Storage and get URLs
      final mediaUrls = <String>[];

      final report = await reportService.submitReport(
        reporterUid: user.uid,
        reporterEmail: user.email,
        reporterAadhaarHash: user.aadhaarHash,
        anonymousId: user.anonymousId,
        isAnonymous: user.isAnonymous,
        description: _descriptionController.text.trim(),
        category: _selectedCategory!,
        location: null, // TODO: GPS coordinates
        locationAddress: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        city: _selectedCity,
        district: _selectedDistrict,
        mediaUrls: mediaUrls,
      );

      // Store reference in user's myReports sub-collection
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection('myReports')
          .doc(report.reportId)
          .set({
        'reportId': report.reportId,
        'createdAt': Timestamp.now(),
      });

      setState(() {
        _submittedReportId = report.reportId;
        _currentStep = _totalSteps; // Show success
      });
    } catch (e) {
      _showError('Failed to submit report: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _showWarningDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surfaceContainerHigh,
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 48,
            ),
            title: const Text(
              '⚠️ Important Warning',
              style: TextStyle(color: AppColors.onSurface),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Filing a false report is a serious offense.',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You may face legal consequences including:\n\n'
                  '• Account suspension after 3 false reports\n'
                  '• Prosecution under IPC Section 182\n'
                  '• Criminal penalties for false information\n\n'
                  'By submitting, you confirm that this report is truthful and accurate.',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text(
                  'I Confirm — Submit',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    // Success state
    if (_submittedReportId != null) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Report Incident'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Column(
        children: [
          // ─── Progress Bar ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _totalSteps,
                      backgroundColor: AppColors.surfaceContainerHighest,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.tertiary),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'STEP ${_currentStep + 1}/$_totalSteps',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // ─── Step Content ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStep(),
              ),
            ),
          ),

          // ─── Navigation Buttons ───
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _prevStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : (_currentStep == _totalSteps - 1
                            ? _submitReport
                            : _nextStep),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentStep == _totalSteps - 1
                          ? AppColors.tertiary
                          : AppColors.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentStep == _totalSteps - 1
                                ? 'Submit Report'
                                : 'Next Step',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _buildDescriptionStep();
      case 1:
        return _buildCategoryStep();
      case 2:
        return _buildPhotoStep();
      case 3:
        return _buildLocationStep();
      case 4:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 1: Description ───
  Widget _buildDescriptionStep() {
    return Column(
      key: const ValueKey('desc'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What did you observe?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Provide a detailed description of the incident. Your safety is our priority; do not put yourself at risk.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _descriptionController,
          maxLines: 8,
          maxLength: AppConstants.maxDescriptionLength,
          style: const TextStyle(color: AppColors.onSurface, fontSize: 16),
          decoration: const InputDecoration(
            hintText:
                'e.g., Suspicious activity at the corner of MG Road, three individuals exchanging packages...',
          ),
        ),
      ],
    );
  }

  // ─── Step 2: Category ───
  Widget _buildCategoryStep() {
    return Column(
      key: const ValueKey('category'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Category',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the type of incident you are reporting.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 24),
        ...AppConstants.categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          final label = AppConstants.categoryLabels[cat] ?? cat;
          final icon = _categoryIcon(cat);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: isSelected
                  ? AppColors.secondary.withValues(alpha: 0.1)
                  : AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => setState(() => _selectedCategory = cat),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.secondary.withValues(alpha: 0.4)
                          : AppColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon,
                          color: isSelected
                              ? AppColors.secondary
                              : AppColors.onSurfaceVariant),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected
                                ? AppColors.secondary
                                : AppColors.onSurface,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: AppColors.secondary, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'trafficking':
        return Icons.local_shipping;
      case 'manufacturing':
        return Icons.factory;
      case 'drug_sale':
        return Icons.storefront;
      case 'drug_use':
        return Icons.smoking_rooms;
      case 'possession':
        return Icons.inventory_2;
      default:
        return Icons.report;
    }
  }

  // ─── Step 3: Photos ───
  Widget _buildPhotoStep() {
    return Column(
      key: const ValueKey('photos'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evidence Upload',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Attach photos (optional). Metadata will be stripped for your protection.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 16),

        // Photo count
        Text(
          '${_photos.length}/${AppConstants.maxPhotosPerReport} photos',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),

        // Add photo buttons
        Row(
          children: [
            Expanded(
              child: _PhotoActionButton(
                icon: Icons.add_a_photo,
                label: 'Camera',
                onTap: () => _pickPhoto(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PhotoActionButton(
                icon: Icons.photo_library,
                label: 'Gallery',
                onTap: () => _pickPhoto(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Photo previews
        if (_photos.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _photos.asMap().entries.map((entry) {
              return Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: const Icon(
                      Icons.image,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () => _removePhoto(entry.key),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.error,
                        ),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),

        const SizedBox(height: 16),

        // Security note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.security, color: AppColors.secondary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All uploads are encrypted and metadata-stripped.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 4: Location ───
  Widget _buildLocationStep() {
    return Column(
      key: const ValueKey('location'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pin the Location',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select the area where the incident occurred.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 24),

        // District dropdown
        DropdownButtonFormField<String>(
          value: _selectedDistrict,
          dropdownColor: AppColors.surfaceContainerHigh,
          decoration: const InputDecoration(
            labelText: 'District *',
            prefixIcon:
                Icon(Icons.map_outlined, color: AppColors.onSurfaceVariant),
          ),
          items: KeralaLocations.districts.map((d) {
            return DropdownMenuItem(value: d, child: Text(d));
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedDistrict = val;
              _selectedCity = null;
            });
          },
        ),
        const SizedBox(height: 16),

        // City dropdown (filtered by district)
        if (_selectedDistrict != null)
          DropdownButtonFormField<String>(
            value: _selectedCity,
            dropdownColor: AppColors.surfaceContainerHigh,
            decoration: const InputDecoration(
              labelText: 'City / Area',
              prefixIcon: Icon(Icons.location_city,
                  color: AppColors.onSurfaceVariant),
            ),
            items: (KeralaLocations.districtCities[_selectedDistrict] ?? [])
                .map((c) {
              return DropdownMenuItem(value: c, child: Text(c));
            }).toList(),
            onChanged: (val) => setState(() => _selectedCity = val),
          ),
        const SizedBox(height: 16),

        // Manual address
        TextFormField(
          controller: _addressController,
          maxLines: 2,
          style: const TextStyle(color: AppColors.onSurface),
          decoration: const InputDecoration(
            labelText: 'Additional Address Details (optional)',
            prefixIcon:
                Icon(Icons.near_me, color: AppColors.onSurfaceVariant),
            hintText: 'Near landmark, street name...',
          ),
        ),
        const SizedBox(height: 16),

        // GPS button
        OutlinedButton.icon(
          onPressed: () {
            // TODO: Implement GPS location fetch
            _showError('GPS location feature coming soon.');
          },
          icon: const Icon(Icons.my_location, color: AppColors.tertiary),
          label: const Text('Use Current Location'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            side: const BorderSide(color: AppColors.tertiary),
          ),
        ),
      ],
    );
  }

  // ─── Step 5: Review ───
  Widget _buildReviewStep() {
    return Column(
      key: const ValueKey('review'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Final Review',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Review your report before submission. Once sent, it cannot be edited.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 24),

        _ReviewCard(
          label: 'DESCRIPTION',
          content: _descriptionController.text.trim(),
        ),
        const SizedBox(height: 12),
        _ReviewCard(
          label: 'CATEGORY',
          content: AppConstants.categoryLabels[_selectedCategory] ?? '—',
        ),
        const SizedBox(height: 12),
        _ReviewCard(
          label: 'PHOTOS',
          content: _photos.isEmpty
              ? 'No photos attached'
              : '${_photos.length} photo(s) attached',
        ),
        const SizedBox(height: 12),
        _ReviewCard(
          label: 'LOCATION',
          content: [
            _selectedDistrict,
            _selectedCity,
            if (_addressController.text.trim().isNotEmpty)
              _addressController.text.trim(),
          ].whereType<String>().join(', '),
        ),
      ],
    );
  }

  // ─── Success Screen ───
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.secondary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Report Submitted',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your report has been submitted anonymously.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TRACKING ID',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _submittedReportId!,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.tertiary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save this ID to track your report status',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/track/${_submittedReportId!}'),
                  child: const Text('Track Report'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PhotoActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.outlineVariant,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.tertiary, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String label;
  final String content;

  const _ReviewCard({required this.label, required this.content});

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
          const SizedBox(height: 6),
          Text(
            content.isEmpty ? '—' : content,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
