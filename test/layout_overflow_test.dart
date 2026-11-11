// Layout checks at phone (390px) and desktop (1440px) widths with long,
// realistic text. A RenderFlex overflow shows up as an exception, so each
// test asserts `tester.takeException()` is null.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/crm_user.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/hr/recruitment/data/recruitment_models.dart';
import 'package:nizan_crm/features/hr/recruitment/presentation/screens/hr_recruitment_screen.dart';
import 'package:nizan_crm/features/hr/recruitment/service/recruitment_service.dart';
import 'package:nizan_crm/presentation/screens/settings_screen.dart';
import 'package:nizan_crm/services/district_service.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/services/pincode_service.dart';
import 'package:nizan_crm/services/region_service.dart';
import 'package:nizan_crm/services/role_service.dart';
import 'package:nizan_crm/services/state_service.dart';
import 'package:nizan_crm/services/user_service.dart';
import 'package:nizan_crm/services/zone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _desktop = Size(1440, 1400);
const _phone = Size(390, 1400);

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

// ── Recruitment fixtures ────────────────────────────────────────────────────

List<Candidate> _candidates() => [
      for (final (i, stage, name, source, ref) in [
        (1, 'applied', 'Anjali Krishnakumar Menon', 'meta', 'Meta & LinkedIn Ad Campaign'),
        (2, 'screening', 'Divya Nair', 'referral', 'Risan Abdul Rahman (Studio Ops)'),
        (3, 'interview', 'Meera Das', 'website', ''),
        (4, 'offer', 'Riya Joseph', 'walk-in', 'Front desk – Kochi studio'),
        (5, 'hired', 'FATHIMA LIYA M', 'meta', 'Meta & LinkedIn Ad Campaign'),
        (6, 'hired', 'Yadhu Krishna', 'referral', 'Risan'),
      ])
        Candidate.fromJson({
          '_id': 'c$i',
          'name': name,
          'email': 'candidate$i.long.address@example.com',
          'phone': '98765432$i$i',
          'jobTitle': 'Software Developer Intern – Technology & Systems',
          'source': source,
          'referrer': ref,
          'stage': stage,
          'rating': i % 5,
        }),
    ];

List<HiringPlan> _plans() => [
      HiringPlan.fromJson({
        '_id': 'p1',
        'designation': 'Senior Dev-ops engineer and Cloud Infrastructure Lead',
        'department': 'Technology & Systems (IT)',
        'openings': 2,
        'employmentType': 'Full-time',
        'reportingLine': 'IT Head',
        'status': 'approved',
      }),
      HiringPlan.fromJson({
        '_id': 'p2',
        'designation': 'Bridal Makeup Artist',
        'department': 'Bridal Styling',
        'status': 'raised',
      }),
    ];

List<JobPost> _posts() => [
      JobPost.fromJson({
        '_id': 'j1',
        'title': 'Senior Dev-ops engineer and Cloud Infrastructure Lead',
        'department': 'Technology & Systems (IT)',
        'location': 'Kochi, Kerala',
        'status': 'published',
        'candidateCount': 0,
      }),
    ];

List<Offer> _offers() => [
      Offer.fromJson({
        '_id': 'o1',
        'candidateId': 'c4',
        'candidateName': 'Riya Joseph Kuruvilla Thomas',
        'designation': 'Senior Bridal Makeup Artist & Trainer',
        'department': 'Bridal Styling',
        'salary': 45000,
        'hra': 9000,
        'status': 'sent',
        'joiningDate': '2026-12-01',
      }),
    ];

List<JobRole> _roles() => [
      JobRole.fromJson({
        '_id': 'r1',
        'roleCode': 'TS-IT-01',
        'designation': 'Head of Technology & Systems',
        'dept': 'Technology & Systems (IT)',
        'tier': 2,
        'team': 'IT',
        'purpose': 'Own the CRM, ERP and all internal systems end to end.',
        'skills': [
          {'name': 'Cloud infrastructure', 'score': 4},
          {'name': 'Team leadership', 'score': 3.5},
        ],
      }),
      JobRole.fromJson({
        '_id': 'r2',
        'roleCode': 'TS-IT-02',
        'designation': 'Senior Dev-ops engineer and Cloud Infrastructure Lead',
        'dept': 'Technology & Systems (IT)',
        'tier': 4,
        'parentId': 'r1',
        'reportsTo': 'Head of Technology & Systems',
      }),
    ];

