import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/hr/recruitment/utils/recruitment_file_import.dart';

void main() {
  group('Recruitment File Import Tests', () {
    test('Parses CSV with standard headers correctly', () {
      const csvData = '''Full Name,Email,Phone,Resume Link,Experience,LinkedIn
Amina Khan,amina@test.com,+919876543210,https://drive.google.com/amina.pdf,4 Years,https://linkedin.com/in/amina
Bilal Ahmed,bilal@test.com,+919876543211,https://dropbox.com/bilal.pdf,2 Years,https://linkedin.com/in/bilal
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final res = parseCandidateFile(bytes, 'leads_october.csv');

      expect(res.candidates.length, 2);
      expect(res.candidates[0].fullName, 'Amina Khan');
      expect(res.candidates[0].email, 'amina@test.com');
      expect(res.candidates[0].phone, '+919876543210');
      expect(res.candidates[0].resumeUrl, 'https://drive.google.com/amina.pdf');
      expect(res.candidates[0].experience, '4 Years');
      expect(res.candidates[0].linkedinUrl, 'https://linkedin.com/in/amina');

      expect(res.candidates[1].fullName, 'Bilal Ahmed');
      expect(res.candidates[1].email, 'bilal@test.com');
    });

    test('Parses Meta Lead Gen CSV format with first_name and last_name', () {
      const metaCsv = '''first_name,last_name,email,phone_number,portfolio_link
Zoya,Shaikh,zoya@example.com,9876543212,https://instagram.com/zoya_art
Rohan,Das,rohan@example.com,9876543213,https://drive.google.com/cv.pdf
''';
      final bytes = Uint8List.fromList(utf8.encode(metaCsv));
      final res = parseCandidateFile(bytes, 'meta_facebook_leads.csv');

      expect(res.candidates.length, 2);
      expect(res.candidates[0].fullName, 'Zoya Shaikh');
      expect(res.candidates[0].email, 'zoya@example.com');
      expect(res.candidates[0].phone, '9876543212');
      expect(res.candidates[0].resumeUrl, 'https://instagram.com/zoya_art');

      expect(res.candidates[1].fullName, 'Rohan Das');
    });

    test('Cleans floating point excel formatted phones and emails', () {
      const csvData = '''Candidate Name,Phone Number,Email Address
Kavita,9876543210.0,kavita@domain.com
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final res = parseCandidateFile(bytes, 'exported_list.csv');

      expect(res.candidates.length, 1);
      expect(res.candidates[0].fullName, 'Kavita');
      expect(res.candidates[0].phone, '9876543210');
      expect(res.candidates[0].email, 'kavita@domain.com');
    });

    test('Parses interview tracking sheet and isolates SELECTED candidate', () {
      const interviewSheetCsv = '''Sl No,Date,Candidate Name,Mobile,Email,Place,Exp,Interview Date,Time,Status,Decision
1,22/09/2026,RISHANA KA,8848324152,rishanak826@gmail.com,Wayanad,4 month,,,NO LAP CALL BACK,
2,22/09/2026,SAFA FATHIMA T T,9605787132,safatt313@gmail.com,Vadakara,,,NOT ATTEND,
14,22/09/2026,NIHMA P,8592941931,nihmanihma073@gmail.com,Malappuram,,22/09/2026,02:00,ATTEND,ATTENDED
15,22/09/2026,FATHIMA LIYA M,9947351694,cbfathimaliyam6464@gmail.com,Calicut,,22/09/2026,02:00,ATTEND,SELECTED
''';
      final bytes = Uint8List.fromList(utf8.encode(interviewSheetCsv));
      final res = parseCandidateFile(bytes, 'interview_tracker.csv');

      expect(res.candidates.length, 4);

      // Verify FATHIMA LIYA M is identified as the recruited candidate
      expect(res.recruitedCount, 1);
      final recruited = res.recruitedCandidates;
      expect(recruited.length, 1);
      expect(recruited[0].fullName, 'FATHIMA LIYA M');
      expect(recruited[0].phone, '9947351694');
      expect(recruited[0].email, 'cbfathimaliyam6464@gmail.com');
      expect(recruited[0].location, 'Calicut');
      expect(recruited[0].isRecruited, true);
      expect(recruited[0].stage, 'hired');

      // Verify NIHMA P was attended (interview stage)
      final nihma = res.candidates.firstWhere((c) => c.fullName == 'NIHMA P');
      expect(nihma.stage, 'interview');

      // Verify non-attendees are marked as rejected
      final safa = res.candidates.firstWhere((c) => c.fullName == 'SAFA FATHIMA T T');
      expect(safa.stage, 'rejected');
    });
  });
}
