import 'package:intl/intl.dart';
import 'package:nizan_crm/core/models/crm_user.dart';

/// Where a driver's app login stands.
enum DriverLoginKind {
  /// No login has been given.
  none,

  /// A login with no end date.
  permanent,

  /// A temporary login that is still valid.
  temporary,

  /// A temporary login whose end date has passed.
  ended,

  /// Switched off (the driver is Inactive, or the login was ended early).
  off,
}

/// A driver's login, worked out from their user account — what the driver card shows and
/// which actions it offers. Pure.
class DriverLogin {
  final DriverLoginKind kind;

  /// The end date of a temporary login (its last valid day).
  final DateTime? until;

  /// Whole days left, counting today (a login that ends today has 1).
  final int? daysLeft;

  const DriverLogin(this.kind, {this.until, this.daysLeft});

  bool get hasLogin => kind != DriverLoginKind.none;
  bool get canSignIn => kind == DriverLoginKind.permanent || kind == DriverLoginKind.temporary;

  /// A temporary login is about to run out.
  bool get endsSoon => kind == DriverLoginKind.temporary && (daysLeft ?? 99) <= 2;

  static final _day = DateFormat('d MMM');

  /// The login of [user] (null = the driver has none) as of [now].
  factory DriverLogin.of(CrmUser? user, DateTime now) {
    if (user == null) return const DriverLogin(DriverLoginKind.none);
    final end = user.accessExpiresAt?.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = end == null ? null : DateTime(end.year, end.month, end.day);
    if (!user.active) return DriverLogin(DriverLoginKind.off, until: endDay);
    if (endDay == null) return const DriverLogin(DriverLoginKind.permanent);
    if (endDay.isBefore(today)) return DriverLogin(DriverLoginKind.ended, until: endDay);
    return DriverLogin(
      DriverLoginKind.temporary,
      until: endDay,
      daysLeft: endDay.difference(today).inDays + 1,
    );
  }

  /// "Login until 9 Nov" — the short line on the driver card.
  String get label => switch (kind) {
        DriverLoginKind.none => 'No app login',
        DriverLoginKind.permanent => 'App login',
        DriverLoginKind.temporary =>
          daysLeft == 1 ? 'Login ends today' : 'Login until ${_day.format(until!)}',
        DriverLoginKind.ended => 'Login ended ${_day.format(until!)}',
        DriverLoginKind.off => 'Login switched off',
      };
}

/// The ways to say how long a temporary login lasts (a start-from-today choice).
const loginDurationPresets = <({String label, int days})>[
  (label: '3 days', days: 3),
  (label: '1 week', days: 7),
  (label: '2 weeks', days: 14),
  (label: '1 month', days: 30),
];

/// The last valid day when a login is given for [days] days starting [from] (today counts).
DateTime loginEndAfter(int days, {DateTime? from}) {
  final d = from ?? DateTime.now();
  return DateTime(d.year, d.month, d.day).add(Duration(days: days - 1));
}

/// 'YYYY-MM-DD' — how the server is told the end date.
String loginDayParam(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Is this something a person can sign in with: an email, or a mobile number (10+ digits,
/// spaces / dashes / +91 allowed)?
bool isLoginId(String value) {
  final s = value.trim();
  if (s.isEmpty) return false;
  if (s.contains('@')) return _emailRe.hasMatch(s);
  return RegExp(r'^[+\d][\d\s\-]{8,}$').hasMatch(s) && s.replaceAll(RegExp(r'\D'), '').length >= 10;
}

/// What the driver will type to sign in, from what the fleet manager entered: the email, else
/// the 10 digits of the mobile number. null when neither is usable.
String? loginIdFor({required String email, required String phone}) {
  final e = email.trim();
  if (e.isNotEmpty) return e.toLowerCase();
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 10 ? digits.substring(digits.length - 10) : null;
}
