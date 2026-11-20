import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/footage_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/providers/dio_provider.dart';

/// Footage from works (backend /api/work-footage): the artist hands in the Dropbox link of a work's videos (or uploads through the
/// work's Dropbox upload page when Dropbox is connected); Marketing sees it in Creative Portfolio → Footage. A refusal from the server
/// (a link that is not Dropbox, a day still to come…) arrives as [TeamRefusal] with its reason.
class FootageService {
  FootageService(this._dio);
  final Dio _dio;

  Future<T> _call<T>(String action, Future<Response<dynamic>> Function() run, T Function(Map<String, dynamic>) parse) async {
    try {
      final res = await run();
      return parse(res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{});
    } on DioException catch (e) {
      final data = e.response?.data;
      final status = e.response?.statusCode;
      if (status != null && [400, 403, 404, 409, 429, 502].contains(status) && data is Map && data['message'] != null) throw TeamRefusal(data['message'].toString(), status: status);
      throw AppException(e, action: action);
    } catch (e) {
      throw AppException(e, action: action);
    }
  }

  Future<BookingFootage> booking(String bookingId) => _call('load the footage', () => _dio.get('/work-footage/booking/$bookingId'), BookingFootage.fromJson);
  Future<BookingFootage> addLink(String bookingId, {required String day, required String url, String label = ''}) =>
      _call('add the footage link', () => _dio.post('/work-footage/booking/$bookingId/links', data: {'day': day, 'url': url, 'label': label}), BookingFootage.fromJson);
  Future<BookingFootage> removeLink(String bookingId, String linkId) => _call('remove the link', () => _dio.delete('/work-footage/booking/$bookingId/links/$linkId'), BookingFootage.fromJson);

  /// The work's Dropbox upload page (Dropbox connected on the server).
  Future<String> uploadPage(String bookingId, String day) => _call('open the upload page', () => _dio.post('/work-footage/booking/$bookingId/upload-page', data: {'day': day}), (j) => j['url']?.toString() ?? '');

  /// Look in the work's Dropbox folder for what was uploaded → the booking's footage and how many files were found.
  Future<(BookingFootage, int)> checkUpload(String bookingId, String day) =>
      _call('check the upload', () => _dio.post('/work-footage/booking/$bookingId/check', data: {'day': day}), (j) => (BookingFootage.fromJson(j), (j['found'] as num?)?.toInt() ?? 0));

  Future<FootageInbox> inbox({String status = 'all'}) => _call('load the footage', () => _dio.get('/work-footage/inbox', queryParameters: {if (status != 'all') 'status': status}), FootageInbox.fromJson);

  /// Hand the footage to an editor ([editorMemberId], a task on their Team Dashboard) or mark it edited / new.
  Future<void> setStatus(String id, String status, {String? editorMemberId}) =>
      _call('change the footage', () => _dio.patch('/work-footage/$id', data: {'status': status, 'editorMemberId': ?editorMemberId}), (_) {});
}

final footageServiceProvider = Provider<FootageService>((ref) => FootageService(ref.watch(dioProvider)));
final bookingFootageProvider = FutureProvider.autoDispose.family<BookingFootage, String>((ref, id) => ref.watch(footageServiceProvider).booking(id), retry: (_, _) => null);
final footageInboxProvider = FutureProvider.autoDispose.family<FootageInbox, String>((ref, status) => ref.watch(footageServiceProvider).inbox(status: status), retry: (_, _) => null);

void refreshFootage(WidgetRef ref) {
  ref.invalidate(bookingFootageProvider);
  ref.invalidate(footageInboxProvider);
}
