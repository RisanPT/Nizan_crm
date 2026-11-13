import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/recruitment/data/recruitment_models.dart';

class RecruitmentService {
  final Dio _dio;
  RecruitmentService(this._dio);

  // Job posts
  Future<List<JobPost>> getJobPosts() async {
    try {
      final res = await _dio.get('/recruitment/job-posts');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => JobPost.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load job posts');
    }
  }

  Future<void> saveJobPost(Map<String, dynamic> body, {String? id}) async {
    try {
      if (id == null) {
        await _dio.post('/recruitment/job-posts', data: body);
      } else {
        await _dio.put('/recruitment/job-posts/$id', data: body);
      }
    } catch (e) {
      throw AppException(e, action: 'save job post');
    }
  }

  Future<void> deleteJobPost(String id) async {
    try {
      await _dio.delete('/recruitment/job-posts/$id');
    } catch (e) {
      throw AppException(e, action: 'delete job post');
    }
  }

  // Candidates
  Future<List<Candidate>> getCandidates({String? stage, String? jobPostId}) async {
    try {
      final res = await _dio.get('/recruitment/candidates', queryParameters: {
        'stage': ?stage,
        'jobPostId': ?jobPostId,
      });
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => Candidate.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load candidates');
    }
  }

  Future<void> saveCandidate(Map<String, dynamic> body, {String? id}) async {
    try {
      if (id == null) {
        await _dio.post('/recruitment/candidates', data: body);
      } else {
        await _dio.put('/recruitment/candidates/$id', data: body);
      }
    } catch (e) {
      throw AppException(e, action: 'save candidate');
    }
  }

  Future<void> deleteCandidate(String id, {bool deleteLinkedEmployee = false}) async {
    try {
      await _dio.delete(
        '/recruitment/candidates/$id',
        queryParameters: {
          if (deleteLinkedEmployee) 'deleteLinkedEmployee': 'true',
        },
      );
    } catch (e) {
      throw AppException(e, action: 'delete candidate');
    }
  }

  // Offers
  Future<List<Offer>> getOffers() async {
    try {
      final res = await _dio.get('/recruitment/offers');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => Offer.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load offers');
    }
  }

  Future<void> createOffer(Map<String, dynamic> body) async {
    try {
      await _dio.post('/recruitment/offers', data: body);
    } catch (e) {
      throw AppException(e, action: 'create offer');
    }
  }

  Future<void> acceptOffer(String id) async {
    try {
      await _dio.post('/recruitment/offers/$id/accept');
    } catch (e) {
      throw AppException(e, action: 'accept offer');
    }
  }

  Future<void> declineOffer(String id) async {
    try {
      await _dio.post('/recruitment/offers/$id/decline');
    } catch (e) {
      throw AppException(e, action: 'decline offer');
    }
  }

  Future<void> deleteOffer(String id, {bool deleteLinkedEmployee = false}) async {
    try {
      await _dio.delete(
        '/recruitment/offers/$id',
        queryParameters: {
          if (deleteLinkedEmployee) 'deleteLinkedEmployee': 'true',
        },
      );
    } catch (e) {
      throw AppException(e, action: 'delete offer');
    }
  }

  // Job Roles & Organizational Hierarchy (FR-1.1 - FR-1.3)
  Future<List<JobRole>> getJobRoles() async {
    try {
      final res = await _dio.get('/recruitment/roles');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => JobRole.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load job roles');
    }
  }

  Future<void> saveJobRole(Map<String, dynamic> body, {String? id}) async {
    try {
      if (id == null) {
        await _dio.post('/recruitment/roles', data: body);
      } else {
        await _dio.put('/recruitment/roles/$id', data: body);
      }
    } catch (e) {
      throw AppException(e, action: 'save job role');
    }
  }

  Future<void> deleteJobRole(String id) async {
    try {
      await _dio.delete('/recruitment/roles/$id');
    } catch (e) {
      throw AppException(e, action: 'archive job role');
    }
  }

  // Hiring Plans / Requisitions (FR-1.1 - FR-1.5)
  Future<List<HiringPlan>> getHiringPlans() async {
    try {
      final res = await _dio.get('/recruitment/plans');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => HiringPlan.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load hiring plans');
    }
  }

  Future<void> saveHiringPlan(Map<String, dynamic> body, {String? id}) async {
    try {
      if (id == null) {
        await _dio.post('/recruitment/plans', data: body);
      } else {
        await _dio.put('/recruitment/plans/$id', data: body);
      }
    } catch (e) {
      throw AppException(e, action: 'save hiring plan');
    }
  }

  Future<void> raiseHiringPlan(String id) async {
    try {
      await _dio.post('/recruitment/plans/$id/raise');
    } catch (e) {
      throw AppException(e, action: 'raise hiring plan');
    }
  }

  /// Approve (vet) a plan. → true when the plan was sent on to the CEO / Executive Director instead of being approved here.
  Future<bool> approveHiringPlan(String id) async {
    try {
      final res = await _dio.post('/recruitment/plans/$id/approve');
      final data = res.data;
      return data is Map && data['awaitingLeadership'] == true;
    } catch (e) {
      throw AppException(e, action: 'approve hiring plan');
    }
  }

  Future<void> rejectHiringPlan(String id, {String? reason}) async {
    try {
      await _dio.post('/recruitment/plans/$id/reject', data: {'reason': reason ?? 'Rejected'});
    } catch (e) {
      throw AppException(e, action: 'reject hiring plan');
    }
  }

  Future<void> deleteHiringPlan(String id) async {
    try {
      await _dio.delete('/recruitment/plans/$id');
    } catch (e) {
      throw AppException(e, action: 'delete hiring plan');
    }
  }

  // Social automation & Webhooks
  Future<Map<String, dynamic>> getSocialCopy(String jobPostId) async {
    try {
      final res = await _dio.get('/recruitment/job-posts/$jobPostId/social-copy');
      return res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : {};
    } catch (e) {
      throw AppException(e, action: 'load social copy');
    }
  }

  Future<Map<String, dynamic>> getWebhookConfig() async {
    try {
      final res = await _dio.get('/recruitment/webhook-config');
      return res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : {};
    } catch (e) {
      throw AppException(e, action: 'load webhook config');
    }
  }

  Future<Map<String, dynamic>> bulkImportCandidates({
    required List<Map<String, dynamic>> candidates,
    String? jobPostId,
    String? source,
    String? campaignName,
  }) async {
    try {
      final res = await _dio.post('/recruitment/candidates/bulk-import', data: {
        'candidates': candidates,
        'jobPostId': ?jobPostId,
        'source': ?source,
        'campaignName': ?campaignName,
      });
      return res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : {};
    } catch (e) {
      throw AppException(e, action: 'bulk import candidates');
    }
  }
}

final recruitmentServiceProvider =
    Provider<RecruitmentService>((ref) => RecruitmentService(ref.watch(dioProvider)));

final jobPostsProvider = FutureProvider<List<JobPost>>((ref) => ref.watch(recruitmentServiceProvider).getJobPosts());

final candidatesProvider = FutureProvider<List<Candidate>>((ref) => ref.watch(recruitmentServiceProvider).getCandidates());

final offersProvider = FutureProvider<List<Offer>>((ref) => ref.watch(recruitmentServiceProvider).getOffers());

final jobRolesProvider = FutureProvider<List<JobRole>>((ref) => ref.watch(recruitmentServiceProvider).getJobRoles());

final hiringPlansProvider = FutureProvider<List<HiringPlan>>((ref) => ref.watch(recruitmentServiceProvider).getHiringPlans());
