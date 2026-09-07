/// The five company pillars (Jasim Rasheed's principle). Order matters — it
/// drives the scorecard axes and the score getters.
const kPillars = <String>[
  'learnability',
  'responsibility',
  'punctuality',
  'commitment',
  'leadership',
];

const kPillarLabels = <String, String>{
  'learnability': 'Learnability',
  'responsibility': 'Responsibility',
  'punctuality': 'Punctuality',
  'commitment': 'Commitment',
  'leadership': 'Leadership',
};

/// One employee's 5-pillar evaluation for a month.
class EmployeeEvaluation {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final int month; // 1–12
  final int year;
  final double learnability;
  final double responsibility;
  final double punctuality;
  final double commitment;
  final double leadership;
  final double composite;
  final String punctualitySource; // auto | manual
  final String notes;
  final String evaluatorName;
  final DateTime? updatedAt;

  const EmployeeEvaluation({
    required this.id,
    required this.employeeId,
    this.employeeName = '',
    this.department = '',
    required this.month,
    required this.year,
    this.learnability = 0,
    this.responsibility = 0,
    this.punctuality = 0,
    this.commitment = 0,
    this.leadership = 0,
    this.composite = 0,
    this.punctualitySource = 'manual',
    this.notes = '',
    this.evaluatorName = '',
    this.updatedAt,
  });

  double pillar(String key) {
    switch (key) {
      case 'learnability':
        return learnability;
      case 'responsibility':
        return responsibility;
      case 'punctuality':
        return punctuality;
      case 'commitment':
        return commitment;
      case 'leadership':
        return leadership;
      default:
        return 0;
    }
  }

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

  factory EmployeeEvaluation.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return EmployeeEvaluation(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null
          ? (empMap['_id'] as String? ?? '')
          : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? j['employeeName'] as String? ?? '',
      department: empMap?['department'] as String? ?? j['department'] as String? ?? '',
      month: (j['month'] as num?)?.toInt() ?? 1,
      year: (j['year'] as num?)?.toInt() ?? DateTime.now().year,
      learnability: _d(j['learnability']),
      responsibility: _d(j['responsibility']),
      punctuality: _d(j['punctuality']),
      commitment: _d(j['commitment']),
      leadership: _d(j['leadership']),
      composite: _d(j['composite']),
      punctualitySource: j['punctualitySource'] as String? ?? 'manual',
      notes: j['notes'] as String? ?? '',
      evaluatorName: j['evaluatedBy'] is Map
          ? (j['evaluatedBy']['name'] as String? ?? '')
          : (j['evaluatorName'] as String? ?? ''),
      updatedAt: j['updatedAt'] != null
          ? DateTime.tryParse(j['updatedAt'].toString())
          : null,
    );
  }
}
