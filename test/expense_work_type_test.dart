import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';

ArtistExpense _fromJson(Map<String, dynamic> json) =>
    ArtistExpense.fromJson({
      '_id': 'e1',
      'amount': 500,
      'date': '2026-07-22T00:00:00.000Z',
      'status': 'pending',
      ...json,
    });

void main() {
  group('ArtistExpense.workType', () {
    test('parses bridal and model_shoot', () {
      expect(_fromJson({'workType': 'bridal'}).workType, 'bridal');
      expect(_fromJson({'workType': 'model_shoot'}).workType, 'model_shoot');
    });

    test('defaults to bridal for expenses logged before the field existed', () {
      expect(_fromJson({}).workType, 'bridal');
    });

    test('is independent of category — both survive together', () {
      final e = _fromJson({'category': 'travel', 'workType': 'model_shoot'});
      expect(e.category, 'travel');
      expect(e.workType, 'model_shoot');
    });
  });

  group('expense split', () {
    // Mirrors the totals shown above the artist expense list.
    double bridal(List<ArtistExpense> xs) => xs
        .where((e) => e.workType != 'model_shoot')
        .fold(0.0, (s, e) => s + e.amount);
    double shoot(List<ArtistExpense> xs) => xs
        .where((e) => e.workType == 'model_shoot')
        .fold(0.0, (s, e) => s + e.amount);

    test('separates the two streams and legacy rows count as bridal', () {
      final items = [
        _fromJson({'amount': 500, 'workType': 'bridal'}),
        _fromJson({'amount': 300, 'workType': 'model_shoot'}),
        _fromJson({'amount': 200}), // legacy, no workType
        _fromJson({'amount': 100, 'workType': 'model_shoot'}),
      ];
      expect(bridal(items), 700); // 500 + 200 legacy
      expect(shoot(items), 400); // 300 + 100
      // Nothing is lost or double counted.
      expect(bridal(items) + shoot(items),
          items.fold<double>(0, (s, e) => s + e.amount));
    });
  });
}
