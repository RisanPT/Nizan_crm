import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/features/bookings/data/assignment_rules.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';

// The rules behind the booking's Artist Assignment chips: who each chip offers, and how an assignment is written.

Employee _e(String id, String name, {String role = 'artist', String type = 'in-house', bool associate = false, String spec = '', List<String> works = const [], String phone = '9000000001'}) =>
    Employee.fromJson({'_id': id, 'name': name, 'artistRole': role, 'type': type, 'isAssociate': associate, 'specialization': spec, 'works': works, 'phone': phone, 'status': 'active'});

final _team = [
  _e('a1', 'Lead Artist 1'),
  _e('a2', 'Lead Artist 2'),
  _e('s1', 'Assistant 1', role: 'assistant'),
  _e('d1', 'Driver 1', role: 'driver'),
  _e('f1', 'Freelancer', role: 'assistant', type: 'outsource'), // an outsource freelancer, NOT an associate
  _e('x1', 'Asha', role: 'assistant', type: 'outsource', associate: true, spec: 'Hair'),
  _e('x2', 'Binu', role: 'artist', type: 'outsource', associate: true), // even an associate whose role says "artist"
  _e('st', 'Office staff', role: 'staff'),
];

List<String> _names(List<Employee> l) => l.map((e) => e.name).toList();

void main() {
  group('who each chip offers', () {
    test('LEAD: artists; DRIVER: drivers; ASST: artists and assistants — and never an associate', () {
      expect(_names(selectableStaff(_team, 'lead', const [])), ['Lead Artist 1', 'Lead Artist 2']);
      expect(_names(selectableStaff(_team, 'driver', const [])), ['Driver 1']);
      expect(_names(selectableStaff(_team, 'assistant', const [])), ['Lead Artist 1', 'Lead Artist 2', 'Assistant 1', 'Freelancer']);
    });

    test('ASSOC.: only associates (whatever their role says); a plain freelancer is not one', () {
      expect(_names(selectableStaff(_team, 'associate', const [])), ['Asha', 'Binu']);
    });

    test('someone already on the team is not offered again, under any chip', () {
      final onTeam = [assignmentFor(_team[5], 'associate'), assignmentFor(_team[0], 'lead')];
      expect(_names(selectableStaff(_team, 'associate', onTeam)), ['Binu']);
      expect(_names(selectableStaff(_team, 'lead', onTeam)), ['Lead Artist 2']);
      expect(_names(selectableStaff(_team, 'assistant', onTeam)), ['Lead Artist 2', 'Assistant 1', 'Freelancer']);
    });

    test('each person once, even if the staff list repeats them; an unknown chip offers assistants', () {
      expect(_names(selectableStaff([..._team, ..._team], 'associate', const [])), ['Asha', 'Binu']);
      expect(selectableStaff(const [], 'associate', const []), isEmpty);
      expect(_names(selectableStaff(_team, 'whatever', const [])), ['Lead Artist 1', 'Lead Artist 2', 'Assistant 1', 'Freelancer']);
    });
  });

  group('how an assignment is written', () {
    test('an associate is written as the lead\'s assistant with the role "Associate", or what was typed', () {
      final a = assignmentFor(_team[5], 'associate');
      expect([a.employeeId, a.artistName, a.role, a.roleType, a.type, a.phone], ['x1', 'Asha', 'Associate', 'assistant', 'outsource', '9000000001']);
      expect(a.works, ['Hair'], reason: 'what they do, from their record');
      expect(assignmentFor(_team[5], 'associate', roleText: '  Saree draping ').role, 'Saree draping');
    });

    test('lead, driver and assistant are written exactly as before', () {
      final lead = assignmentFor(_team[0], 'lead', roleText: 'ignored');
      expect([lead.role, lead.roleType], ['Lead Artist', 'lead']);
      final driver = assignmentFor(_team[3], 'driver');
      expect([driver.role, driver.roleType, driver.works], ['Driver', 'driver', ['Driver']]);
      final asst = assignmentFor(_team[2], 'assistant');
      expect([asst.role, asst.roleType], ['Assistant', 'assistant']);
      expect(assignmentFor(_team[2], 'assistant', roleText: 'Hair').role, 'Hair');
    });

    test('works: their own list when they have one, else what they do, else nothing (a driver reads "Driver")', () {
      expect(assignmentFor(_e('w', 'W', works: ['Bridal', 'Party'], spec: 'Hair'), 'assistant').works, ['Bridal', 'Party']);
      expect(assignmentFor(_e('w', 'W', spec: 'Hair'), 'assistant').works, ['Hair']);
      expect(assignmentFor(_e('w', 'W'), 'assistant').works, isEmpty);
      expect(assignmentFor(_e('w', 'W', role: 'driver'), 'driver').works, ['Driver']);
    });
  });

  test('the badge: the ids of the associates among the staff', () {
    expect(associateIdsOf(_team), {'x1', 'x2'});
    expect(associateIdsOf(const []), isEmpty);
    expect(kAssignmentTypes, ['lead', 'driver', 'assistant', 'associate']);
  });

  test('an assignment survives a round trip through the booking (the team is stored as it was written)', () {
    final a = assignmentFor(_team[5], 'associate');
    final back = BookingAssignment.fromJson(a.toJson());
    expect([back.employeeId, back.role, back.roleType, back.works], [a.employeeId, a.role, a.roleType, a.works]);
  });
}
