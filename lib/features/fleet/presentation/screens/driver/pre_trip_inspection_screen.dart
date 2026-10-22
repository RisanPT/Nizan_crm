import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';
import 'package:nizan_crm/services/upload_service.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

class PreTripInspectionScreen extends ConsumerStatefulWidget {
  final String jobId;
  const PreTripInspectionScreen({super.key, required this.jobId});

  @override
  ConsumerState<PreTripInspectionScreen> createState() =>
      _PreTripInspectionScreenState();
}

class _PreTripInspectionScreenState
    extends ConsumerState<PreTripInspectionScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  final Set<int> _uploadingIndexes = {};
  final _kmCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  static const int _minPhotos = 6;
  static const int _maxPhotos = 8;

  /// Starting odometer reading, or null until a valid number is entered.
  double? get _startKm {
    final v = double.tryParse(_kmCtrl.text.replaceAll(',', '').trim());
    return (v == null || v < 0) ? null : v;
  }

  /// This job, for the vehicle's last recorded km and staff assignments.
  FleetJob? get _job =>
      (ref.read(driverJobsProvider).value ?? const <FleetJob>[])
          .where((j) => j.id == widget.jobId)
          .firstOrNull;

  bool get _requiresOtp => _job?.requiresArtistOtp ?? false;
  bool get _hasValidOtp => !_requiresOtp || _otpCtrl.text.trim().length == 4;
  bool get _hasPhotos => _selectedImages.length >= _minPhotos;
  bool get _canStartTrip => _hasPhotos && _startKm != null && _hasValidOtp;

  @override
  void dispose() {
    _kmCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= _maxPhotos) {
      _showSnack('Maximum $_maxPhotos photos allowed.', isError: true);
      return;
    }
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // compress for faster upload
      );
      if (image != null && mounted) {
        setState(() => _selectedImages.add(image));
      }
    } catch (e) {
      _showSnack(
          friendlyErrorMessage(e,
              fallback: 'Could not open the camera. Please try again.'),
          isError: true);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_selectedImages.length >= _maxPhotos) {
      _showSnack('Maximum $_maxPhotos photos allowed.', isError: true);
      return;
    }
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 80);
      if (images.isNotEmpty && mounted) {
        final remaining = _maxPhotos - _selectedImages.length;
        setState(() {
          _selectedImages.addAll(images.take(remaining));
        });
      }
    } catch (e) {
      _showSnack(
          friendlyErrorMessage(e,
              fallback: 'Could not open the gallery. Please try again.'),
          isError: true);
    }
  }

  Future<void> _startTrip() async {
    if (!_canStartTrip || _isSubmitting) return;
    final startKm = _startKm!;

    // Odometers only go up — a reading below the last recorded one is
    // usually a typo, so make the driver confirm it.
    final lastKm = _job?.vehicleCurrentKm ?? 0;
    if (lastKm > 0 && startKm < lastKm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Check the km reading'),
          content: Text(
              'You entered ${formatKm(startKm)} km, which is less than this '
              "vehicle's last recorded reading of ${formatKm(lastKm)} km. "
              'Start the trip with ${formatKm(startKm)} km anyway?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Fix it')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Yes, it's correct")),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final uploadService = ref.read(uploadServiceProvider);
      final fleetService = ref.read(fleetServiceProvider);

      final List<String> photoUrls = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        setState(() => _uploadingIndexes.add(i));
        final url = await uploadService.uploadImage(_selectedImages[i]);
        photoUrls.add(url);
        if (mounted) setState(() => _uploadingIndexes.remove(i));
      }

      await fleetService.startTripWithInspection(
        widget.jobId,
        photoUrls,
        startKm: startKm,
        artistOtp: _requiresOtp ? _otpCtrl.text.trim() : null,
      );

      // ✅ Refresh the jobs provider so dashboard/works screen updates
      ref.refreshData
        ..fleetJobs()
        ..bookings(); // jobs are bookings (tripStatus)

      if (mounted) {
        _showSnack('Trip started! Drive safe 🚗');
        // Replace so user can't go back to inspection
        context.go('/driver/jobs');
      }
    } catch (e) {
      final msg = friendlyErrorMessage(e);
      if (mounted) {
        setState(() {
          _errorMessage = msg;
          _uploadingIndexes.clear();
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[700] : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _selectedImages.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProgressCard(count),
                  const SizedBox(height: 16),
                  if (_errorMessage != null) _buildErrorBanner(),
                  _buildPhotoGrid(count),
                  const SizedBox(height: 16),
                  _buildPickButtons(),
                  const SizedBox(height: 16),
                  _buildKmCard(),
                  if (_requiresOtp) ...[
                    const SizedBox(height: 16),
                    _buildOtpCard(),
                  ],
                  const SizedBox(height: 20),
                  _buildStartButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3A0F35), Color(0xFF6B1A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white70, size: 20),
              ),
              const SizedBox(width: 4),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pre-Trip Inspection',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  Text('Vehicle photo documentation',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(int count) {
    final progress = count / _minPhotos;
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt_outlined,
                  color: Color(0xFF4A1942), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Capture vehicle photos from all angles before starting the trip.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count / $_maxPhotos Photos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _hasPhotos ? const Color(0xFF2E7D32) : const Color(0xFF4A1942),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _hasPhotos
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                      : const Color(0xFFFF9800).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _hasPhotos
                      ? '✓ Photos done'
                      : 'Need ${_minPhotos - count} more',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _hasPhotos
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clampedProgress,
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                _hasPhotos ? const Color(0xFF4CAF50) : const Color(0xFF4A1942),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
          IconButton(
            onPressed: () => setState(() => _errorMessage = null),
            icon: const Icon(Icons.close, size: 16, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          )
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(int count) {
    final total = count + (count < _maxPhotos ? 1 : 0);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: total,
      itemBuilder: (context, index) {
        if (index == count) {
          return _buildAddPhotoTile();
        }
        return _buildPhotoTile(index);
      },
    );
  }

  Widget _buildAddPhotoTile() {
    return InkWell(
      onTap: _isSubmitting ? null : _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF4A1942).withValues(alpha: 0.06),
          border: Border.all(
              color: const Color(0xFF4A1942).withValues(alpha: 0.25),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_rounded, size: 32, color: Color(0xFF4A1942)),
            SizedBox(height: 4),
            Text('Add Photo',
                style:
                    TextStyle(fontSize: 11, color: Color(0xFF4A1942), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoTile(int index) {
    final isUploading = _uploadingIndexes.contains(index);
    final file = _selectedImages[index];

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: kIsWeb
              ? Image.network(file.path, fit: BoxFit.cover)
              : Image.file(File(file.path), fit: BoxFit.cover),
        ),
        if (isUploading)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            ),
          ),
        if (!isUploading && !_isSubmitting)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() => _selectedImages.removeAt(index)),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        // Photo number badge
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _pickImage,
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: const Text('Camera'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4A1942),
              side: const BorderSide(color: Color(0xFF4A1942)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Gallery'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4A1942),
              side: const BorderSide(color: Color(0xFF4A1942)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKmCard() {
    final lastKm = _job?.vehicleCurrentKm ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.speed_rounded, color: Color(0xFF4A1942), size: 20),
              SizedBox(width: 8),
              Text('Starting km',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              lastKm > 0
                  ? 'Enter the odometer reading now. '
                      'Last recorded: ${formatKm(lastKm)} km'
                  : 'Enter the odometer reading shown on the vehicle now.',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          TextField(
            controller: _kmCtrl,
            enabled: !_isSubmitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText:
                  lastKm > 0 ? 'e.g. ${formatKm(lastKm)}' : 'e.g. 45230',
              suffixText: 'km',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpCard() {
    final isOtpComplete = _otpCtrl.text.trim().length == 4;
    final isOtpError = _errorMessage != null &&
        (_errorMessage!.toLowerCase().contains('otp') ||
            _errorMessage!.toLowerCase().contains('verification'));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isOtpError
            ? Border.all(color: Colors.red.shade400, width: 1.5)
            : Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A1942).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF4A1942),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Artist Trip OTP',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      'Required before starting the trip',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A1942).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4A1942).withValues(alpha: 0.2),
                  ),
                ),
                child: const Text(
                  '4-DIGIT PIN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4A1942),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Ask the lead artist or assistant for the 4-digit OTP shown on their schedule or dashboard.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _otpCtrl,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 16,
              color: Color(0xFF1A1A2E),
            ),
            onChanged: (val) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
              setState(() {});
            },
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              hintStyle: TextStyle(
                fontSize: 26,
                letterSpacing: 16,
                color: Colors.grey.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isOtpError ? Colors.red : Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isOtpError
                      ? Colors.red
                      : isOtpComplete
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade300,
                  width: isOtpComplete ? 1.5 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF4A1942),
                  width: 2,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isOtpComplete
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: 14,
                color: isOtpComplete ? const Color(0xFF2E7D32) : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                isOtpComplete
                    ? '4-digit OTP entered'
                    : 'Enter all 4 digits provided by the artist',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isOtpComplete ? FontWeight.w700 : FontWeight.w500,
                  color: isOtpComplete
                      ? const Color(0xFF2E7D32)
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_canStartTrip && !_isSubmitting) ? _startTrip : null,
        icon: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Icon(Icons.play_arrow_rounded, size: 22),
        label: Text(
          _isSubmitting
              ? 'Uploading & Starting...'
              : !_hasPhotos
                  ? 'Add ${_minPhotos - _selectedImages.length} more photos'
                  : _startKm == null
                      ? 'Enter starting km'
                      : !_hasValidOtp
                          ? 'Enter 4-digit Artist OTP'
                          : 'Start Trip',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _canStartTrip ? const Color(0xFF4A1942) : Colors.grey[300],
          foregroundColor: _canStartTrip ? Colors.white : Colors.grey[600],
          disabledBackgroundColor: Colors.grey[200],
          disabledForegroundColor: Colors.grey[500],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: _canStartTrip ? 3 : 0,
        ),
      ),
    );
  }
}
