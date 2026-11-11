import 'package:nizan_crm/features/it/domain/models/okr_model.dart';

// Sample objectives for the tree and scorecard tests. "Today" is Feb 15 2027, noon.

final okrNow = DateTime(2027, 2, 15, 12);

OKRModel okrFixture(
  String id,
  String title, {
  String level = 'project',
  String? parent,
  DateTime? start,
  DateTime? end,
  int progress = 0,
  OKRStatus status = OKRStatus.inProgress,
  String department = '',
  String owner = '',
  String project = '',
  String projectDepartment = '',
  List<KeyResultItem> krs = const [],
  OKRAccess access = OKRAccess.unrestricted,
}) =>
    OKRModel(
      id: id,
      objective: title,
      level: level,
      parentObjectiveId: parent,
      startDate: start,
      deadline: end,
      progress: progress,
      status: status,
      department: department.isEmpty ? (level == 'company' ? 'company' : '') : department,
      projectHeadName: owner,
      projectName: project,
      projectDepartment: projectDepartment,
      keyResults: krs,
      access: access,
      createdAt: DateTime(2027, 1, 1),
    );

/// company ← department ← project, plus a company objective with no dates:
///
///   Grow bridal revenue (Company, Mira, Jan 1 – Mar 31, 65%)      on track
///   └ Cut cost per lead (Marketing, Asha, Feb 1 – Apr 30, 5%)     at risk
///     └ Launch landing pages (project Diwali / Marketing, Anu,
///       Jan 25 – Feb 28, 0%)                                      off track; its key result nobody reports on
///   Loose idea (Company, no dates)                                no dates
List<OKRModel> sampleOkrs({OKRAccess access = OKRAccess.unrestricted}) => [
      okrFixture(
        'c',
        'Grow bridal revenue',
        level: 'company',
        owner: 'Mira Nair',
        start: DateTime(2027, 1, 1),
        end: DateTime(2027, 3, 31),
        progress: 65,
        access: access,
        krs: [
          KeyResultItem(
            id: 'k1',
            title: 'Revenue',
            targetValue: 100,
            currentValue: 30,
            unit: 'L',
            checkIns: [KeyResultCheckIn(value: 30, at: DateTime(2027, 2, 5), by: 'Mira')],
          ),
          const KeyResultItem(id: 'k2', title: 'Conversion', targetValue: 25, currentValue: 25, completed: true),
        ],
      ),
      okrFixture('d', 'Cut cost per lead', level: 'department', parent: 'c', department: 'Marketing', owner: 'Asha Rao', start: DateTime(2027, 2, 1), end: DateTime(2027, 4, 30), progress: 5, access: access),
      okrFixture(
        'p',
        'Launch landing pages',
        parent: 'd',
        owner: 'Anu Menon',
        project: 'Diwali',
        projectDepartment: 'Marketing',
        start: DateTime(2027, 1, 25),
        end: DateTime(2027, 2, 28),
        access: access,
        krs: const [KeyResultItem(id: 'k3', title: 'Pages live', targetValue: 10)],
      ),
      okrFixture('u', 'Loose idea', level: 'company', access: access),
    ];
