import 'dart:developer';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/hr/letters/utils/nizan_hr_document_pdf.dart';
import 'package:nizan_crm/features/hr/recruitment/data/recruitment_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generates 4-page offer letter matching Salmanul Faris sample PDF', () async {
    final offer = Offer(
      id: 'offer-test-123',
      candidateName: 'SALMANUL FARIS A.T',
      designation: 'Marketing Manager',
      department: 'Marketing',
      salary: 75000,
      basicSalary: 75000,
      hra: 0,
      incentive: 5000,
      reportingTo: 'HR Manager',
      joiningDate: DateTime(2026, 9, 3),
      status: 'sent',
    );

    final pdfBytes = await generateOfferLetterPdf(
      offer: offer,
      issueDate: DateTime(2026, 9, 2),
    );

    expect(pdfBytes, isNotEmpty);
    expect(pdfBytes.length, greaterThan(1000));

    final testOutDir = Directory('/Users/muhammedrisan/.gemini/antigravity-ide/brain/5dee468e-3b2d-4ed5-8c71-2bef32394d19/scratch');
    if (!testOutDir.existsSync()) {
      testOutDir.createSync(recursive: true);
    }
    final outFile = File('${testOutDir.path}/test_salmanul_offer.pdf');
    await outFile.writeAsBytes(pdfBytes);
    log('Saved test PDF to: ${outFile.path}');
  });

  test('Generates offer letter with HRA and incentive', () async {
    final offerWithHra = Offer(
      id: 'offer-test-hra',
      candidateName: 'Rahul Sharma',
      designation: 'Senior Marketing Lead',
      department: 'Marketing',
      salary: 80000,
      basicSalary: 60000,
      hra: 20000,
      incentive: 10000,
      reportingTo: 'Marketing Director',
      joiningDate: DateTime(2026, 10, 1),
      status: 'sent',
    );

    final pdfBytes = await generateOfferLetterPdf(
      offer: offerWithHra,
      issueDate: DateTime(2026, 9, 15),
    );

    expect(pdfBytes, isNotEmpty);
    final outFile = File('/Users/muhammedrisan/.gemini/antigravity-ide/brain/5dee468e-3b2d-4ed5-8c71-2bef32394d19/scratch/test_hra_offer.pdf');
    await outFile.writeAsBytes(pdfBytes);
    print('Saved HRA test PDF to: ${outFile.path}');
  });
}
