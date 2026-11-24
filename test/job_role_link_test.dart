// HRMS job roles linked to real departments and a CRM login role (2026-11-24).
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/features/hr/recruitment/data/recruitment_models.dart';

void main() {
  test('JobRole reads departmentId and crmRoleKey (plain or populated)', () {
    final a = JobRole.fromJson({'_id': 'j1', 'designation': 'Bridal Artist', 'dept': 'Artist', 'departmentId': 'd1', 'crmRoleKey': 'artist'});
    expect(a.departmentId, 'd1');
    expect(a.crmRoleKey, 'artist');
    final b = JobRole.fromJson({'_id': 'j2', 'designation': 'X', 'departmentId': {'_id': 'd2', 'name': 'HR'}});
    expect(b.departmentId, 'd2');
    expect(b.crmRoleKey, '');
    final old = JobRole.fromJson({'_id': 'j3', 'designation': 'Old', 'dept': 'Academy'});
    expect(old.departmentId, isNull);
  });

  test('Employee keeps jobRoleId through copyWith and never sends it', () {
    final e = Employee.fromJson({'_id': 'e1', 'name': 'Asha', 'email': 'a@x.in', 'jobRoleId': 'j1'});
    expect(e.jobRoleId, 'j1');
    final edited = e.copyWith(name: 'Asha K');
    expect(edited.jobRoleId, 'j1');
    expect(e.toJson().containsKey('jobRoleId'), isFalse);
    expect(Employee.fromJson({'_id': 'e2', 'name': 'B', 'email': ''}).jobRoleId, isNull);
  });
}
