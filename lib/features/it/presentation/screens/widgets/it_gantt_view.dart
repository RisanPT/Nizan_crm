import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_interactive_gantt.dart';

class ITGanttView extends ConsumerWidget {
  const ITGanttView({super.key, required this.projectId, required this.tasks});
  final String projectId;
  final List<ITTaskModel> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ITInteractiveGantt(
      tasks: tasks,
      allTasks: tasks,
      projectId: projectId,
    );
  }
}
