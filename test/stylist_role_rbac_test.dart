import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_permissions.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/models/auth_session.dart';

void main() {
  group('Stylist AppRole & RBAC resolution', () {
    test('AppRole parses stylist variants', () {
      expect(AppRole.fromString('stylist'), AppRole.stylist);
      expect(AppRole.fromString('stylist_lead'), AppRole.stylist);
      expect(AppRole.fromString('bridal_stylist'), AppRole.stylist);
      expect(AppRole.fromString('senior_stylist'), AppRole.stylist);
      expect(AppRole.stylist.homeRoute, '/consultations/dashboard');
    });

    test('User with role stylist has access to consultations/stylist features by default', () {
      final session = AuthSession(
        token: 'tok',
        userId: 'u1',
        name: 'Stylist User',
        email: 'stylist@example.com',
        role: 'stylist',
        employeeId: 'emp1',
        permissions: const [],
      );
      final access = Access.of(session);
      expect(access.role, AppRole.stylist);
      expect(access.canSeeConsultations, isTrue);
    });

    test('Custom role with stylist permission can see consultations', () {
      final session = AuthSession(
        token: 'tok',
        userId: 'u2',
        name: 'Custom User',
        email: 'custom@example.com',
        role: 'custom_bridal_consultant',
        employeeId: 'emp2',
        permissions: const ['stylist'],
      );
      final access = Access.of(session);
      expect(access.canSeeConsultations, isTrue);
    });

    test('Legacy or custom role with consultations permission can see consultations', () {
      final session = AuthSession(
        token: 'tok',
        userId: 'u3',
        name: 'Legacy User',
        email: 'legacy@example.com',
        role: 'consultant',
        employeeId: 'emp3',
        permissions: const ['consultations'],
      );
      final access = Access.of(session);
      expect(access.canSeeConsultations, isTrue);
    });

    test('Stylist sub-permissions work symmetrically', () {
      final sessionWithStylistSubs = AuthSession(
        token: 'tok',
        userId: 'u4',
        name: 'User 4',
        email: 'u4@example.com',
        role: 'consultant',
        employeeId: 'emp4',
        permissions: const ['stylist.notes', 'stylist.reports'],
      );
      final access1 = Access.of(sessionWithStylistSubs);
      expect(access1.canSeeConsultationNotes, isTrue);
      expect(access1.canSeeConsultationReports, isTrue);

      final sessionWithConsultationSubs = AuthSession(
        token: 'tok',
        userId: 'u5',
        name: 'User 5',
        email: 'u5@example.com',
        role: 'consultant',
        employeeId: 'emp5',
        permissions: const ['consultations.notes', 'consultations.reports'],
      );
      final access2 = Access.of(sessionWithConsultationSubs);
      expect(access2.canSeeConsultationNotes, isTrue);
      expect(access2.canSeeConsultationReports, isTrue);
    });

    test('Unrelated role without stylist permissions cannot see consultations', () {
      final session = AuthSession(
        token: 'tok',
        userId: 'u6',
        name: 'Driver User',
        email: 'driver@example.com',
        role: 'driver',
        employeeId: 'emp6',
        permissions: const [],
      );
      final access = Access.of(session);
      expect(access.canSeeConsultations, isFalse);
    });

    test('featureForKey resolves both stylist and consultations', () {
      final f1 = featureForKey('stylist');
      final f2 = featureForKey('consultations');
      expect(f1, isNotNull);
      expect(f1!.label, 'Stylist');
      expect(f2, isNotNull);
      expect(f2!.key, 'stylist');
    });
  });
}
