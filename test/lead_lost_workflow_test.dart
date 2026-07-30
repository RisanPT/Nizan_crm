import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';
import 'package:nizan_crm/features/sales/presentation/screens/sales_leads_screen.dart';

/// Covers the Lead Management enhancements: Event Type, Alternate Number and the
/// lost-approval workflow (statuses, reviewer roles, model round-trip).
void main() {
  group('outcome statuses', () {
    test('Lost is an outcome option but not a plain picker status', () {
      expect(kLeadStatuses.contains('Lost'), isFalse);
      expect(kOutcomeStatuses.contains('Lost'), isTrue);
      // The pickers are a strict prefix of the outcome options.
      expect(kOutcomeStatuses.take(kLeadStatuses.length).toList(), kLeadStatuses);
    });

    test('Pending Lost Approval is a known status but never a picker option', () {
      expect(kAllLeadStatuses.contains('Pending Lost Approval'), isTrue);
      expect(kLeadStatuses.contains('Pending Lost Approval'), isFalse);
      expect(kOutcomeStatuses.contains('Pending Lost Approval'), isFalse);
      expect(kLeadStatusFilters.contains('Pending Lost Approval'), isTrue);
    });

    test('coerceLeadStatus maps system states onto a selectable picker value', () {
      for (final s in ['Lost', 'Pending Lost Approval', 'Converted']) {
        expect(kLeadStatuses.contains(coerceLeadStatus(s)), isTrue);
      }
    });
  });

  group('isLostReviewer', () {
    test('managers, regional managers and admin can review', () {
      expect(isLostReviewer('admin'), isTrue);
      expect(isLostReviewer('manager'), isTrue);
      expect(isLostReviewer('sales_manager'), isTrue);
      expect(isLostReviewer('regional_manager'), isTrue);
    });

    test('sales executives and unknown roles cannot review', () {
      expect(isLostReviewer('sales'), isFalse);
      expect(isLostReviewer('crm'), isFalse);
      expect(isLostReviewer(''), isFalse);
      expect(isLostReviewer(null), isFalse);
    });
  });

  group('event types', () {
    test('covers the required wedding/event catalogue', () {
      for (final t in ['Wedding', 'Reception', 'Engagement', 'Haldi', 'Mehendi',
          'Sangeet', 'Baby Shower', 'Birthday', 'Corporate Event', 'Photoshoot',
          'Fashion Show', 'Celebrity Event', 'Housewarming', 'Other']) {
        expect(kEventTypes.contains(t), isTrue, reason: '$t missing from kEventTypes');
      }
    });
  });

  group('Lead model — new fields', () {
    Map<String, dynamic> base() => {
          '_id': '1',
          'name': 'A',
          'phone': '9876543210',
          'status': 'New',
          'reason': '',
          'remarks': '',
        };

    test('parses eventType, alternateNumber and lost-workflow fields', () {
      final lead = Lead.fromJson({
        ...base(),
        'eventType': 'Wedding',
        'alternateNumber': '9000000000',
        'competitorName': 'Rival Studio',
        'lostDecision': 'approved',
        'lostReviewNote': 'confirmed lost',
      });
      expect(lead.eventType, 'Wedding');
      expect(lead.alternateNumber, '9000000000');
      expect(lead.competitorName, 'Rival Studio');
      expect(lead.lostDecision, 'approved');
      expect(lead.lostReviewNote, 'confirmed lost');
    });

    test('new fields default to empty when absent', () {
      final lead = Lead.fromJson(base());
      expect(lead.eventType, '');
      expect(lead.alternateNumber, '');
      expect(lead.competitorName, '');
      expect(lead.lostDecision, '');
    });

    test('toJson carries eventType and alternateNumber for the API', () {
      final lead = Lead.fromJson({
        ...base(),
        'eventType': 'Reception',
        'alternateNumber': '9000000000',
      });
      final json = lead.toJson();
      expect(json['eventType'], 'Reception');
      expect(json['alternateNumber'], '9000000000');
    });
  });
}
