/// A task within an IT project. Mirrors backend models/ITTask.js.
class ITTask {
  final String id;
  final String projectId;
  final String title;
  final String description;
  final String assignedToId;
  final String assignedToName;
  final String status; // todo | in-progress | review | completed
  final String priority; // low | medium | high | critical
  final String category; // feature | bug | maintenance | research
  final DateTime? deadline;
  final double estimatedHours;
  final double actualHours;
  final DateTime? completedAt;

  const ITTask({
    required this.id,
    required this.projectId,
    required this.title,
    this.description = '',
    this.assignedToId = '',
    this.assignedToName = '',
    this.status = 'todo',
    this.priority = 'medium',
    this.category = 'feature',
    this.deadline,
    this.estimatedHours = 0,
    this.actualHours = 0,
    this.completedAt,
  });

  factory ITTask.fromJson(Map<String, dynamic> j) {
    final proj = j['projectId'];
    final assignee = j['assignedTo'];
    return ITTask(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      projectId: proj is Map ? (proj['_id'] ?? '').toString() : (proj ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      assignedToId: assignee is Map ? (assignee['_id'] ?? '').toString() : (assignee ?? '').toString(),
      assignedToName: assignee is Map ? (assignee['name'] ?? '').toString() : '',
      status: (j['status'] ?? 'todo').toString(),
      priority: (j['priority'] ?? 'medium').toString(),
      category: (j['category'] ?? 'feature').toString(),
      deadline: _date(j['deadline']),
      estimatedHours: (j['estimatedHours'] as num?)?.toDouble() ?? 0,
      actualHours: (j['actualHours'] as num?)?.toDouble() ?? 0,
      completedAt: _date(j['completedAt']),
    );
  }

  static DateTime? _date(dynamic v) =>
      (v == null || v == '') ? null : DateTime.tryParse(v.toString())?.toLocal();
}

/// The kanban columns, in order.
const itTaskStatuses = ['todo', 'in-progress', 'review', 'completed'];
String itStatusLabel(String s) => switch (s) {
      'in-progress' => 'In Progress',
      'review' => 'Review',
      'completed' => 'Completed',
      _ => 'To-do',
    };
