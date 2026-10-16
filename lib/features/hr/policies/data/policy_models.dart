// Company Policy & HR Policy Models

class HrPolicy {
  final String id;
  final String title;
  final String category; // 'HR Policy' | 'Company Policy' | 'Code of Conduct' | 'Studio & Hygiene' | 'Financial & Travel'
  final String summary;
  final String content;
  final String version;
  final DateTime effectiveDate;
  final bool isMandatory;
  final List<String> acknowledgedBy; // Employee IDs who have acknowledged

  const HrPolicy({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.content,
    this.version = 'v1.0',
    required this.effectiveDate,
    this.isMandatory = true,
    this.acknowledgedBy = const [],
  });

  bool isAcknowledged(String empId) => acknowledgedBy.contains(empId);

  HrPolicy copyWith({
    List<String>? acknowledgedBy,
  }) {
    return HrPolicy(
      id: id,
      title: title,
      category: category,
      summary: summary,
      content: content,
      version: version,
      effectiveDate: effectiveDate,
      isMandatory: isMandatory,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
    );
  }
}

final List<HrPolicy> kDefaultCompanyPolicies = [
  HrPolicy(
    id: 'pol-01',
    title: 'Code of Conduct & Professional Ethics',
    category: 'Company Policy',
    version: 'v2.2',
    effectiveDate: DateTime(2026, 1, 1),
    isMandatory: true,
    summary: 'Standard guidelines on professional workplace behavior, client integrity, respect and ethical business conduct.',
    content: '''
# Code of Conduct & Professional Ethics

### 1. Purpose & Scope
Team N is dedicated to maintaining an inspiring, professional, and respectful environment for all artists, technicians, operations personnel, and leadership. This Code applies across all studios, remote client sites, and digital communication channels.

### 2. Core Expectations
- **Client Dignity & Privacy:** Client personal details, bridal looks, and private photos must remain strictly confidential unless written consent is provided.
- **Punctuality & Reliability:** As bridal artists and operators, punctuality is paramount. Reporting 45 minutes prior to scheduled call-times for weddings and trials is mandatory.
- **Integrity & Honesty:** Zero tolerance for unauthorized product diversions, unapproved commissions, or conflict of interest with competing agencies.

### 3. Mutual Respect & Inclusivity
Every team member has the right to work in an environment free from discrimination, harassment, or verbal mistreatment.
''',
    acknowledgedBy: ['emp-01', 'emp-02'],
  ),
  HrPolicy(
    id: 'pol-02',
    title: 'Attendance, Punctuality & Timebox Rules',
    category: 'HR Policy',
    version: 'v2.0',
    effectiveDate: DateTime(2026, 1, 15),
    isMandatory: true,
    summary: 'Rules on biometric punching, shift adherence, grace periods, regularization deadlines and LOP computations.',
    content: '''
# Attendance & Punctuality Policy

### 1. Shift Adherence & Check-ins
- All staff must record biometric / Timebox check-in upon arriving and check-out upon leaving.
- Grace period is 15 minutes from official shift start time.
- Three late check-ins in a calendar month result in a half-day loss-of-pay (LOP).

### 2. Attendance Regularization
- If a biometric punch is missed due to outdoor assignment, on-duty duty slip or technical failure, regularization requests must be submitted within 48 hours via the ERP portal.
- Submissions beyond 48 hours require Department Head sign-off.

### 3. Unapproved Absence
- Any absence without approved leave in advance is recorded as LOP (Loss of Pay) and impacts monthly composite scoring.
''',
    acknowledgedBy: ['emp-01'],
  ),
  HrPolicy(
    id: 'pol-03',
    title: 'Leave & Time-Off Regulations',
    category: 'HR Policy',
    version: 'v1.8',
    effectiveDate: DateTime(2026, 2, 1),
    isMandatory: true,
    summary: 'Details annual leave quotas, paid casual leaves, medical certification rules, and blackout dates during peak wedding season.',
    content: '''
# Leave & Time-Off Regulations

### 1. Annual Allotment
- Paid Casual Leave (CL): 12 days per year (credited 1 day per month).
- Paid Sick Leave (SL): 6 days per year with medical documentation required for > 2 consecutive days.
- Compensatory Off (Comp-Off): Granted for verified overtime or work on mandatory studio holidays.

### 2. Peak Wedding Season Blackout Dates
- During peak wedding periods (November through February), leaves must be planned at least 45 days in advance and are contingent on booking coverage.
''',
    acknowledgedBy: [],
  ),
  HrPolicy(
    id: 'pol-04',
    title: 'Studio Hygiene, Sanitation & Kit Care',
    category: 'Studio & Hygiene',
    version: 'v3.1',
    effectiveDate: DateTime(2026, 1, 10),
    isMandatory: true,
    summary: 'Strict beauty hygiene standards: tool sterilization, expiration monitoring, vanity cleaning and kit audits.',
    content: '''
# Studio & Kit Hygiene Standards

### 1. Tool Sanitization
- Brushes, sponges, and palettes must be sterilized using hospital-grade sanitizing sprays before and after every client engagement.
- Disposable applicators must be used for mascara and lip products.

### 2. Kit Audits & Product Expiry
- Quarterly kit audits are conducted by the Inventory Manager and Artist Head.
- Any product past its expiration date or with altered texture/scent must be decommissioned immediately.
''',
    acknowledgedBy: ['emp-01'],
  ),
  HrPolicy(
    id: 'pol-05',
    title: 'POSH (Prevention of Sexual Harassment) Policy',
    category: 'Company Policy',
    version: 'v2.0',
    effectiveDate: DateTime(2026, 1, 1),
    isMandatory: true,
    summary: 'Team N zero-tolerance policy against sexual harassment, internal complaint committee process and grievance redressal.',
    content: '''
# Prevention of Sexual Harassment (POSH)

### 1. Policy Statement
Team N enforces a strict zero-tolerance approach toward sexual harassment of any form. We are committed to a safe, supportive, and dignified workplace for all employees, artists, and contractors.

### 2. Grievance Redressal Mechanism
- Reports can be lodged confidentially via the Confidential Grievances portal or directly to the Internal Committee (IC).
- Inquiries are completed with strict confidentiality within 30 days.
''',
    acknowledgedBy: ['emp-01', 'emp-02'],
  ),
  HrPolicy(
    id: 'pol-06',
    title: 'Travel Desk & Expense Reimbursement Policy',
    category: 'Financial & Travel',
    version: 'v1.5',
    effectiveDate: DateTime(2026, 3, 1),
    isMandatory: true,
    summary: 'Allowances, cab limits, outstation hotel caps, advance draw rules and receipt submission timelines.',
    content: '''
# Travel & Expense Reimbursement

### 1. Outstation Bridal Travels
- Transport and lodging are coordinated through the Fleet & Travel desk.
- Daily food & incidental allowances follow standard tier-based limits (Tier 1 vs Tier 2 cities).

### 2. Claim Submission
- All expense receipts must be uploaded within 7 days of trip conclusion.
- Approved claims are reimbursed in the subsequent bi-weekly pay cycle.
''',
    acknowledgedBy: [],
  ),
];
