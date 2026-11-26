// My Team shows everyone in the head's team automatically (2026-11-26).
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/crm_user.dart';
import 'package:nizan_crm/features/org/data/department.dart';
import 'package:nizan_crm/features/team/presentation/screens/team_management_screen.dart';

CrmUser _u(String id, String role, {String dept = '', String managedBy = ''}) =>
    CrmUser.fromJson({'_id': id, 'name': id, 'email': '$id@x', 'role': role, 'departmentId': dept, 'managedBy': managedBy});

const _depts = [
  Department(id: 'dMkt', key: 'marketing', name: 'Marketing', allowedRoleKeys: ['dop', 'video_editor']),
  Department(id: 'dSales', key: 'sales', name: 'Sales'),
];

final _users = [
  _u('me', 'marketing_admin'),
  _u('exec', 'marketing_executive'),
  _u('mgr', 'marketing_manager'),
  _u('digital', 'digital_marketing_executive'),
  _u('dop', 'dop'), // listed on the Marketing department
  _u('editor', 'employee', dept: 'dMkt'), // login set to Marketing
  _u('made', 'employee', managedBy: 'me'), // created by me
  _u('salesguy', 'sales'),
  _u('artist', 'artist'),
];

List<String> _team({String myDeptId = '', String myDeptName = ''}) => myTeamMembers(
      users: _users,
      myId: 'me',
      myRoleKey: 'marketing_admin',
      myDepartmentId: myDeptId,
      myDepartmentName: myDeptName,
      creatableRoles: const {'marketing_admin', 'marketingadmin', 'marketing_manager', 'marketing_executive'},
      departments: _depts,
    ).map((u) => u.id).toList();

void main() {
  test('a Marketing Admin with NO department set still sees the whole marketing team', () {
    final team = _team();
    expect(team, containsAll(['exec', 'mgr', 'digital', 'dop', 'editor', 'made']));
    expect(team, isNot(contains('me')));
    expect(team, isNot(contains('salesguy')));
    expect(team, isNot(contains('artist')));
  });

  test('same when the department is set on the login', () {
    expect(_team(myDeptId: 'dMkt'), containsAll(['exec', 'dop', 'editor']));
  });

  test('a Sales head does not get the marketing team', () {
    final team = myTeamMembers(
      users: _users,
      myId: 'boss',
      myRoleKey: 'sales_manager',
      myDepartmentId: '',
      myDepartmentName: '',
      creatableRoles: const {'sales', 'sales_manager', 'sales_executive'},
      departments: _depts,
    ).map((u) => u.id);
    expect(team, contains('salesguy'));
    expect(team, isNot(contains('exec')));
    expect(team, isNot(contains('dop')));
  });
}
