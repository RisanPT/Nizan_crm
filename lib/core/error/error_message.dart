import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'app_exception.dart';

const _offlineMsg =
    "Can't reach the server. Please check your internet connection and try again.";
const _timeoutMsg = 'The server is taking too long to respond. Please try again.';

/// Turns ANY error object into a short, human-readable message safe to show a
/// user. It never leaks a stack trace or a framework/Dio dump.
///
/// Priority:
///  1. A short, human message the backend sent (`{ "message": "..." }`).
///  2. A message chosen from the network/HTTP failure kind.
///  3. For an [AppException] with an action: "Couldn't {action}. Please try again."
///  4. [fallback] (or a generic line) for anything unrecognised.
///
/// Use this everywhere an error reaches the UI — `AsyncValue.error` branches,
/// catch blocks, snackbars — via [AppErrorView] / `showErrorSnackBar`, or
/// directly.
String friendlyErrorMessage(Object? error, {String? fallback}) {
  if (error is AppException) {
    final generic = fallback ?? _actionMessage(error.action);
    // Guard against an AppException wrapping itself.
    final cause = error.cause is AppException
        ? (error.cause as AppException).cause
        : error.cause;
    if (cause == null) return generic;
    return friendlyErrorMessage(cause, fallback: generic);
  }

  final generic = fallback ?? 'Something went wrong. Please try again.';
  if (error == null) return generic;

  if (error is DioException) return _fromDio(error, generic);
  if (error is SocketException) return _offlineMsg;
  if (error is TimeoutException) return _timeoutMsg;

  // Anything else (usually `Exception("...")` a service already threw). Strip
  // the "Exception:" prefix, recognise network/HTTP failures that older
  // services embedded in the text, and reject anything that looks like a raw
  // technical dump so a leaked Dio/stack string can never reach the user.
  final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  if (raw.isEmpty) return generic;
  final kind = _kindFromText(raw);
  if (kind == _Kind.offline) return _offlineMsg;
  if (kind == _Kind.timeout) return _timeoutMsg;
  final code = _statusFromText(raw);
  if (code != null) return _fromStatus(code, generic);
  if (_looksTechnical(raw)) return generic;
  return raw;
}

String _actionMessage(String? action) {
  if (action == null || action.trim().isEmpty) {
    return 'Something went wrong. Please try again.';
  }
  var a = action.trim();
  a = a.replaceFirst(RegExp(r'^(failed|unable|could not|couldn.t) to\s+', caseSensitive: false), '');
  if (a.endsWith('.')) a = a.substring(0, a.length - 1);
  return "Couldn't $a. Please try again.";
}

enum _Kind { offline, timeout, other }

/// Recognises connection failures from their text. Dio's own messages (on web
/// the XHR "onError callback" text) and dart:io socket errors end up inside
/// plain `Exception` strings in older services, so match on the words.
_Kind _kindFromText(String s) {
  final t = s.toLowerCase();
  const offline = [
    'xmlhttprequest',
    'connection error',
    'connection errored',
    'connectionerror',
    'failed host lookup',
    'connection refused',
    'connection reset',
    'connection closed',
    'network is unreachable',
    'no address associated',
    'socketexception',
    'clientexception',
    'failed to fetch',
    'networkerror',
    'err_internet_disconnected',
    'err_network',
  ];
  if (offline.any(t.contains)) return _Kind.offline;
  const timeout = [
    'connection timeout',
    'receive timeout',
    'send timeout',
    'connectiontimeout',
    'receivetimeout',
    'took longer than',
    'timed out',
    'timeoutexception',
  ];
  if (timeout.any(t.contains)) return _Kind.timeout;
  return _Kind.other;
}

/// Pulls an HTTP status out of Dio's "…status code of 404…" text.
int? _statusFromText(String s) {
  final m = RegExp(r'status code of (\d{3})').firstMatch(s);
  return m == null ? null : int.tryParse(m.group(1)!);
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
    'is not a subtype',
    'NoSuchMethodError',
    'RangeError',
    'FormatException',
    'Instance of',
    'Unexpected character',
    'Cast to ObjectId',
    'E11000',
    'MongoServerError',
    'Cannot read properties',
  ];
  return markers.any(s.contains);
}

String _fromDio(DioException e, String generic) {
  // 1. A short, human message from the backend wins.
  final data = e.response?.data;
  if (data is Map) {
    final m = data['message'] ?? data['error'];
    if (m is String) {
      final msg = m.trim();
      if (msg.isNotEmpty && !_looksTechnical(msg)) return msg;
    }
  }

  // 2. Otherwise decide from the failure kind.
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return _timeoutMsg;
    case DioExceptionType.connectionError:
      return _offlineMsg;
    case DioExceptionType.badCertificate:
      return 'Could not establish a secure connection to the server.';
    case DioExceptionType.cancel:
      return 'The request was cancelled.';
    case DioExceptionType.badResponse:
      return _fromStatus(e.response?.statusCode, generic);
    case DioExceptionType.unknown:
      // On web a dropped network often arrives as `unknown` with an XHR error.
      if (e.error is SocketException ||
          _kindFromText('${e.error} ${e.message}') == _Kind.offline) {
        return _offlineMsg;
      }
      if (e.error is TimeoutException) return _timeoutMsg;
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
    case 502:
    case 503:
    case 504:
      return 'The server is temporarily unavailable. Please try again in a moment.';
    case 500:
      return 'The server ran into a problem. Please try again in a moment.';
    default:
      if (code != null && code >= 500) {
        return 'The server ran into a problem. Please try again in a moment.';
      }
      return generic;
  }
}

/// Unwraps [AppException] to the error that actually happened.
Object? _root(Object? error) {
  var e = error;
  while (e is AppException) {
    e = e.cause;
  }
  return e;
}

/// A short heading that pairs with the message (used by [AppErrorView]).
String friendlyErrorTitle(Object? error) {
  if (isOfflineError(error)) return "Can't connect";
  final code = _statusOf(error);
  if (code == 404) return 'Not found';
  if (code == 403 || code == 401) return 'Access denied';
  if (code != null && code >= 500) return 'Server problem';
  return 'Something went wrong';
}

/// True when [error] means the server couldn't be reached at all (no
/// internet, DNS failure, server down, timeout) rather than an error reply.
bool isOfflineError(Object? error) {
  final e = _root(error);
  if (e is SocketException || e is TimeoutException) return true;
  if (e is DioException) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.error is SocketException ||
        (e.type == DioExceptionType.unknown &&
            _kindFromText('${e.error} ${e.message}') == _Kind.offline);
  }
  if (e == null) return false;
  return _kindFromText(e.toString()) != _Kind.other;
}

int? _statusOf(Object? error) {
  final e = _root(error);
  if (e is DioException) return e.response?.statusCode;
  if (e == null) return null;
  return _statusFromText(e.toString());
}

/// Which glyph best represents [error] — used by [AppErrorView].
/// (Kept here so both the widget and any custom UI stay consistent.)
int errorKind(Object? error) {
  if (isOfflineError(error)) return 0; // offline / unreachable
  final code = _statusOf(error);
  if (code == 404) return 1; // not found
  if (code == 401 || code == 403) return 2; // denied
  if (code != null && code >= 500) return 3; // server
  return 4; // generic
}
