// Letter models — mirror LetterTemplate.js & GeneratedLetter.js.

const kLetterTypes = <String>['offer', 'experience', 'salary_certificate', 'noc', 'confirmation', 'warning', 'other'];

String letterTypeLabel(String t) {
  switch (t) {
    case 'salary_certificate':
      return 'Salary certificate';
    case 'noc':
      return 'NOC';
    default:
      return t.isEmpty ? 'Other' : t[0].toUpperCase() + t.substring(1);
  }
}

DateTime? _date(dynamic v) => (v == null) ? null : DateTime.tryParse(v.toString());

class LetterTemplate {
  final String id;
  final String name;
  final String type;
  final String body;
  final bool active;

  const LetterTemplate({required this.id, this.name = '', this.type = 'other', this.body = '', this.active = true});

  factory LetterTemplate.fromJson(Map<String, dynamic> j) => LetterTemplate(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        type: j['type'] as String? ?? 'other',
        body: j['body'] as String? ?? '',
        active: j['active'] as bool? ?? true,
      );
}

class GeneratedLetter {
  final String id;
  final String employeeId;
  final String employeeName;
  final String type;
  final String subject;
  final String body;
  final String issuedByName;
  final DateTime? createdAt;

  const GeneratedLetter({
    required this.id,
    this.employeeId = '',
    this.employeeName = '',
    this.type = 'other',
    this.subject = '',
    this.body = '',
    this.issuedByName = '',
    this.createdAt,
  });

  factory GeneratedLetter.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return GeneratedLetter(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null ? (empMap['_id'] as String? ?? '') : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? j['employeeName'] as String? ?? '',
      type: j['type'] as String? ?? 'other',
      subject: j['subject'] as String? ?? '',
      body: j['body'] as String? ?? '',
      issuedByName: j['issuedByName'] as String? ?? '',
      createdAt: _date(j['createdAt']),
    );
  }
}
