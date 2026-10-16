import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart' show CsvDecoder;
import 'package:excel/excel.dart';

/// Parsed candidate data extracted from an uploaded spreadsheet/CSV.
class CandidateImportRow {
  final String fullName;
  final String? email;
  final String? phone;
  final String? resumeUrl;
  final String? experience;
  final String? location;
  final String? linkedinUrl;
  final String? status;
  final String stage; // 'hired', 'interview', 'screening', 'rejected', 'applied'
  final bool isRecruited; // true if status is 'SELECTED' / 'HIRED' or row highlighted in green
  final String? notes;

  const CandidateImportRow({
    required this.fullName,
    this.email,
    this.phone,
    this.resumeUrl,
    this.experience,
    this.location,
    this.linkedinUrl,
    this.status,
    this.stage = 'applied',
    this.isRecruited = false,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        if (email != null && email!.isNotEmpty) 'email': email,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (resumeUrl != null && resumeUrl!.isNotEmpty) 'resumeUrl': resumeUrl,
        if (experience != null && experience!.isNotEmpty) 'experience': experience,
        if (location != null && location!.isNotEmpty) 'location': location,
        if (linkedinUrl != null && linkedinUrl!.isNotEmpty) 'linkedinUrl': linkedinUrl,
        if (status != null && status!.isNotEmpty) 'status': status,
        'stage': stage,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

/// Result of parsing an Excel or CSV file.
class CandidateFileImportResult {
  final List<CandidateImportRow> candidates;
  final List<String> warnings;
  final int totalRows;
  final int skippedRows;
  final String? detectedHeaders;

  const CandidateFileImportResult({
    required this.candidates,
    this.warnings = const [],
    required this.totalRows,
    required this.skippedRows,
    this.detectedHeaders,
  });

  /// Count of candidates marked as SELECTED / HIRED / RECRUITED (e.g. green-marked)
  int get recruitedCount => candidates.where((c) => c.isRecruited).length;

  /// List of only recruited/selected candidates
  List<CandidateImportRow> get recruitedCandidates => candidates.where((c) => c.isRecruited).toList();
}

/// Parses an uploaded Excel (.xlsx, .xls) or CSV (.csv) file into candidate rows.
CandidateFileImportResult parseCandidateFile(
  Uint8List bytes,
  String filename, {
  String? sheetName,
}) {
  final lower = filename.toLowerCase();
  List<List<dynamic>> rawRows;
  Set<int> greenRowIndices = {};

  try {
    if (lower.endsWith('.csv')) {
      rawRows = _readCsv(bytes);
    } else {
      final res = _readXlsxWithStyles(bytes, sheetName);
      rawRows = res.rows;
      greenRowIndices = res.greenRowIndices;
    }
  } catch (e) {
    return CandidateFileImportResult(
      candidates: const [],
      warnings: ['Could not read file "$filename": $e. Ensure it is not corrupted or password-protected.'],
      totalRows: 0,
      skippedRows: 0,
    );
  }

  // Filter out completely empty rows
  final rowsWithIdx = <MapEntry<int, List<dynamic>>>[];
  for (var i = 0; i < rawRows.length; i++) {
    if (rawRows[i].any((c) => _asStr(c).isNotEmpty)) {
      rowsWithIdx.add(MapEntry(i, rawRows[i]));
    }
  }

  if (rowsWithIdx.isEmpty) {
    return const CandidateFileImportResult(
      candidates: [],
      warnings: ['The uploaded file is empty or contains no readable text.'],
      totalRows: 0,
      skippedRows: 0,
    );
  }

  // Step 1: Detect header row (within the first 15 rows)
  var headerIdx = -1;
  var colMap = <int, String>{};
  final scanLimit = rowsWithIdx.length < 15 ? rowsWithIdx.length : 15;

  for (var i = 0; i < scanLimit; i++) {
    final row = rowsWithIdx[i].value;
    final candidateMap = <int, String>{};
    for (var c = 0; c < row.length; c++) {
      final headerStr = _asStr(row[c]);
      final field = _fieldForHeader(headerStr);
      if (field != null) {
        candidateMap[c] = field;
      }
    }
    // A valid header row should at least detect a name, email, or phone
    final hasContactInfo = candidateMap.containsValue('fullName') ||
        candidateMap.containsValue('firstName') ||
        candidateMap.containsValue('email') ||
        candidateMap.containsValue('phone');

    if (hasContactInfo && candidateMap.length > colMap.length) {
      headerIdx = i;
      colMap = candidateMap;
    }
  }

  final candidates = <CandidateImportRow>[];
  final warnings = <String>[];
  var skipped = 0;

  // Step 2: Extract rows based on detected headers
  if (headerIdx >= 0) {
    final startRow = headerIdx + 1;
    for (var r = startRow; r < rowsWithIdx.length; r++) {
      final origIdx = rowsWithIdx[r].key;
      final row = rowsWithIdx[r].value;
      final values = <String, String>{};

      colMap.forEach((colIndex, fieldName) {
        if (colIndex < row.length) {
          final val = _asStr(row[colIndex]);
          if (val.isNotEmpty) {
            values[fieldName] = val;
          }
        }
      });

      // Name composition (support First + Last or Full Name)
      String fullName = values['fullName'] ?? '';
      if (fullName.isEmpty) {
        final first = values['firstName'] ?? '';
        final last = values['lastName'] ?? '';
        fullName = '$first $last'.trim();
      }

      final email = _cleanEmail(values['email']);
      final phone = _cleanPhone(values['phone']);
      final resumeUrl = values['resumeUrl'] ?? values['portfolio'] ?? '';
      final experience = values['experience'] ?? '';
      final location = values['location'] ?? '';
      final linkedin = values['linkedinUrl'] ?? '';
      final notes = values['notes'] ?? '';

      // Skip row if completely devoid of identifiable info
      if (fullName.isEmpty && email == null && phone == null) {
        skipped++;
        continue;
      }

      // If full name is missing, use email prefix or phone as placeholder
      if (fullName.isEmpty) {
        if (email != null && email.contains('@')) {
          fullName = email.split('@').first.replaceAll(RegExp(r'[._\-]'), ' ');
        } else if (phone != null) {
          fullName = 'Applicant ($phone)';
        } else {
          fullName = 'Applicant';
        }
      }

      // Check status & green highlight
      final rowText = row.map(_asStr).join(' ').toUpperCase();
      final isGreen = greenRowIndices.contains(origIdx);
      final eval = _evaluateStatusAndStage(rowText, values['status'], isGreen);

      candidates.add(CandidateImportRow(
        fullName: fullName,
        email: email,
        phone: phone,
        resumeUrl: resumeUrl.isNotEmpty ? resumeUrl : null,
        experience: experience.isNotEmpty ? experience : null,
        location: location.isNotEmpty ? location : null,
        linkedinUrl: linkedin.isNotEmpty ? linkedin : null,
        status: eval.status,
        stage: eval.stage,
        isRecruited: eval.isRecruited,
        notes: notes.isNotEmpty ? notes : null,
      ));
    }
  } else {
    // Step 3: Fallback heuristic row parsing (when no standard header row exists)
    warnings.add('No standard header row detected. Using automatic column recognition.');
    for (var r = 0; r < rowsWithIdx.length; r++) {
      final origIdx = rowsWithIdx[r].key;
      final row = rowsWithIdx[r].value;
      String? name;
      String? email;
      String? phone;
      String? resume;
      String? linkedin;
      String? location;
      String? exp;
      String? explicitStatus;

      for (final cell in row) {
        final str = _asStr(cell);
        if (str.isEmpty) continue;

        if (email == null && str.contains('@') && RegExp(r'^[\w\-.]+@[\w\-.]+\.[a-zA-Z]{2,}$').hasMatch(str)) {
          email = str.toLowerCase();
        } else if (resume == null && (str.startsWith('http://') || str.startsWith('https://')) && !str.contains('linkedin.com')) {
          resume = str;
        } else if (linkedin == null && str.contains('linkedin.com')) {
          linkedin = str;
        } else if (phone == null && _looksLikePhone(str)) {
          phone = _cleanPhone(str);
        } else if (exp == null && (str.toLowerCase().contains('month') || str.toLowerCase().contains('year') || str.toLowerCase().contains('yr'))) {
          exp = str;
        } else if (_isKnownCityOrPlace(str)) {
          location = str;
        } else if (_isStatusKeyword(str)) {
          explicitStatus = explicitStatus == null ? str : '$explicitStatus | $str';
        } else if (name == null && !str.contains('http') && !str.contains('@') && !_isDateOrTime(str) && str.length > 2 && num.tryParse(str) == null) {
          name = str;
        }
      }

      if (name != null || email != null || phone != null) {
        final rowText = row.map(_asStr).join(' ').toUpperCase();
        final isGreen = greenRowIndices.contains(origIdx);
        final eval = _evaluateStatusAndStage(rowText, explicitStatus, isGreen);

        candidates.add(CandidateImportRow(
          fullName: name ?? (email != null ? email.split('@').first : 'Applicant'),
          email: email,
          phone: phone,
          resumeUrl: resume,
          location: location,
          experience: exp,
          linkedinUrl: linkedin,
          status: eval.status,
          stage: eval.stage,
          isRecruited: eval.isRecruited,
        ));
      } else {
        skipped++;
      }
    }
  }

  return CandidateFileImportResult(
    candidates: candidates,
    warnings: warnings,
    totalRows: rowsWithIdx.length - (headerIdx >= 0 ? headerIdx + 1 : 0),
    skippedRows: skipped,
    detectedHeaders: colMap.values.join(', '),
  );
}

// ─── Status & Stage Evaluator ────────────────────────────────────────────────

class _StatusEvaluation {
  final String? status;
  final String stage;
  final bool isRecruited;

  const _StatusEvaluation({this.status, required this.stage, required this.isRecruited});
}

_StatusEvaluation _evaluateStatusAndStage(String combinedRowText, String? explicitStatus, bool isGreen) {
  final upper = combinedRowText.toUpperCase();

  if (isGreen ||
      upper.contains('SELECTED') ||
      upper.contains('RECRUITED') ||
      upper.contains('HIRED') ||
      upper.contains('ACCEPTED') ||
      upper.contains('JOINED')) {
    return _StatusEvaluation(
      status: explicitStatus ?? 'SELECTED',
      stage: 'hired',
      isRecruited: true,
    );
  }

  if (upper.contains('ATTENDED') || (upper.contains('ATTEND') && !upper.contains('NOT ATTEND'))) {
    return _StatusEvaluation(
      status: explicitStatus ?? 'ATTENDED',
      stage: 'interview',
      isRecruited: false,
    );
  }

  if (upper.contains('CALL BACK') || upper.contains('CALLBACK')) {
    return _StatusEvaluation(
      status: explicitStatus ?? 'CALL BACK',
      stage: 'screening',
      isRecruited: false,
    );
  }

  if (upper.contains('NOT ATTEND') ||
      upper.contains('NOT INTERESTED') ||
      upper.contains('RELOCATION') ||
      upper.contains('REJECT') ||
      upper.contains('NO LAP')) {
    String st = explicitStatus ?? 'REJECTED';
    if (upper.contains('RELOCATION')) st = 'RELOCATION PROBLEM';
    if (upper.contains('NOT INTERESTED')) st = 'NOT INTERESTED';
    if (upper.contains('NOT ATTEND')) st = 'NOT ATTEND';
    if (upper.contains('NO LAP')) st = 'NO LAP CALL BACK';

    return _StatusEvaluation(
      status: st,
      stage: 'rejected',
      isRecruited: false,
    );
  }

  return _StatusEvaluation(
    status: explicitStatus,
    stage: 'applied',
    isRecruited: false,
  );
}

bool _isStatusKeyword(String s) {
  final u = s.toUpperCase();
  return u == 'SELECTED' ||
      u == 'ATTEND' ||
      u == 'ATTENDED' ||
      u == 'NOT ATTEND' ||
      u == 'NOT INTERESTED' ||
      u == 'RELOCATION PROBLEM' ||
      u == 'CALL BACK' ||
      u == 'NO LAP' ||
      u == 'NO LAP CALL BACK' ||
      u == 'SHORTLISTED' ||
      u == 'REJECTED';
}

bool _isKnownCityOrPlace(String s) {
  const places = [
    'wayanad', 'vadakara', 'thrissur', 'malappuram', 'kozhikode',
    'calicut', 'koyilandy', 'neelikulam', 'kannur', 'ernakulam',
    'kochi', 'palakkad', 'trivandrum', 'thiruvananthapuram', 'kollam',
    'alappuzha', 'kottayam', 'idukki', 'kasaragod', 'pathanamthitta',
    'bangalore', 'bengaluru', 'mumbai', 'dubai', 'sharjah'
  ];
  return places.contains(s.trim().toLowerCase());
}

bool _isDateOrTime(String s) {
  final clean = s.trim();
  if (RegExp(r'^\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}$').hasMatch(clean)) return true;
  if (RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(clean)) return true;
  return false;
}

// ─── Header Matching ────────────────────────────────────────────────────────

String? _fieldForHeader(String raw) {
  final norm = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (norm.isEmpty) return null;

  // Name
  if (norm == 'fullname' || norm == 'candidatename' || norm == 'applicantname' || norm == 'name') {
    return 'fullName';
  }
  if (norm == 'firstname' || norm == 'fname') return 'firstName';
  if (norm == 'lastname' || norm == 'lname' || norm == 'surname') return 'lastName';

  // Email
  if (norm.contains('email') || norm == 'mail' || norm == 'emailaddress' || norm == 'contactemail') {
    return 'email';
  }

  // Phone
  if (norm.contains('phone') || norm.contains('mobile') || norm.contains('contactno') || norm.contains('contactnumber') || norm == 'tel' || norm == 'whatsapp') {
    return 'phone';
  }

  // Location / City / Place
  if (norm == 'location' || norm == 'city' || norm == 'place' || norm == 'district' || norm == 'address') {
    return 'location';
  }

  // Status / Decision / Remarks
  if (norm == 'status' || norm == 'decision' || norm == 'remarks' || norm == 'remark' || norm == 'result' || norm == 'interviewstatus') {
    return 'status';
  }

  // Resume / CV Link
  if (norm.contains('resume') || norm.contains('cv') || norm.contains('curriculumvitae') || norm.contains('drivelink') || norm.contains('portfolio') || norm.contains('fileurl')) {
    return 'resumeUrl';
  }

  // Experience
  if (norm.contains('experience') || norm == 'exp' || norm.contains('yearsofexperience') || norm.contains('workexperience')) {
    return 'experience';
  }

  // LinkedIn
  if (norm.contains('linkedin') || norm.contains('profileurl') || norm.contains('socialprofile')) {
    return 'linkedinUrl';
  }

  // Notes / Job Title
  if (norm.contains('notes') || norm.contains('comment') || norm.contains('jobtitle') || norm.contains('position')) {
    return 'notes';
  }

  return null;
}

// ─── Helpers ────────────────────────────────────────────────────────────────

bool _looksLikePhone(String s) {
  final digits = s.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 7 && digits.length <= 15;
}

String? _cleanPhone(String? s) {
  if (s == null) return null;
  var val = s.trim();
  if (val.endsWith('.0')) {
    val = val.substring(0, val.length - 2);
  }
  final clean = val.replaceAll(RegExp(r'[^\d+]'), '');
  return clean.isNotEmpty ? clean : null;
}

String? _cleanEmail(String? s) {
  if (s == null) return null;
  final email = s.trim().toLowerCase();
  if (email.contains('@') && email.contains('.')) return email;
  return null;
}

String _asStr(dynamic v) {
  if (v == null) return '';
  if (v is String) return v.trim();
  final s = v.toString().trim();
  if (s.endsWith('.0') && num.tryParse(s) != null) {
    return s.substring(0, s.length - 2);
  }
  return s;
}

List<List<dynamic>> _readCsv(Uint8List bytes) {
  final text = utf8
      .decode(bytes, allowMalformed: true)
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  return const CsvDecoder(parseHeaders: false, dynamicTyping: false).convert(text);
}

class _ExcelReadResult {
  final List<List<dynamic>> rows;
  final Set<int> greenRowIndices;
  const _ExcelReadResult(this.rows, this.greenRowIndices);
}

_ExcelReadResult _readXlsxWithStyles(Uint8List bytes, [String? sheetName]) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) return const _ExcelReadResult([], {});
  final sheet = (sheetName != null && excel.tables.containsKey(sheetName))
      ? excel.tables[sheetName]!
      : excel.tables.values.firstWhere(
          (s) => s.maxRows > 0,
          orElse: () => excel.tables.values.first,
        );

  final List<List<dynamic>> rows = [];
  final Set<int> greenRows = {};

  for (var rIdx = 0; rIdx < sheet.rows.length; rIdx++) {
    final rowCells = sheet.rows[rIdx];
    final rowVals = <dynamic>[];
    var isGreen = false;

    for (final cell in rowCells) {
      rowVals.add(_cellRaw(cell));
      final styleStr = cell?.cellStyle?.toString().toLowerCase() ?? '';
      if (styleStr.contains('00ff00') || styleStr.contains('green') || styleStr.contains('34a853') || styleStr.contains('22c55e')) {
        isGreen = true;
      }
    }
    rows.add(rowVals);
    if (isGreen) greenRows.add(rIdx);
  }

  return _ExcelReadResult(rows, greenRows);
}

dynamic _cellRaw(Data? cell) {
  final v = cell?.value;
  if (v == null) return null;
  return switch (v) {
    TextCellValue() => v.value.toString(),
    IntCellValue() => v.value,
    DoubleCellValue() => v.value,
    BoolCellValue() => v.value,
    DateCellValue() => v.asDateTimeLocal().toIso8601String().split('T').first,
    DateTimeCellValue() => v.asDateTimeLocal().toIso8601String(),
    TimeCellValue() => v.toString(),
    FormulaCellValue() => v.formula,
  };
}

/// Generates a standard CSV sample template that recruiters can download or view.
String getRecruitmentSampleCsvTemplate() {
  return '''Full Name,Email,Phone,Location,Experience,Interview Status,Decision
FATHIMA LIYA M,cbfathimaliyam6464@gmail.com,9947351694,Calicut,1 Year,ATTEND,SELECTED
NIHMA P,nihmanihma073@gmail.com,8592941931,Malappuram,Fresher,ATTEND,ATTENDED
AHAMMED SAFWAN K,ahammedsafwank@gmail.com,9605665925,Malappuram,6 Months,CALL BACK,CALL BACK
JAMSHIYA NASSIR,jamshiyanassir000@gmail.com,8848225960,Wayanad,1 Year,NOT INTERESTED,NOT INTERESTED
''';
}
