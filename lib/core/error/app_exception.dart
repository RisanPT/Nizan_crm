import 'error_message.dart';

/// The error type services should throw when an API call fails.
///
/// It KEEPS the original error ([cause], usually a `DioException`) so the UI
/// can still tell "no internet" from "server said: phone already exists" from
/// "you don't have permission" — information that is lost when a service
/// throws `Exception('Failed to X: ${e.message}')`.
///
/// ```dart
/// try {
///   final res = await _dio.get('/bookings');
///   ...
/// } catch (e) {
///   throw AppException(e, action: 'load bookings');
/// }
/// ```
///
/// [toString] returns the friendly, user-facing message, so even older UI code
/// that does `Text('$e')` shows something readable instead of a Dio dump.
class AppException implements Exception {
  const AppException(this.cause, {this.action});

  /// The underlying error (DioException, SocketException, …).
  final Object? cause;

  /// What was being attempted, as a short verb phrase: 'load bookings',
  /// 'save the lead'. Used when nothing more specific is known:
  /// "Couldn't load bookings. Please try again."
  final String? action;

  /// The user-facing message.
  String get message => friendlyErrorMessage(this);

  @override
  String toString() => message;
}
