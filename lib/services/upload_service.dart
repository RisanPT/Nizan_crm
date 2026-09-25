import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/dio_provider.dart';
import '../core/error/errors.dart';

final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(ref.watch(dioProvider));
});

class UploadService {
  final Dio _dio;

  UploadService(this._dio);

  Future<String> uploadImage(XFile file) async {
    try {
      final fileName = file.name;
      final formData = FormData.fromMap({
        'image': kIsWeb
            ? MultipartFile.fromBytes(await file.readAsBytes(), filename: fileName)
            : await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _dio.post('/upload', data: formData);
      return response.data['url'] as String;
    } catch (e) {
      throw AppException(e, action: 'upload the image');
    }
  }
}
