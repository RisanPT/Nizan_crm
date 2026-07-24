import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/features/fleet/services/fleet_service.dart';
import 'package:nizan_crm/services/upload_service.dart';

class AccidentReportScreen extends ConsumerStatefulWidget {
  final String jobId;
  final String vehicleId;
  const AccidentReportScreen({super.key, required this.jobId, required this.vehicleId});

  @override
  ConsumerState<AccidentReportScreen> createState() => _AccidentReportScreenState();
}

class _AccidentReportScreenState extends ConsumerState<AccidentReportScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _oppNameController = TextEditingController();
  final TextEditingController _oppPhoneController = TextEditingController();
  final TextEditingController _oppVehicleController = TextEditingController();
  final TextEditingController _oppNotesController = TextEditingController();
  bool _isSubmitting = false;
  bool _locating = true;
  bool _permBlocked = false;
  Position? _currentPosition;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  void _setLocError(String msg, {bool blocked = false}) {
    if (!mounted) return;
    setState(() {
      _locationError = msg;
      _permBlocked = blocked;
      _locating = false;
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    _oppNameController.dispose();
    _oppPhoneController.dispose();
    _oppVehicleController.dispose();
    _oppNotesController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    if (mounted) {
      setState(() {
        _locating = true;
        _locationError = null;
        _permBlocked = false;
      });
    }
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setLocError('Location (GPS) is turned off. Enable it, then Retry.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setLocError('Location permission denied. Tap Retry to allow it.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setLocError(
            'Location permission is blocked. Enable it in Settings, then Retry.',
            blocked: true);
        return;
      }

      // Bounded fix so we never hang on "Getting precise location…".
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        // High-accuracy fix timed out / failed — fall back to last known.
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        _setLocError('Could not get a location fix. Move to open sky and Retry.');
        return;
      }

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _locationError = null;
          _locating = false;
        });
      }
    } catch (e) {
      _setLocError('Failed to get location: $e');
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _selectedImages.add(image);
      });
    }
  }

  Future<void> _submitReport() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Location not captured yet — tap Retry under Incident Location.')),
      );
      return;
    }
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo of the accident.')),
      );
      return;
    }
    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a description.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final uploadService = ref.read(uploadServiceProvider);
      final fleetService = ref.read(fleetServiceProvider);
      
      List<String> photoUrls = [];
      for (var file in _selectedImages) {
        final url = await uploadService.uploadImage(file);
        photoUrls.add(url);
      }

      await fleetService.reportAccident(
        vehicleId: widget.vehicleId,
        jobId: widget.jobId,
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
        address: _addressController.text,
        photos: photoUrls,
        description: _descriptionController.text,
        oppositeName: _oppNameController.text,
        oppositePhone: _oppPhoneController.text,
        oppositeVehicle: _oppVehicleController.text,
        oppositeNotes: _oppNotesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accident reported successfully.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to report accident: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Accident'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.withValues(alpha:0.1),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please ensure you are safe before submitting this report.',
                      style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Incident Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_currentPosition != null)
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location captured · ${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                  TextButton(
                    onPressed: _locating ? null : _determinePosition,
                    child: const Text('Refresh'),
                  ),
                ],
              )
            else if (_locating)
              const Row(
                children: [
                  SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Getting precise location...'),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_off_outlined,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_locationError ?? 'Location unavailable.',
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _determinePosition,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                      ),
                      if (_permBlocked) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => Geolocator.openAppSettings(),
                          icon: const Icon(Icons.settings, size: 18),
                          label: const Text('Open Settings'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 16),
            const Text('Address / Landmark', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. near XYZ junction, MG Road',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Describe the accident...',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Other Party Involved (optional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _oppNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _oppPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.call_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _oppVehicleController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Vehicle no.',
                      prefixIcon: Icon(Icons.directions_car_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _oppNotesController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Notes (insurance, injuries…)',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Photos (Minimum 1)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._selectedImages.asMap().entries.map((entry) {
                  int idx = entry.key;
                  XFile file = entry.value;
                  return Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          image: DecorationImage(
                            image: kIsWeb 
                                ? NetworkImage(file.path) as ImageProvider
                                : FileImage(File(file.path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(idx);
                            });
                          },
                          child: Container(
                            color: Colors.black54,
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                InkWell(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                    ),
                    child: const Icon(Icons.add_a_photo, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Report', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
