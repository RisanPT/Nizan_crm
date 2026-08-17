import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/error_message.dart';

DioException _resp(int code, {dynamic body}) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: code,
          data: body),
    );

void main() {
  group('friendlyErrorMessage', () {
    test('prefers a short human backend message', () {
      final e = _resp(400, body: {'message': 'Credit note number already exists'});
      expect(friendlyErrorMessage(e), 'Credit note number already exists');
    });

    test('404 without a body is humanised, never a dump', () {
      final msg = friendlyErrorMessage(_resp(404));
      expect(msg.toLowerCase(), contains("isn't available"));
      expect(msg, isNot(contains('status code')));
      expect(msg, isNot(contains('RequestOptions')));
    });

    test('500 → server problem', () {
      expect(friendlyErrorMessage(_resp(503)).toLowerCase(),
          contains('server ran into a problem'));
    });

    test('401 → session expired', () {
      expect(friendlyErrorMessage(_resp(401)).toLowerCase(),
          contains('session has expired'));
    });

    test('connection error → offline message', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );
      expect(friendlyErrorMessage(e).toLowerCase(), contains("can't reach the server"));
    });

    test('timeout → try again message', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.receiveTimeout,
      );
      expect(friendlyErrorMessage(e).toLowerCase(), contains('taking too long'));
    });

    test('strips the "Exception:" prefix from a plain thrown message', () {
      expect(friendlyErrorMessage(Exception('Please fill all fields')),
          'Please fill all fields');
    });

    test('a leaked Dio/technical dump falls back to the generic line', () {
      final dump = Exception(
          'This exception was thrown because the response has a status code of 404 and RequestOptions.validateStatus was configured to throw');
      final msg = friendlyErrorMessage(dump);
      expect(msg, isNot(contains('status code')));
      expect(msg, isNot(contains('RequestOptions')));
      expect(msg, 'Something went wrong. Please try again.');
    });

    test('uses the provided fallback for unrecognised errors', () {
      expect(friendlyErrorMessage(null, fallback: 'Could not load'),
          'Could not load');
    });

    test('title reflects the failure kind', () {
      expect(friendlyErrorTitle(_resp(404)), 'Not found');
      expect(friendlyErrorTitle(_resp(500)), 'Server problem');
      final offline = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );
      expect(friendlyErrorTitle(offline), "Can't connect");
    });
  });
}
