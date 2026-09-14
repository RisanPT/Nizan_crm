export 'package:nizan_crm/features/it/domain/models/it_task_model.dart';

import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';

typedef ITTask = ITTaskModel;

/// The kanban columns, in order.
const itTaskStatuses = [
  'backlog',
  'todo',
  'in-progress',
  'code-review',
  'qa-testing',
  'deployed',
  'closed',
];

String itStatusLabel(String s) => switch (s.toLowerCase().replaceAll('_', '-')) {
      'backlog' => 'Backlog',
      'in-progress' || 'progress' => 'In Progress',
      'code-review' || 'review' => 'Code Review',
      'qa-testing' || 'qa' => 'QA Testing',
      'deployed' => 'Deployed',
      'closed' || 'completed' || 'done' => 'Closed',
      _ => 'To-do',
    };
