import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_session.dart';
import '../../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authControllerProvider = Provider<AuthController>((ref) {
  final controller = AuthController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

class AuthController extends ChangeNotifier {
  AuthController(this._ref) {
    _restoreSession();
  }

  static const _sessionKey = 'auth_session';

  final Ref _ref;

  AuthSession? _session;
  bool _isInitializing = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  AuthSession? get session => _session;
  bool get isInitializing => _isInitializing;
  bool get isSubmitting => _isSubmitting;
  bool get isAuthenticated => _session != null && _session!.token.isNotEmpty;
  String? get errorMessage => _errorMessage;

  Future<void> _restoreSession() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final rawSession = preferences.getString(_sessionKey);

      if (rawSession == null || rawSession.isEmpty) {
        _session = null;
        return;
      }

      final storedSession = AuthSession.fromStorageValue(rawSession);
      final refreshedSession = await _ref
          .read(authServiceProvider)
          .getCurrentUser(storedSession.token);

      _session = refreshedSession;
      await preferences.setString(_sessionKey, refreshedSession.toStorageValue());
    } catch (_) {
      await _clearPersistedSession();
      _session = null;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await _ref
          .read(authServiceProvider)
          .login(email: email, password: password);

      _session = session;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_sessionKey, session.toStorageValue());
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _session = null;
    _errorMessage = null;
    await _clearPersistedSession();
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _clearPersistedSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }
}
