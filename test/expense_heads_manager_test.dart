import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/admin_expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/admin_expense.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/manage_expense_heads_dialog.dart';
import 'package:nizan_crm/features/accounts/services/admin_expense_service.dart';

ExpenseHead _h(
  String id,
  String code,
  String label,
  String group, {
  bool jobLinked = false,
  bool recurring = false,
  bool foreign = false,
  bool active = true,
  bool system = false,
  int used = 0,
}) =>
    ExpenseHead(code, label, group, id: id, jobLinked: jobLinked, recurring: recurring, foreign: foreign, active: active, system: system, used: used);

List<ExpenseHead> _seed() => [
      _h('1', 'FOO-01', 'Food Expense', 'Operating Expense', system: true, used: 12),
      _h('2', 'RNT-01', 'Rent – Office Expense', 'Rent', recurring: true, system: true, used: 3),
      _h('3', 'DRP-01', 'Drapist Expenses', 'Direct / Job Expense', jobLinked: true, system: true),
      _h('4', 'COU-01', 'Courier Charges', 'Operating Expense', used: 2),
      _h('5', 'TMP-01', 'Temporary Head', 'Operating Expense'),
      _h('6', 'OLD-01', 'Old Head', 'Operating Expense', active: false, used: 1),
    ];

AppException _server(String message) {
  final req = RequestOptions(path: '/admin-expenses/heads');
  return AppException(DioException(requestOptions: req, response: Response(requestOptions: req, statusCode: 400, data: {'message': message})), action: 'add expense head');
}

class _FakeAdmin implements AdminExpenseService {
  final List<ExpenseHead> heads = _seed();
  final calls = <String>[];
  Map<String, dynamic>? lastCreate;
  Map<String, dynamic>? lastUpdate;
  String? failWith;

  @override
  Future<List<ExpenseHead>> getExpenseHeads({bool all = false}) async => all ? List.of(heads) : heads.where((h) => h.active).toList();

  @override
  Future<ExpenseHead> createExpenseHead({required String name, String group = '', String code = '', bool jobLinked = false, bool recurring = false, bool foreign = false}) async {
    calls.add('create');
    lastCreate = {'name': name, 'group': group, 'code': code, 'jobLinked': jobLinked, 'recurring': recurring, 'foreign': foreign};
    if (failWith != null) throw _server(failWith!);
    final made = _h('n${heads.length}', code.isEmpty ? 'NEW-01' : code, name, group.isEmpty ? 'Operating Expense' : group, jobLinked: jobLinked, recurring: recurring, foreign: foreign);
    heads.add(made);
    return made;
  }

  @override
  Future<ExpenseHead> updateExpenseHead(String id, {String? name, String? group, String? code, bool? jobLinked, bool? recurring, bool? foreign, bool? active}) async {
    calls.add('update');
    lastUpdate = {'id': id, 'name': name, 'group': group, 'code': code, 'jobLinked': jobLinked, 'recurring': recurring, 'foreign': foreign, 'active': active};
    if (failWith != null) throw _server(failWith!);
    final i = heads.indexWhere((h) => h.id == id);
    final o = heads[i];
    heads[i] = ExpenseHead(code ?? o.code, name ?? o.label, group ?? o.group,
        id: o.id, jobLinked: jobLinked ?? o.jobLinked, recurring: recurring ?? o.recurring, foreign: foreign ?? o.foreign, active: active ?? o.active, system: o.system, used: o.used);
    return heads[i];
  }

  @override
  Future<void> deleteExpenseHead(String id) async {
    calls.add('delete');
    heads.removeWhere((h) => h.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Future<_FakeAdmin> _open(WidgetTester tester, {_FakeAdmin? fake}) async {
  final f = fake ?? _FakeAdmin();
  tester.view.physicalSize = const Size(900, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminExpenseServiceProvider.overrideWithValue(f)],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: Center(child: ManageExpenseHeadsDialog()))),
    ),
  );
  await tester.pumpAndSettle();
  return f;
}

