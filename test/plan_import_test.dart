import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/domain/plan_import.dart';

// A list of tasks pasted as text becomes task drafts: one per line, an optional number of days at the end of the line.

List<(String, int)> _read(String text, {int defaultDays = 3}) => [
  for (final t in parseTaskLines(text, defaultDays: defaultDays))
    (t.title, t.days),
];

void main() {
  test(
    'one task per line, each with the default length when no days are given',
    () {
      expect(_read('Wireframes\nMockups\nHandoff'), [
        ('Wireframes', 3),
        ('Mockups', 3),
        ('Handoff', 3),
      ]);
      expect(_read('Wireframes\nMockups', defaultDays: 5), [
        ('Wireframes', 5),
        ('Mockups', 5),
      ]);
    },
  );

  test(
    'blank lines and surrounding spaces are ignored; Windows line ends work',
    () {
      expect(_read('\n  Wireframes  \r\n\r\n\t\nMockups\r\n'), [
        ('Wireframes', 3),
        ('Mockups', 3),
      ]);
      expect(_read(''), isEmpty);
      expect(_read('   \n \n'), isEmpty);
    },
  );

  test('bullets and numbers at the start of a line are dropped', () {
    expect(
      _read(
        '- Wireframes\n* Mockups\n• Handoff\n1. Review\n2) Launch\n(3) Retro\n– Notes',
      ),
      [
        ('Wireframes', 3),
        ('Mockups', 3),
        ('Handoff', 3),
        ('Review', 3),
        ('Launch', 3),
        ('Retro', 3),
        ('Notes', 3),
      ],
    );
    expect(_read('2026 launch plan'), [
      ('2026 launch plan', 3),
    ], reason: 'a year in a title is not a list number');
    expect(_read('3D models'), [
      ('3D models', 3),
    ], reason: 'neither is a digit that starts a word');
  });

  test(
    'days after a comma, a semicolon or a tab (a column pasted from a spreadsheet)',
    () {
      expect(_read('Wireframes, 4'), [('Wireframes', 4)]);
      expect(_read('Wireframes,4'), [('Wireframes', 4)]);
      expect(_read('Wireframes; 6 days'), [('Wireframes', 6)]);
      expect(_read('Wireframes\t10'), [('Wireframes', 10)]);
      expect(_read('Wireframes , 2 d'), [('Wireframes', 2)]);
    },
  );

  test('days written as a unit at the end of the line', () {
    expect(_read('Wireframes 3d'), [('Wireframes', 3)]);
    expect(_read('Wireframes 7 days'), [('Wireframes', 7)]);
    expect(_read('Wireframes 1 day'), [('Wireframes', 1)]);
  });

  test('a number with no unit and no separator stays in the title', () {
    expect(_read('Phase 2 kickoff'), [('Phase 2 kickoff', 3)]);
    expect(_read('Review 3 designs'), [('Review 3 designs', 3)]);
    expect(_read('Sprint 5'), [('Sprint 5', 3)]);
  });

  test(
    'a comma inside a title is kept unless what follows it is a number of days',
    () {
      expect(_read('Design, build and test'), [('Design, build and test', 3)]);
      expect(_read('Design, build and test, 8'), [
        ('Design, build and test', 8),
      ]);
    },
  );

  test(
    'days that make no sense fall back to the default: zero, more than a year',
    () {
      expect(_read('Wireframes, 0'), [('Wireframes', 3)]);
      expect(_read('Wireframes, 400'), [('Wireframes', 3)]);
      expect(_read('Wireframes, 365'), [('Wireframes', 365)]);
      expect(_read('Wireframes, 1'), [('Wireframes', 1)]);
    },
  );

  test(
    'a line that is only a number or only days has no title, and is skipped',
    () {
      expect(_read('3\n, 4\n5 days\nReal task'), [('Real task', 3)]);
    },
  );

  test('spaces inside a title are tidied; a very long title is cut', () {
    expect(_read('Build   the\t\tlogin    screen'), [
      ('Build the login screen', 3),
    ]);
    final long = 'x' * 300;
    expect(parseTaskLines(long).single.title.length, maxTitleLength);
  });

  test('a paste adds at most the limit', () {
    final many = List.generate(
      maxImportedTasks + 50,
      (i) => 'Task $i',
    ).join('\n');
    expect(parseTaskLines(many), hasLength(maxImportedTasks));
    expect(parseTaskLines(many).first.title, 'Task 0');
    expect(parseTaskLines(many).last.title, 'Task ${maxImportedTasks - 1}');
  });
}
