import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/models/crm_user.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/models/service_region.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/fleet/data/driver_login.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/fleet_drivers_screen.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/services/region_service.dart';
import 'package:nizan_crm/services/user_service.dart';

CrmUser _user({bool active = true, DateTime? until, String employeeId = 'e1', String role = 'driver'}) =>
    CrmUser(id: 'u-$employeeId', name: 'x', email: 'x@x.test', role: role, active: active, accessExpiresAt: until, employeeId: employeeId);

final _today = DateTime(2026, 11, 2, 14, 30);
DateTime _day(int plus) => DateTime(2026, 11, 2 + plus, 23, 59, 59);

void main() {
  group('where a login stands', () {
    test('no user = no login', () {
      final l = DriverLogin.of(null, _today);
      expect(l.kind, DriverLoginKind.none);
      expect(l.hasLogin, isFalse);
      expect(l.canSignIn, isFalse);
      expect(l.label, 'No app login');
    });

    test('no end date = permanent', () {
      final l = DriverLogin.of(_user(), _today);
      expect(l.kind, DriverLoginKind.permanent);
      expect(l.canSignIn, isTrue);
      expect(l.label, 'App login');
    });

    test('a temporary login that is still valid says until when, and how long is left', () {
      final l = DriverLogin.of(_user(until: _day(5)), _today);
      expect(l.kind, DriverLoginKind.temporary);
      expect(l.daysLeft, 6); // 2 Nov … 7 Nov, counting today
      expect(l.label, 'Login until 7 Nov');
      expect(l.endsSoon, isFalse);
    });

    test('the last day still counts as valid, and is flagged as ending soon', () {
      final l = DriverLogin.of(_user(until: _day(0)), _today);
      expect(l.kind, DriverLoginKind.temporary);
      expect(l.daysLeft, 1);
      expect(l.label, 'Login ends today');
      expect(l.endsSoon, isTrue);
      expect(DriverLogin.of(_user(until: _day(1)), _today).endsSoon, isTrue);
      expect(DriverLogin.of(_user(until: _day(2)), _today).endsSoon, isFalse);
    });

    test('a login whose last day has passed has ended', () {
      final l = DriverLogin.of(_user(until: _day(-1)), _today);
      expect(l.kind, DriverLoginKind.ended);
      expect(l.canSignIn, isFalse);
      expect(l.hasLogin, isTrue);
      expect(l.label, 'Login ended 1 Nov');
    });

    test('a switched-off login is off, whatever its end date', () {
      expect(DriverLogin.of(_user(active: false), _today).kind, DriverLoginKind.off);
      expect(DriverLogin.of(_user(active: false, until: _day(5)), _today).kind, DriverLoginKind.off);
      expect(DriverLogin.of(_user(active: false), _today).label, 'Login switched off');
    });

    test('the end date is read from the server\'s UTC time in the viewer\'s own day', () {
      final fromServer = CrmUser.fromJson({'id': 'u', 'role': 'driver', 'active': true, 'accessExpiresAt': '2026-11-09T18:29:59.999Z'});
      expect(fromServer.accessExpiresAt, isNotNull);
      expect(CrmUser.fromJson({'id': 'u', 'accessExpiresAt': null}).accessExpiresAt, isNull);
      expect(CrmUser.fromJson({'id': 'u'}).accessExpiresAt, isNull);
    });
  });

  group('choosing an end date', () {
    test('"1 week" from today is 7 days counting today', () {
      expect(loginEndAfter(7, from: DateTime(2026, 11, 2)), DateTime(2026, 11, 8));
      expect(loginEndAfter(1, from: DateTime(2026, 11, 2)), DateTime(2026, 11, 2));
      expect(loginEndAfter(30, from: DateTime(2026, 11, 2)), DateTime(2026, 12, 1));
    });

    test('the server is told a plain day', () {
      expect(loginDayParam(DateTime(2026, 11, 8, 23, 59)), '2026-11-08');
      expect(loginDayParam(DateTime(2027, 1, 5)), '2027-01-05');
    });

    test('presets are in order', () {
      expect([for (final p in loginDurationPresets) p.days], [3, 7, 14, 30]);
    });
  });

  group('signing in with an email or a mobile number', () {
    test('an email', () {
      expect(isLoginId('suresh@vendor.test'), isTrue);
      expect(isLoginId(' a@b.co '), isTrue);
      expect(isLoginId('not an email@'), isFalse);
      expect(isLoginId('a@b'), isFalse);
    });

    test('a mobile number, however it is typed', () {
      expect(isLoginId('9895000000'), isTrue);
      expect(isLoginId('98950 00000'), isTrue);
      expect(isLoginId('+91 98950-00000'), isTrue);
      expect(isLoginId('12345'), isFalse);
      expect(isLoginId('abcdefghij'), isFalse);
      expect(isLoginId(''), isFalse);
    });

    test('what the driver will type: the email, else the 10 digits of the number', () {
      expect(loginIdFor(email: ' Suresh@Vendor.test ', phone: '9895000000'), 'suresh@vendor.test');
      expect(loginIdFor(email: '', phone: '+91 98950 00000'), '9895000000');
      expect(loginIdFor(email: '', phone: '12345'), isNull);
      expect(loginIdFor(email: '', phone: ''), isNull);
    });
  });

  group('the drivers screen', () {
    final until5 = DateTime.now().add(const Duration(days: 5));
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    Employee emp(String id, String name, {String type = 'outsource', String status = 'active'}) => Employee.fromJson({
          '_id': id, 'name': name, 'type': type, 'artistRole': 'driver', 'status': status, 'phone': '98950000${id.hashCode.abs() % 100}',
        });

    late _FakeUsers users;
    late _FakeEmployees employees;

    Widget screen({List<Employee>? drivers, List<CrmUser>? logins}) {
      users = _FakeUsers();
      employees = _FakeEmployees();
      return ProviderScope(
        overrides: [
          employeesProvider.overrideWith((ref) async => drivers ?? [
                emp('e1', 'Suresh'),
                emp('e2', 'Ramu'),
                emp('e3', 'Kumar', type: 'in-house'),
                emp('e4', 'Anu'),
              ]),
          regionsProvider.overrideWith((ref) async => <ServiceRegion>[]),
          crmUsersProvider.overrideWith((ref) async => logins ?? [
                _user(employeeId: 'e1', until: until5), // temporary, valid
                _user(employeeId: 'e2', until: yesterday), // ended
                _user(employeeId: 'e3'), // permanent
                // e4: none
                _user(employeeId: 'e9', role: 'artist'), // not a driver's login
              ]),
          userServiceProvider.overrideWithValue(users),
          employeeServiceProvider.overrideWithValue(employees),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: FleetDriversScreen()))),
      );
    }

    void desktop(WidgetTester t) {
      t.view.physicalSize = const Size(1200, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
    }

    Future<void> openMenu(WidgetTester t, int card) async {
      await t.tap(find.byType(PopupMenuButton<String>).at(card));
      await t.pumpAndSettle();
    }

    testWidgets('each driver card says where their login stands', (t) async {
      desktop(t);
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      expect(find.text('Login until ${DateFormat('d MMM').format(until5)}'), findsOneWidget);
      expect(find.text('Login ended ${DateFormat('d MMM').format(yesterday)}'), findsOneWidget);
      expect(find.text('App login'), findsOneWidget);
      expect(find.text('No app login'), findsOneWidget);
    });

    testWidgets('the card menu offers what makes sense for the login', (t) async {
      desktop(t);
      await t.pumpWidget(screen());
      await t.pumpAndSettle();

      await openMenu(t, 0); // temporary, valid
      expect(find.text('Change end date'), findsOneWidget);
      expect(find.text('End login now'), findsOneWidget);
      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();

      await openMenu(t, 1); // ended: renew, nothing to end
      expect(find.text('Renew login'), findsOneWidget);
      expect(find.text('End login now'), findsNothing);
      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();

      await openMenu(t, 3); // no login at all
      expect(find.text('Renew login'), findsNothing);
      expect(find.text('Change end date'), findsNothing);
      expect(find.text('End login now'), findsNothing);
    });

    testWidgets('"End login now" asks, then switches that driver\'s login off', (t) async {
      desktop(t);
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      await openMenu(t, 0);
      await t.tap(find.text('End login now'));
      await t.pumpAndSettle();
      expect(find.text('End login now?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(users.access, isEmpty, reason: 'cancel changes nothing');

      await openMenu(t, 0);
      await t.tap(find.text('End login now'));
      await t.pumpAndSettle();
      await t.tap(find.text('End login'));
      await t.pumpAndSettle();
      expect(users.access.single, (employeeId: 'e1', expiresOn: null, permanent: false, active: false));
    });

    testWidgets('renewing an ended login sets a new end date and brings it back on', (t) async {
      desktop(t);
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      await openMenu(t, 1);
      await t.tap(find.text('Renew login'));
      await t.pumpAndSettle();
      expect(find.text('Login for Ramu'), findsOneWidget);
      await t.tap(find.text('2 weeks'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(users.access.single, (employeeId: 'e2', expiresOn: loginDayParam(loginEndAfter(14)), permanent: false, active: true));
    });

    testWidgets('…or removes the end date', (t) async {
      desktop(t);
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      await openMenu(t, 0);
      await t.tap(find.text('Change end date'));
      await t.pumpAndSettle();
      await t.tap(find.text('No end date'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(users.access.single, (employeeId: 'e1', expiresOn: null, permanent: true, active: true));
    });

    testWidgets('an inactive driver is not offered a renewal that their status would undo', (t) async {
      desktop(t);
      await t.pumpWidget(screen(
        drivers: [emp('e1', 'Suresh', status: 'inactive')],
        logins: [_user(employeeId: 'e1', active: false)],
      ));
      await t.pumpAndSettle();
      expect(find.text('Login switched off'), findsOneWidget);
      await openMenu(t, 0);
      expect(find.text('Renew login'), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
    });

    Future<void> openAdd(WidgetTester t) async {
      await t.tap(find.text('Add Driver'));
      await t.pumpAndSettle();
    }

    Future<void> field(WidgetTester t, String label, String text) async {
      final f = find.widgetWithText(TextField, label);
      await t.ensureVisible(f);
      await t.enterText(f, text);
    }

    testWidgets('an outsource driver with only a phone gets a TEMPORARY login by phone number', (t) async {
      desktop(t);
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      await openAdd(t);

      await field(t, 'Name', 'Mohan');
      await t.tap(find.byType(DropdownButtonFormField<String>).first); // Type
      await t.pumpAndSettle();
      await t.tap(find.text('Outsource').last);
      await t.pumpAndSettle();
      await field(t, 'Phone', '98950 11111');
      await field(t, 'Login password (min 6 chars)', 'temp1234');
      expect(find.text('Temporary login'), findsOneWidget); // on by default for an outsource driver
      expect(find.textContaining('Stops working after ${DateFormat('d MMM yyyy').format(loginEndAfter(7))}'), findsOneWidget);

      await t.tap(find.text('Save'));
      await t.pumpAndSettle();

      expect(employees.saved.single['email'], '');
      expect(employees.saved.single['type'], 'outsource');
      expect(users.grants.single, (
        name: 'Mohan', email: '', phone: '98950 11111', password: 'temp1234', employeeId: 'new1', expiresOn: loginDayParam(loginEndAfter(7)),
      ));
      expect(find.textContaining('They sign in with 9895011111, until'), findsOneWidget);
    });

    testWidgets('the end date can be changed to 2 weeks before saving', (t) async {
      desktop(t);
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      await openAdd(t);
      await field(t, 'Name', 'Mohan');
      await t.tap(find.byType(DropdownButtonFormField<String>).first); // Type
      await t.pumpAndSettle();
      await t.tap(find.text('Outsource').last);
      await t.pumpAndSettle();
      await field(t, 'Phone', '9895011111');
      await field(t, 'Login password (min 6 chars)', 'temp1234');
      await t.ensureVisible(find.text('2 weeks'));
      await t.tap(find.text('2 weeks'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(users.grants.single.expiresOn, loginDayParam(loginEndAfter(14)));
    });

    testWidgets('an in-house driver\'s login stays permanent unless asked otherwise', (t) async {
      desktop(t);
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      await openAdd(t);
      await field(t, 'Name', 'Gopi');
      await field(t, 'Login email (optional if they have a phone)', 'gopi@x.test');
      await field(t, 'Login password (min 6 chars)', 'perm1234');
      expect(find.text('Works until you switch it off'), findsOneWidget); // the temporary switch starts off
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(users.grants.single.expiresOn, isNull);
      expect(users.grants.single.email, 'gopi@x.test');
    });

    testWidgets('no email and no phone is refused with a clear message, and nothing is saved', (t) async {
      desktop(t);
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      await openAdd(t);
      await field(t, 'Name', 'Nobody');
      await field(t, 'Login password (min 6 chars)', 'abcdef');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.textContaining('Add a login email, or a mobile number'), findsOneWidget);
      expect(employees.saved, isEmpty);
      expect(users.grants, isEmpty);
    });

    testWidgets('a mistyped email is refused', (t) async {
      desktop(t);
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      await openAdd(t);
      await field(t, 'Name', 'Typo');
      await field(t, 'Login email (optional if they have a phone)', 'typo@');
      await field(t, 'Phone', '9895011111');
      await field(t, 'Login password (min 6 chars)', 'abcdef');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.textContaining('does not look right'), findsOneWidget);
      expect(users.grants, isEmpty);
    });
  });
}

typedef _Grant = ({String name, String email, String phone, String password, String employeeId, String? expiresOn});
typedef _Access = ({String employeeId, String? expiresOn, bool permanent, bool? active});

class _FakeUsers implements UserService {
  final grants = <_Grant>[];
  final access = <_Access>[];

  @override
  Future<void> grantDriverLogin({
    required String name,
    required String email,
    required String password,
    String? employeeId,
    String? phone,
    String? expiresOn,
  }) async =>
      grants.add((name: name, email: email, phone: phone ?? '', password: password, employeeId: employeeId ?? '', expiresOn: expiresOn));

  @override
  Future<void> setDriverLoginAccess({required String employeeId, String? expiresOn, bool permanent = false, bool? active}) async =>
      access.add((employeeId: employeeId, expiresOn: expiresOn, permanent: permanent, active: active));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _FakeEmployees implements EmployeeService {
  final saved = <Map<String, dynamic>>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #saveEmployee) {
      final a = invocation.namedArguments;
      saved.add({for (final e in a.entries) _name(e.key): e.value});
      return Future.value(Employee.fromJson({
        '_id': 'new1', 'name': a[#name], 'type': a[#type], 'artistRole': 'driver', 'status': a[#status], 'phone': a[#phone],
      }));
    }
    throw UnimplementedError('${invocation.memberName}');
  }

  static String _name(Symbol s) => s.toString().replaceAll('Symbol("', '').replaceAll('")', '');
}
