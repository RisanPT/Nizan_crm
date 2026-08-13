import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nizan_crm/core/providers/auth_provider.dart';

/// Per-user Reports Center state: which reports are starred and when each was
/// last opened. Persisted locally (SharedPreferences), scoped to the user so it
/// doesn't leak across logins.
class ReportsMeta {
  final Set<String> favorites;
  final Map<String, DateTime> lastVisited;

  const ReportsMeta({this.favorites = const {}, this.lastVisited = const {}});

  ReportsMeta copyWith({Set<String>? favorites, Map<String, DateTime>? lastVisited}) =>
      ReportsMeta(
        favorites: favorites ?? this.favorites,
        lastVisited: lastVisited ?? this.lastVisited,
      );

  bool isFavorite(String key) => favorites.contains(key);
  DateTime? visitedAt(String key) => lastVisited[key];
}

class ReportsMetaNotifier extends Notifier<ReportsMeta> {
  SharedPreferences? _prefs;
  String _userId = 'anon';

  String get _favKey => 'finance_report_favs_$_userId';
  String get _visitKey => 'finance_report_visits_$_userId';

  @override
  ReportsMeta build() {
    _userId = ref.watch(authSessionProvider)?.userId ?? 'anon';
    _load();
    return const ReportsMeta();
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final favs = _prefs?.getStringList(_favKey)?.toSet() ?? <String>{};
      final visits = <String, DateTime>{};
      final raw = _prefs?.getString(_visitKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            final d = DateTime.tryParse(v.toString());
            if (d != null) visits[k.toString()] = d;
          });
        }
      }
      state = ReportsMeta(favorites: favs, lastVisited: visits);
    } catch (_) {
      // No persistence — stay with in-memory defaults.
    }
  }

  Future<void> toggleFavorite(String key) async {
    final favs = {...state.favorites};
    if (!favs.remove(key)) favs.add(key);
    state = state.copyWith(favorites: favs);
    try {
      await _prefs?.setStringList(_favKey, favs.toList());
    } catch (_) {}
  }

  Future<void> recordVisit(String key) async {
    final visits = {...state.lastVisited, key: DateTime.now()};
    state = state.copyWith(lastVisited: visits);
    try {
      await _prefs?.setString(
        _visitKey,
        jsonEncode(visits.map((k, v) => MapEntry(k, v.toIso8601String()))),
      );
    } catch (_) {}
  }
}

final reportsMetaProvider =
    NotifierProvider<ReportsMetaNotifier, ReportsMeta>(ReportsMetaNotifier.new);
