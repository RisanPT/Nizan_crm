import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/letters/data/letter_models.dart';

class LetterService {
  final Dio _dio;
  LetterService(this._dio);

  Future<List<LetterTemplate>> getTemplates() async {
    try {
      final res = await _dio.get('/letters/templates');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => LetterTemplate.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load letter templates');
    }
  }

  Future<void> saveTemplate(Map<String, dynamic> body, {String? id}) async {
    try {
      if (id == null) {
        await _dio.post('/letters/templates', data: body);
      } else {
        await _dio.put('/letters/templates/$id', data: body);
      }
    } catch (e) {
      throw AppException(e, action: 'save template');
    }
  }

  Future<void> deleteTemplate(String id) async {
    try {
      await _dio.delete('/letters/templates/$id');
    } catch (e) {
      throw AppException(e, action: 'delete template');
    }
  }

  Future<List<GeneratedLetter>> getGenerated() async {
    try {
      final res = await _dio.get('/letters/generated');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => GeneratedLetter.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load letters');
    }
  }

  Future<void> generate({
    required String employeeId,
    String? templateId,
    String? body,
    String subject = '',
    String? type,
  }) async {
    try {
      await _dio.post('/letters/generate', data: {
        'type': ?type,
        'employeeId': employeeId,
        'templateId': ?templateId,
        'body': ?body,
        'subject': subject,
      });
    } catch (e) {
      throw AppException(e, action: 'generate letter');
    }
  }

  Future<void> deleteGenerated(String id) async {
    try {
      await _dio.delete('/letters/generated/$id');
    } catch (e) {
      throw AppException(e, action: 'delete letter');
    }
  }
}

final letterServiceProvider = Provider<LetterService>((ref) => LetterService(ref.watch(dioProvider)));

final letterTemplatesProvider =
    FutureProvider<List<LetterTemplate>>((ref) => ref.watch(letterServiceProvider).getTemplates());

final generatedLettersProvider =
    FutureProvider<List<GeneratedLetter>>((ref) => ref.watch(letterServiceProvider).getGenerated());
