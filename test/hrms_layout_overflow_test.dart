// Layout checks for the HRMS Leave / Offboarding / Assets / Shift screens at
// phone (390px) and desktop (1440px) widths with long, realistic text. A
// RenderFlex overflow shows up as an exception, so each step asserts
// `tester.takeException()` is null.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/hr/approvals/service/approval_service.dart';
import 'package:nizan_crm/features/hr/assets/data/employee_asset_models.dart';
import 'package:nizan_crm/features/hr/assets/presentation/screens/hr_assets_screen.dart';
import 'package:nizan_crm/features/hr/assets/service/employee_asset_service.dart';
import 'package:nizan_crm/features/hr/leave/data/leave_models.dart';
import 'package:nizan_crm/features/hr/leave/presentation/screens/hr_leave_screen.dart';
import 'package:nizan_crm/features/hr/leave/service/leave_service.dart';
import 'package:nizan_crm/features/hr/offboarding/data/offboarding_models.dart';
import 'package:nizan_crm/features/hr/offboarding/presentation/screens/hr_offboarding_screen.dart';
import 'package:nizan_crm/features/hr/offboarding/service/offboarding_service.dart';
import 'package:nizan_crm/features/hr/shift/data/shift_models.dart';
import 'package:nizan_crm/features/hr/shift/presentation/screens/hr_shift_screen.dart';
import 'package:nizan_crm/features/hr/shift/service/shift_service.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _desktop = Size(1440, 1400);
const _phone = Size(390, 1400);

const _longDept = 'Technology & Systems (IT)';
const _longDesig = 'Senior Bridal Makeup Artist & Trainer';
const _longName = 'Anjali Krishnakumar Menon Pillai';

const _session = AuthSession(
  token: 't',
  userId: 'u0',
  name: 'Admin',
  email: 'admin@example.com',
  role: 'admin',
  employeeId: 'e0',
);

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pump(WidgetTester tester, Size size, Widget home, List overrides) async {
  SharedPreferences.setMockInitialValues({});
  await _setSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith((ref) => _session),
        employeesProvider.overrideWith((ref) async => _employees()),
        ...overrides.cast(),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: home),
    ),
  );
  await tester.pumpAndSettle();
}

/// Run with --dart-define=LOCATE=true to let the framework print the
/// culprit widget's file:line instead of failing on the first exception.
const _locate = bool.fromEnvironment('LOCATE');

void _ok(WidgetTester tester, String reason) {
  if (_locate) return;
  expect(tester.takeException(), isNull, reason: reason);
}

Future<void> _tapAndCheck(WidgetTester tester, Finder f, String reason, {bool scroll = true}) async {
  if (scroll) {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
  }
  await tester.tap(f);
  await tester.pumpAndSettle();
  _ok(tester, reason);
}

Future<void> _closeDialog(WidgetTester tester) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
  nav.pop();
  await tester.pumpAndSettle();
}

// ── Fixtures ────────────────────────────────────────────────────────────────

List<Employee> _employees() => [
      for (final (i, name) in [(1, _longName), (2, 'Fathima Liya M'), (3, 'Yadhu Krishna')])
        Employee.fromJson({
          '_id': 'e$i',
          'name': name,
          'email': 'employee$i.long.address@example.com',
          'department': _longDept,
          'designation': _longDesig,
          'status': 'active',
        }),
    ];

List<LeaveBalance> _balances() => [
      LeaveBalance.fromJson({
        'leaveTypeId': 'lt1',
        'name': 'Casual Leave (Paid, Monthly Credit)',
        'allocated': 12,
        'used': 3.5,
        'available': 4.5,
        'credited': 9,
        'carriedForward': 2,
        'pending': 1,
      }),
      LeaveBalance.fromJson({'leaveTypeId': 'lt2', 'name': 'Loss of Pay', 'paid': false, 'used': 2, 'pending': 1}),
      LeaveBalance.fromJson({
        'leaveTypeId': 'lt3',
        'name': 'Sick',
        'allocated': 6,
        'used': 8,
        'available': -2,
        'credited': 6,
      }),
    ];

List<LeaveRequest> _requests() => [
      for (final (i, status) in [(1, 'pending'), (2, 'approved'), (3, 'rejected'), (4, 'cancelled')])
        LeaveRequest.fromJson({
          '_id': 'lr$i',
          'employeeId': {'_id': i == 1 ? 'e0' : 'e$i', 'name': _longName, 'department': _longDept},
          'leaveTypeName': 'Casual Leave (Paid, Monthly Credit)',
          'fromDate': '2026-12-0${i}T00:00:00Z',
          'toDate': '2026-12-1${i}T00:00:00Z',
          'days': 10.5,
          'halfDay': i == 2 ? 'first' : 'none',
          'reason':
              'Family function at native place in Thrissur followed by travel for my sister\'s wedding preparations and reception',
          'status': status,
          'approvalId': 'ap$i',
          'decisionNote': 'Approved by department head after checking the bridal season roster for conflicts',
          'decidedAt': '2026-11-10T00:00:00Z',
        }),
    ];

