import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import '../../core/models/employee.dart';
import '../../core/theme/crm_theme.dart';
import '../../services/employee_service.dart';
import '../../providers/dio_provider.dart';

class StaffDetailsScreen extends ConsumerStatefulWidget {
  final Employee employee;

  const StaffDetailsScreen({super.key, required this.employee});

  @override
  ConsumerState<StaffDetailsScreen> createState() => _StaffDetailsScreenState();
}

class _StaffDetailsScreenState extends ConsumerState<StaffDetailsScreen> {
  late Employee _employee;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _employee = widget.employee;
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      final Uint8List bytes = await image.readAsBytes();
      
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          bytes,
          filename: image.name,
        ),
      });

      final dio = ref.read(dioProvider);
      final response = await dio.post('/upload', data: formData);
      
      if (response.statusCode == 200) {
        final imageUrl = response.data['url'] as String;
        
        final updatedEmployee = await ref.read(employeeServiceProvider).saveEmployee(
          id: _employee.id,
          name: _employee.name,
          email: _employee.email,
          type: _employee.type,
          artistRole: _employee.artistRole,
          specialization: _employee.specialization,
          phone: _employee.phone,
          status: _employee.status,
          regionId: _employee.regionId,
          category: _employee.category,
          profileImage: imageUrl,
        );

        setState(() {
          _employee = updatedEmployee;
        });

        ref.invalidate(employeesProvider);
        ref.invalidate(paginatedEmployeesProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile image updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    
    final isArtist = _employee.artistRole == 'artist';
    final isDriver = _employee.artistRole == 'driver';
    
    final levelLabel = isArtist ? 'Artist' : (isDriver ? 'Driver' : 'Assistant');
    final levelColor = isArtist 
        ? crmColors.accent 
        : (isDriver ? crmColors.warning : crmColors.primary);
    final levelBackground = isArtist
        ? crmColors.accent.withValues(alpha: 0.12)
        : (isDriver ? crmColors.warning.withValues(alpha: 0.12) : crmColors.primary.withValues(alpha: 0.10));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Details'),
        backgroundColor: crmColors.surface,
        foregroundColor: crmColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: crmColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage: _employee.profileImage.isNotEmpty 
                        ? NetworkImage(_employee.profileImage) 
                        : null,
                    child: _employee.profileImage.isEmpty
                        ? Text(
                            _employee.name.isNotEmpty
                                ? _employee.name.substring(0, 1).toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 48,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _isUploading
                        ? const CircularProgressIndicator()
                        : CircleAvatar(
                            backgroundColor: crmColors.primary,
                            radius: 20,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              onPressed: _pickAndUploadImage,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _employee.name,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: crmColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: levelBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    levelLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: levelColor,
                    ),
                  ),
                ),
                if (_employee.type == 'in-house') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: crmColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'In-House',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: crmColors.accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: crmColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact & Role Information',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 32),
                    _buildInfoRow(Icons.phone, 'Phone', _employee.phone, crmColors),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.email, 'Email', _employee.email.isEmpty ? 'Not provided' : _employee.email, crmColors),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.work, 'Specialization', _employee.specialization.isEmpty ? 'None' : _employee.specialization, crmColors),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.location_on, 'Region', _employee.regionName.isEmpty ? 'Not assigned' : _employee.regionName, crmColors),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, dynamic crmColors) {
    return Row(
      children: [
        Icon(icon, color: crmColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: crmColors.textSecondary,
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: crmColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
