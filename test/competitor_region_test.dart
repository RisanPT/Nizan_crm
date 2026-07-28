import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/marketing/data/marketing_models.dart';

void main() {
  group('Competitor region', () {
    test('parses regionId as a plain string and region name', () {
      final c = Competitor.fromJson({
        '_id': '1',
        'name': 'Glow Studio',
        'regionId': 'reg123',
        'region': 'Ernakulam',
      });
      expect(c.regionId, 'reg123');
      expect(c.region, 'Ernakulam');
    });

    test('parses a populated regionId object', () {
      final c = Competitor.fromJson({
        '_id': '1',
        'name': 'Glow Studio',
        'regionId': {'_id': 'reg123', 'name': 'Ernakulam'},
        'region': 'Ernakulam',
      });
      expect(c.regionId, 'reg123');
    });

    test('defaults to empty when region is absent', () {
      final c = Competitor.fromJson({'_id': '1', 'name': 'X'});
      expect(c.regionId, '');
      expect(c.region, '');
    });

    test('toJson carries region fields for the API', () {
      const c = Competitor(
        id: '1',
        name: 'X',
        regionId: 'reg123',
        region: 'Ernakulam',
      );
      final j = c.toJson();
      expect(j['regionId'], 'reg123');
      expect(j['region'], 'Ernakulam');
    });
  });
}
