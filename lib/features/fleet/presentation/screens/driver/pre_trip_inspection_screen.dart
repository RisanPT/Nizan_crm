import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/services/upload_service.dart';

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
  bool _isSubmitting = false;
  String? _errorMessage;

  static const int _minPhotos = 6;
  static const int _maxPhotos = 8;

  bool get _canStartTrip => _selectedImages.length >= _minPhotos;

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
      _showSnack('Camera error: $e', isError: true);
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
      _showSnack('Gallery error: $e', isError: true);
    }
  }

  Future<void> _startTrip() async {
    if (!_canStartTrip || _isSubmitting) return;

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

      await fleetService.startTripWithInspection(widget.jobId, photoUrls);

      // ✅ Refresh the jobs provider so dashboard/works screen updates
      ref.invalidate(driverJobsProvider);

      if (mounted) {
        _showSnack('Trip started! Drive safe 🚗');
        // Replace so user can't go back to inspection
        context.go('/driver/jobs');
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        setState(() {
          _errorMessage = msg;
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
                  color: _canStartTrip ? const Color(0xFF2E7D32) : const Color(0xFF4A1942),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _canStartTrip
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                      : const Color(0xFFFF9800).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _canStartTrip
                      ? '✓ Ready to start'
                      : 'Need ${_minPhotos - count} more',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _canStartTrip
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
                _canStartTrip ? const Color(0xFF4CAF50) : const Color(0xFF4A1942),
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
              : _canStartTrip
                  ? 'Start Trip'
                  : 'Add ${_minPhotos - _selectedImages.length} more photos',
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