Future<void> _menu(WidgetTester tester, String code, String item) async {
  await tester.tap(find.byKey(Key('head_menu_$code')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  group('the head as the server sends it', () {
    test('reads id, flags, built-in, archived and how many expenses use it', () {
      final h = ExpenseHead.fromJson({'id': 'abc', 'code': 'COU-01', 'label': 'Courier', 'group': 'Logistics', 'jobLinked': true, 'recurring': false, 'foreign': true, 'status': 'archived', 'system': true, 'used': 4});
      expect([h.id, h.code, h.label, h.group, h.jobLinked, h.recurring, h.foreign, h.active, h.system, h.used], ['abc', 'COU-01', 'Courier', 'Logistics', true, false, true, false, true, 4]);
    });

    test('the plain form-list shape (no status / used) is an active head', () {
      final h = ExpenseHead.fromJson({'code': 'FOO-01', 'label': 'Food', 'group': 'x'});
      expect([h.active, h.system, h.used, h.id], [true, false, 0, '']);
    });

    test('an expense is named by the LIVE heads, so a head Accounts added shows its name', () {
      final e = AdminExpense.fromJson({'_id': 'e1', 'title': 't', 'category': 'office_supplies', 'expenseHead': 'COU-01', 'amount': 10, 'date': '2026-11-01'});
      expect(e.headLabel, 'Office Supplies', reason: 'the built-in list has never heard of COU-01');
      expect(e.headLabelIn(_seed()), 'Courier Charges');
      final built = AdminExpense.fromJson({'_id': 'e2', 'title': 't', 'category': 'other', 'expenseHead': 'FUE-01', 'amount': 10, 'date': '2026-11-01'});
      expect(built.headLabelIn(const []), 'Fuel Expense', reason: 'a built-in head still resolves with no live list');
    });
  });

  group('the heads manager', () {
    testWidgets('lists the heads by group with what each one does and how much it is used', (tester) async {
      await _open(tester);
      expect(find.text('Manage Expense Heads'), findsOneWidget);
      expect(find.text('OPERATING EXPENSE'), findsOneWidget);
      expect(find.text('RENT'), findsOneWidget);
      expect(find.text('Food Expense'), findsOneWidget);
      expect(find.text('12 expenses'), findsOneWidget);
      expect(find.text('2 expenses'), findsOneWidget);
      expect(find.text('Not used yet'), findsNWidgets(2), reason: 'Drapist and Temporary');
      expect(find.text('Recurring'), findsOneWidget);
      expect(find.text('Job-linked'), findsOneWidget);
      expect(find.text('Built-in'), findsNWidgets(3));
    });

    testWidgets('an archived head is hidden until asked for, then shown as archived with a Restore', (tester) async {
      final f = await _open(tester);
      expect(find.text('Old Head'), findsNothing);
      expect(find.text('Show archived (1)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('head_show_archived')));
      await tester.pumpAndSettle();
      expect(find.text('Old Head'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
      await _menu(tester, 'OLD-01', 'Restore');
      expect(f.lastUpdate!['active'], true);
      expect(find.text('"Old Head" restored'), findsOneWidget);
      expect(find.text('Show archived (1)'), findsNothing, reason: 'nothing is archived any more');
      expect(find.text('Old Head'), findsOneWidget);
    });

    testWidgets('search narrows the list by name, code or group', (tester) async {
      await _open(tester);
      await tester.enterText(find.byKey(const Key('head_search')), 'courier');
      await tester.pumpAndSettle();
      expect(find.text('Courier Charges'), findsOneWidget);
      expect(find.text('Food Expense'), findsNothing);
      await tester.enterText(find.byKey(const Key('head_search')), 'rnt-');
      await tester.pumpAndSettle();
      expect(find.text('Rent – Office Expense'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('head_search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No head matches "zzz".'), findsOneWidget);
    });

    testWidgets('adding a head sends the name, group and flags — and it appears in the list', (tester) async {
      final f = await _open(tester);
      await tester.tap(find.byKey(const Key('head_add')));
      await tester.pumpAndSettle();
      expect(find.text('Add expense head'), findsOneWidget);
      // a name is required
      await tester.tap(find.byKey(const Key('head_save')));
      await tester.pumpAndSettle();
      expect(find.text('Give the head a name'), findsOneWidget);
      expect(f.calls, isEmpty);

      await tester.enterText(find.byKey(const Key('head_name')), 'Hair Extensions');
      await tester.tap(find.widgetWithText(ActionChip, 'Direct / Job Expense'));
      await tester.tap(find.byKey(const Key('head_job_linked')));
      await tester.tap(find.byKey(const Key('head_recurring')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('head_save')));
      await tester.pumpAndSettle();

      expect(f.lastCreate, {'name': 'Hair Extensions', 'group': 'Direct / Job Expense', 'code': '', 'jobLinked': true, 'recurring': true, 'foreign': false});
      expect(find.text('Add expense head'), findsNothing, reason: 'the form closed');
      expect(find.text('"Hair Extensions" added as NEW-01'), findsOneWidget);
      expect(find.text('Hair Extensions'), findsOneWidget);
    });

    testWidgets('a typed code is sent; a refusal from the server is shown in the form, which stays open', (tester) async {
      final f = _FakeAdmin()..failWith = 'There is already a head with that name (FOO-01).';
      await _open(tester, fake: f);
      await tester.tap(find.byKey(const Key('head_add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('head_name')), 'Food Expense');
      await tester.enterText(find.byKey(const Key('head_code')), 'fo9');
      await tester.tap(find.byKey(const Key('head_save')));
      await tester.pumpAndSettle();
      expect(f.lastCreate!['code'], 'fo9');
      expect(find.byKey(const Key('head_error')), findsOneWidget);
      expect(find.text('There is already a head with that name (FOO-01).'), findsOneWidget);
      expect(find.text('Add expense head'), findsOneWidget, reason: 'still open so it can be fixed');
      expect(find.text('Saving…'), findsNothing, reason: 'the button is usable again');
    });

    testWidgets('editing a BUILT-IN head: the code is locked, the name and flags can change', (tester) async {
      final f = await _open(tester);
      await _menu(tester, 'FOO-01', 'Edit');
      expect(find.text('Edit expense head'), findsOneWidget);
      final code = tester.widget<TextFormField>(find.byKey(const Key('head_code')));
      expect(code.enabled, isFalse);
      expect(find.text('The code of a built-in head cannot change.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('head_name')), 'Food & Beverage');
      await tester.tap(find.byKey(const Key('head_foreign')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('head_save')));
      await tester.pumpAndSettle();
      expect(f.lastUpdate, {'id': '1', 'name': 'Food & Beverage', 'group': 'Operating Expense', 'code': null, 'jobLinked': false, 'recurring': false, 'foreign': true, 'active': null});
      expect(find.text('Food & Beverage'), findsOneWidget);
      expect(find.text('"Food & Beverage" saved'), findsOneWidget);
    });

    testWidgets('a head that is in use cannot change its code; an unused custom one can', (tester) async {
      final f = await _open(tester);
      await _menu(tester, 'COU-01', 'Edit');
      expect(tester.widget<TextFormField>(find.byKey(const Key('head_code'))).enabled, isFalse);
      expect(find.text('This head is in use, so its code cannot change.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(f.calls, isEmpty, reason: 'cancel changes nothing');

      await _menu(tester, 'TMP-01', 'Edit');
      expect(tester.widget<TextFormField>(find.byKey(const Key('head_code'))).enabled, isTrue);
      await tester.enterText(find.byKey(const Key('head_code')), 'tmp-9');
      await tester.tap(find.byKey(const Key('head_save')));
      await tester.pumpAndSettle();
      expect(f.lastUpdate!['code'], 'tmp-9');
    });

    testWidgets('archiving asks first, then hides the head; Cancel keeps it', (tester) async {
      final f = await _open(tester);
      await _menu(tester, 'COU-01', 'Archive');
      expect(find.text('Archive this head?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(f.calls, isEmpty);
      expect(find.text('Courier Charges'), findsOneWidget);

      await _menu(tester, 'COU-01', 'Archive');
      await tester.tap(find.byKey(const Key('head_archive_confirm')));
      await tester.pumpAndSettle();
      expect(f.lastUpdate!['active'], false);
      expect(find.text('Courier Charges'), findsNothing);
      expect(find.text('Show archived (2)'), findsOneWidget);
    });

    testWidgets('delete is only for a head nothing uses — built-in and in-use heads say why not', (tester) async {
      final f = await _open(tester);
      await tester.tap(find.byKey(const Key('head_menu_FOO-01')));
      await tester.pumpAndSettle();
      expect(find.text('Delete (built-in)'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5)); // dismiss the menu
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('head_menu_COU-01')));
      await tester.pumpAndSettle();
      expect(find.text('Delete (in use)'), findsOneWidget);
      await tester.tap(find.text('Delete (in use)'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this head?'), findsNothing, reason: 'a disabled item does nothing');
      expect(f.calls, isEmpty);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await _menu(tester, 'TMP-01', 'Delete');
      expect(find.text('Delete this head?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('head_delete_confirm')));
      await tester.pumpAndSettle();
      expect(f.calls, ['delete']);
      expect(find.text('Temporary Head'), findsNothing);
      expect(find.text('"Temporary Head" deleted'), findsOneWidget);
    });
  });
}
