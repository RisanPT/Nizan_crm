import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/marketing/data/marketing_models.dart';

void main() {
  group('CompetitorSnapshot.signalLinks', () {
    test('parses per-signal reel/post links', () {
      final s = CompetitorSnapshot.fromJson({
        '_id': 's1',
        'competitor': 'c1',
        'weekOf': '2026-07-20T00:00:00.000Z',
        'viralContent': true,
        'signalEvidence': {'viralContent': '12x median engagement'},
        'signalLinks': {'viralContent': 'https://instagram.com/reel/abc'},
      });
      expect(s.signalLinks['viralContent'], 'https://instagram.com/reel/abc');
      expect(s.signalEvidence['viralContent'], '12x median engagement');
    });

    test('missing links default to empty map, not null', () {
      final s = CompetitorSnapshot.fromJson({
        '_id': 's1',
        'competitor': 'c1',
        'weekOf': '2026-07-20T00:00:00.000Z',
      });
      expect(s.signalLinks, isEmpty);
    });
  });

  group('ScoreSignal.link', () {
    test('parses the link on a triggered signal', () {
      final sig = ScoreSignal.fromJson({
        'key': 'qualityCreative',
        'label': 'Quality creative',
        'points': 5,
        'evidence': 'clean edit, strong hook',
        'link': 'https://instagram.com/p/xyz',
      });
      expect(sig.link, 'https://instagram.com/p/xyz');
      expect(sig.points, 5);
    });

    test('defaults link to empty when absent', () {
      final sig = ScoreSignal.fromJson({
        'key': 'newService',
        'label': 'New service',
        'points': 2,
      });
      expect(sig.link, '');
    });
  });
}
