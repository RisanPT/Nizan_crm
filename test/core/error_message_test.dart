import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/errors.dart';

DioException _dio(DioExceptionType type,
    {int? status, Object? data, Object? error, String? message}) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: type,
    error: error,
    message: message,
    response: status == null
        ? null
        : Response(requestOptions: req, statusCode: status, data: data),
  );
}

const offline =
    "Can't reach the server. Please check your internet connection and try again.";

void main() {
  group('friendlyErrorMessage', () {
    test('web network loss (connectionError) → offline message', () {
      final e = _dio(DioExceptionType.connectionError,
          message: 'The XMLHttpRequest onError callback was called.');
      expect(friendlyErrorMessage(e), offline);
      expect(isOfflineError(e), isTrue);
      expect(friendlyErrorTitle(e), "Can't connect");
    });

    test('web network loss arriving as unknown with XHR text → offline', () {
      final e = _dio(DioExceptionType.unknown,
          error: 'XMLHttpRequest error.', message: null);
      expect(friendlyErrorMessage(e), offline);
    });

    test('legacy Exception string with Dio network text → offline', () {
      final e = Exception(
          'Failed to load bookings: The connection errored: The XMLHttpRequest onError callback was called. This typically indicates an error on the network layer.');
      expect(friendlyErrorMessage(e), offline);
      expect(isOfflineError(e), isTrue);
    });

    test('legacy Exception string with status code → status message', () {
      final e = Exception(
          'Failed to save: This exception was thrown because the response has a status code of 403 and RequestOptions.validateStatus was configured to throw');
      expect(friendlyErrorMessage(e), "You don't have permission to do this.");
      expect(errorKind(e), 2);
    });

    test('backend message wins', () {
      final e = _dio(DioExceptionType.badResponse,
          status: 409, data: {'message': 'Phone number already exists'});
      expect(friendlyErrorMessage(e), 'Phone number already exists');
    });

    test('technical backend message is hidden', () {
      final e = _dio(DioExceptionType.badResponse,
          status: 500,
          data: {'message': 'Cast to ObjectId failed for value "x"'});
      expect(friendlyErrorMessage(e),
          'The server ran into a problem. Please try again in a moment.');
    });

    test('timeouts', () {
      expect(friendlyErrorMessage(_dio(DioExceptionType.connectionTimeout)),
          'The server is taking too long to respond. Please try again.');
    });

    test('plain human exception passes through', () {
      expect(friendlyErrorMessage(Exception('Please select a vendor')),
          'Please select a vendor');
    });
  });

  group('AppException', () {
    test('keeps the backend message from its cause', () {
      final e = AppException(
          _dio(DioExceptionType.badResponse,
              status: 400, data: {'message': 'Amount must be positive'}),
          action: 'save the expense');
      expect(e.toString(), 'Amount must be positive');
    });

    test('offline cause', () {
      final e = AppException(_dio(DioExceptionType.connectionError),
          action: 'load leads');
      expect(e.toString(), offline);
      expect(isOfflineError(e), isTrue);
    });

    test('unknown cause falls back to the action', () {
      final e = AppException(_dio(DioExceptionType.unknown),
          action: 'Failed to load payouts');
      expect(e.toString(), "Couldn't load payouts. Please try again.");
    });

    test('status-only cause', () {
      final e = AppException(_dio(DioExceptionType.badResponse, status: 404),
          action: 'load the lead');
      expect(e.message,
          "This isn't available right now. It may have been moved or removed.");
      expect(errorKind(e), 1);
    });
  });
}