Future<void> _pumpRecruitment(WidgetTester tester, Size size) async {
  await _setSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        candidatesProvider.overrideWith((ref) async => _candidates()),
        hiringPlansProvider.overrideWith((ref) async => _plans()),
        jobPostsProvider.overrideWith((ref) async => _posts()),
        offersProvider.overrideWith((ref) async => _offers()),
        jobRolesProvider.overrideWith((ref) async => _roles()),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const HrRecruitmentScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Settings → Users fixtures ───────────────────────────────────────────────

Future<void> _pumpSettings(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  await _setSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => const AuthSession(token: 't', userId: 'u0', name: 'Admin', email: 'admin@example.com', role: 'admin'),
        ),
        crmUsersProvider.overrideWith(
          (ref) async => [
            CrmUser.fromJson(const {
              '_id': 'u1',
              'name': 'Yadhu Krishna',
              'email': 'yadhu.krishna.longaddress@example.com',
              'role': 'employee',
            }),
          ],
        ),
        rolesProvider.overrideWith(
          (ref) async => [
            for (final (key, label, n) in [
              ('admin', 'Administrator', 120),
              ('employee', 'Employee (Self-service)', 21),
              ('manager', 'Sales & Marketing Operations Manager', 64),
            ])
              AppRoleRecord(
                id: key,
                key: key,
                label: label,
                permissions: List.generate(n, (i) => 'f$i'),
                homeRoute: '/',
                isSystem: false,
                active: true,
                userCount: 1,
              ),
          ],
        ),
        employeesProvider.overrideWith((ref) async => []),
        zonesProvider.overrideWith((ref) async => []),
        statesProvider.overrideWith((ref) async => []),
        regionsProvider.overrideWith((ref) async => []),
        districtsProvider.overrideWith((ref) async => []),
        pincodesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: SettingsScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openEditUser(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Actions').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Edit user'));
  await tester.pumpAndSettle();
}

void main() {
  for (final (label, size) in [('desktop 1440', _desktop), ('phone 390', _phone)]) {
    group(label, () {
      testWidgets('recruitment: every tab lays out without overflow', (tester) async {
        await _pumpRecruitment(tester, size);
        expect(tester.takeException(), isNull, reason: 'Pipeline tab');
        // The kanban sits below the fold on phones; scroll it into view so
        // the long-referrer card is actually laid out.
        await tester.scrollUntilVisible(find.text('FATHIMA LIYA M'), 300,
            scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
        expect(tester.takeException(), isNull, reason: 'kanban cards');

        for (final tab in ['Job Roles & Analysis', 'Job Posts', 'Candidates', 'Offers']) {
          await tester.tap(find.text(tab).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$tab tab');
        }
      });

      testWidgets('settings: Edit user dialog role field fits', (tester) async {
        await _pumpSettings(tester, size);
        expect(tester.takeException(), isNull, reason: 'users list');
        await _openEditUser(tester);
        expect(find.textContaining('Edit user'), findsWidgets);
        expect(tester.takeException(), isNull, reason: 'Edit user dialog');

        // Open the role menu too: items there keep the "N features" hint.
        await tester.tap(find.textContaining('Employee (Self-service)').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'role menu');
      });
    });
  }

  testWidgets('desktop kanban shows all five stages without sideways scroll', (tester) async {
    await _pumpRecruitment(tester, const Size(1280, 1400));
    for (final stage in ['Applied', 'Screening', 'Interview', 'Offer', 'Hired']) {
      final r = tester.getRect(find.text(stage).last);
      expect(r.left, greaterThanOrEqualTo(0), reason: stage);
      expect(r.right, lessThanOrEqualTo(1280), reason: stage);
    }
  });
}
