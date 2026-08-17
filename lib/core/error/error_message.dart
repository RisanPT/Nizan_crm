import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

/// Turns ANY error object into a short, human-readable message safe to show a
/// user. It never leaks a stack trace or a framework/Dio dump.
///
/// Priority:
///  1. A short, human message the backend sent (`{ "message": "..." }`).
///  2. A message chosen from the network/HTTP failure kind.
///  3. [fallback] (or a generic line) for anything unrecognised.
///
/// Use this everywhere an error reaches the UI — `AsyncValue.error` branches,
/// catch blocks, snackbars — via [AppErrorView] / `showErrorSnackBar`, or
/// directly.
String friendlyErrorMessage(Object? error, {String? fallback}) {
  final generic = fallback ?? 'Something went wrong. Please try again.';
  if (error == null) return generic;

  if (error is DioException) return _fromDio(error, generic);
  if (error is SocketException) {
    return "Can't reach the server. Please check your internet connection and try again.";
  }
  if (error is TimeoutException) {
    return 'The server is taking too long to respond. Please try again.';
  }

  // Anything else (usually `Exception("...")` a service already threw). Strip
  // the "Exception:" prefix and reject anything that looks like a raw technical
  // dump so a leaked Dio/stack string can never reach the user.
  final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  if (raw.isEmpty || _looksTechnical(raw)) return generic;
  return raw;
}

bool _looksTechnical(String s) {
  if (s.length > 180) return true;
  const markers = [
    'RequestOptions',
    'DioException',
    'SocketException',
    'status code of',
    'validateStatus',
    'stack trace',
    '#0 ',
    'Null check operator',
    'type \'',
  ];
  return markers.any(s.contains);
}

String _fromDio(DioException e, String generic) {
  // 1. A short, human message from the backend wins.
  final data = e.response?.data;
  if (data is Map) {
    final m = data['message'] ?? data['error'];
    if (m is String && m.trim().isNotEmpty && m.trim().length <= 180) {
      return m.trim();
    }
  }

  // 2. Otherwise decide from the failure kind.
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'The server is taking too long to respond. Please try again.';
    case DioExceptionType.connectionError:
      return "Can't reach the server. Please check your internet connection and try again.";
    case DioExceptionType.badCertificate:
      return 'Could not establish a secure connection to the server.';
    case DioExceptionType.cancel:
      return 'The request was cancelled.';
    case DioExceptionType.badResponse:
      return _fromStatus(e.response?.statusCode, generic);
    case DioExceptionType.unknown:
      if (e.error is SocketException) {
        return "Can't reach the server. Please check your internet connection.";
      }
      return generic;
  }
}

String _fromStatus(int? code, String generic) {
  switch (code) {
    case 400:
      return "The request wasn't valid. Please check your input and try again.";
    case 401:
      return 'Your session has expired. Please log in again.';
    case 403:
      return "You don't have permission to do this.";
    case 404:
      return "This isn't available right now. It may have been moved or removed.";
    case 408:
      return 'The request timed out. Please try again.';
    case 409:
      return 'This conflicts with existing data. Please refresh and try again.';
    case 413:
      return 'That file is too large to upload.';
    case 422:
      return "Some of the information provided isn't valid.";
    case 429:
      return 'Too many requests. Please wait a moment and try again.';
    case 500:
    case 502:
    case 503:
    case 504:
      return 'The server ran into a problem. Please try again in a moment.';
    default:
      if (code != null && code >= 500) {
        return 'The server ran into a problem. Please try again in a moment.';
      }
      return generic;
  }
}

/// A short heading that pairs with the message (used by [AppErrorView]).
String friendlyErrorTitle(Object? error) {
  if (_isOffline(error)) return "Can't connect";
  final code = _statusOf(error);
  if (code == 404) return 'Not found';
  if (code == 403 || code == 401) return 'Access denied';
  if (code != null && code >= 500) return 'Server problem';
  return 'Something went wrong';
}

bool _isOffline(Object? error) {
  if (error is SocketException || error is TimeoutException) return true;
  if (error is DioException) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.error is SocketException;
  }
  return false;
}

int? _statusOf(Object? error) =>
    error is DioException ? error.response?.statusCode : null;

/// Which glyph best represents [error] — used by [AppErrorView].
/// (Kept here so both the widget and any custom UI stay consistent.)
int errorKind(Object? error) {
  if (_isOffline(error)) return 0; // offline / unreachable
  final code = _statusOf(error);
  if (code == 404) return 1; // not found
  if (code == 401 || code == 403) return 2; // denied
  if (code != null && code >= 500) return 3; // server
  return 4; // generic
}