List<Holiday> _holidays() => [
      Holiday.fromJson({
        '_id': 'h1',
        'name': 'Thiruvonam (Onam Festival) – Kerala State Holiday',
        'date': '2026-08-26T00:00:00Z',
        'year': 2026,
        'type': 'state',
        'notes': 'Studio closed; bridal bookings handled by the on-call team',
      }),
      Holiday.fromJson({'_id': 'h2', 'name': 'Christmas', 'date': '2026-12-25T00:00:00Z', 'year': 2026}),
    ];

List<LeaveType> _types() => [
      LeaveType.fromJson({
        '_id': 'lt1',
        'name': 'Casual Leave (Paid, Monthly Credit)',
        'code': 'CL-MONTHLY',
        'annualQuota': 12,
        'carryForward': true,
        'carryForwardMax': 6,
        'docRequired': 'Required for more than 2 consecutive days',
      }),
      LeaveType.fromJson({'_id': 'lt2', 'name': 'Loss of Pay', 'code': 'LWP', 'paid': false}),
    ];

List<Offboarding> _offboardings() => [
      Offboarding.fromJson({
        '_id': 'o1',
        'employeeId': {'_id': 'e1', 'name': _longName, 'department': _longDept},
        'reason': 'resignation',
        'lastWorkingDay': DateTime.now().add(const Duration(days: 23)).toIso8601String(),
        'status': 'in_progress',
        'clearanceItems': [
          {'label': 'IT – laptop, email and CRM access revoked', 'cleared': true, 'owner': 'IT'},
          {'label': 'Accounts – advance and expense recovery settled', 'cleared': false, 'owner': 'Accounts'},
        ],
        'finalSettlementAmount': 123456,
        'notes': 'Moving abroad; requested early relieving after handover of all bridal bookings',
      }),
      Offboarding.fromJson({
        '_id': 'o2',
        'employeeId': {'_id': 'e2', 'name': 'Fathima Liya M', 'department': 'Bridal Styling & Makeup Operations'},
        'reason': 'termination',
        'lastWorkingDay': '2026-10-01T00:00:00Z',
        'status': 'completed',
        'clearanceItems': [
          {'label': 'HR – exit interview', 'cleared': true},
        ],
        'settlementPaid': true,
        'experienceLetterIssued': true,
      }),
    ];

OffboardingSettlement _settlement() => OffboardingSettlement.fromJson({
      'year': 2026,
      'month': 12,
      'daysInMonth': 31,
      'daysWorked': 4,
      'baseSalary': 1234567,
      'allowances': 234567,
      'proratedBase': 159299,
      'proratedAllowances': 30266,
      'amount': 189565,
      'lastWorkingDay': '2026-12-04',
      'canCreateSlip': true,
      'warnings': ['Attendance for December is not locked yet; days worked may change after regularisation'],
    });

List<EmployeeAsset> _assets() => [
      for (final (i, status, cat) in [(1, 'issued', 'laptop'), (2, 'returned', 'phone'), (3, 'lost', 'other')])
        EmployeeAsset.fromJson({
          '_id': 'a$i',
          'employeeId': {'_id': 'e$i', 'name': _longName, 'department': _longDept},
          'item': 'MacBook Pro 14-inch M3 Pro (Space Black) with charger and sleeve',
          'category': cat,
          'serialNo': 'C02XK1ABCDEF-SN-0000$i',
          'issuedOn': '2026-01-15T00:00:00Z',
          'issuedByName': 'Risan Abdul Rahman (Studio Ops)',
          'condition': 'Good – minor scratches on lid',
          'returnedOn': status == 'returned' ? '2026-10-01T00:00:00Z' : null,
          'returnedToName': status == 'returned' ? 'Risan Abdul Rahman (Studio Ops)' : '',
          'returnCondition': status == 'returned' ? 'Keyboard worn, battery health 81%' : '',
          'notes': 'Issued for CRM development and on-site bridal shoots in Kochi & Thrissur',
          'status': status,
        }),
    ];

List<Shift> _shifts() => [
      Shift.fromJson({
        '_id': 's1',
        'name': 'Bridal Early Morning Shift (Studio + On-site)',
        'code': 'BRIDAL-EARLY',
        'startTime': '04:30',
        'endTime': '13:30',
        'graceInMin': 15,
        'graceOutMin': 10,
        'workingDays': [0, 1, 2, 3, 4, 5, 6],
      }),
      Shift.fromJson({'_id': 's2', 'name': 'General', 'code': 'GEN', 'workingDays': [1, 2, 3, 4, 5]}),
    ];

List<ShiftAssignment> _assignments() => [
      ShiftAssignment.fromJson({
        '_id': 'sa1',
        'employeeId': {'_id': 'e1', 'name': _longName, 'department': _longDept},
        'shiftId': {'_id': 's1', 'name': 'Bridal Early Morning Shift (Studio + On-site)'},
        'fromDate': '2026-11-01T00:00:00Z',
        'toDate': '2027-03-31T00:00:00Z',
        'note': 'Wedding season cover for the Kochi and Thrissur studios, rotating weekly',
      }),
      ShiftAssignment.fromJson({
        '_id': 'sa2',
        'employeeId': {'_id': 'e2', 'name': 'Fathima Liya M', 'department': 'Bridal Styling'},
        'shiftId': {'_id': 's2', 'name': 'General'},
        'fromDate': '2026-11-01T00:00:00Z',
      }),
    ];

// ── Pumps ───────────────────────────────────────────────────────────────────

Future<void> _pumpLeave(WidgetTester tester, Size size) => _pump(tester, size, const HrLeaveScreen(), [
      leaveMasterAccessProvider.overrideWith((ref) async => true),
      myBalancesProvider.overrideWith((ref) async => _balances()),
      myLeaveProvider.overrideWith((ref) async => _requests()),
      leaveRequestsProvider.overrideWith((ref) async => _requests()),
      approvalInboxProvider.overrideWith((ref) async => []),
      holidaysProvider.overrideWith((ref) async => _holidays()),
      leaveTypesProvider.overrideWith((ref) async => _types()),
    ]);

Future<void> _pumpOffboarding(WidgetTester tester, Size size) =>
    _pump(tester, size, const HrOffboardingScreen(), [
      offboardingsProvider.overrideWith((ref) async => _offboardings()),
      offboardingSettlementProvider.overrideWith((ref, id) async => _settlement()),
      employeeAssetsForProvider.overrideWith((ref, id) async => _assets()),
    ]);

Future<void> _pumpAssets(WidgetTester tester, Size size) => _pump(tester, size, const HrAssetsScreen(), [
      employeeAssetsProvider.overrideWith((ref) async => _assets()),
      employeeAssetsForProvider.overrideWith((ref, id) async => _assets()),
    ]);

Future<void> _pumpShift(WidgetTester tester, Size size) => _pump(tester, size, const HrShiftScreen(), [
      shiftsProvider.overrideWith((ref) async => _shifts()),
      shiftAssignmentsProvider.overrideWith((ref) async => _assignments()),
    ]);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final (label, size) in [('desktop 1440', _desktop), ('phone 390', _phone)]) {
    group(label, () {
      testWidgets('leave: every tab and dialog lays out without overflow', (tester) async {
        await _pumpLeave(tester, size);
        _ok(tester, 'My Leave tab');
        await _tapAndCheck(tester, find.text('Apply for leave'), 'Apply dialog');
        await _closeDialog(tester);

        for (final tab in ['Requests', 'Holidays', 'Leave Types']) {
          await _tapAndCheck(tester, find.widgetWithText(Tab, tab), '$tab tab');
        }
        await _tapAndCheck(tester, find.byTooltip('Edit').first, 'Edit leave type dialog');
        await _closeDialog(tester);
      });

      testWidgets('offboarding: list, cards and certificate dialog', (tester) async {
        await _pumpOffboarding(tester, size);
        _ok(tester, 'offboarding list');
        await _tapAndCheck(tester, find.text('Experience Certificate').first, 'certificate dialog');
        await _closeDialog(tester);
        // Expand the completed exit too.
        await _tapAndCheck(tester, find.text('Fathima Liya M').first, 'completed card expanded');
      });

      testWidgets('assets: list and issue dialog', (tester) async {
        await _pumpAssets(tester, size);
        _ok(tester, 'assets list');
        for (final s in ['Returned', 'Lost', 'All']) {
          final f = find.textContaining(s);
          if (f.evaluate().isEmpty) continue;
          await _tapAndCheck(tester, f.first, '$s filter');
        }
        await _tapAndCheck(tester, find.text('Issue asset'), 'issue asset dialog');
        await _closeDialog(tester);
      });

      testWidgets('shift: both tabs and dialogs', (tester) async {
        await _pumpShift(tester, size);
        _ok(tester, 'Shifts tab');
        await _tapAndCheck(tester, find.widgetWithText(FloatingActionButton, 'Shift'), 'shift editor', scroll: false);
        await _closeDialog(tester);
        await tester.tap(find.widgetWithText(Tab, 'Roster'));
        await tester.pumpAndSettle();
        _ok(tester, 'Roster tab');
        await _tapAndCheck(tester, find.widgetWithText(FloatingActionButton, 'Assign'), 'assign dialog', scroll: false);
        await _closeDialog(tester);
      });
    });
  }
}
