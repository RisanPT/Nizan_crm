import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/lead_activity.dart';
import 'package:nizan_crm/features/sales/presentation/screens/sales_leads_screen.dart' show kLeadSources, coerceLeadSource;

// The CRM lead fields the Marketing Lead Report reads: how a follow-up is done (LeadActivity.channel) and "Website" as a lead source.

void main() {
  group('follow-up type (channel)', () {
    test('reads and writes the channel; an older entry without one reads as not said', () {
      final a = LeadActivity.fromJson({'_id': 'a1', 'leadId': 'l1', 'type': 'followup', 'channel': 'whatsapp', 'scheduledDate': '2026-11-20T06:30:00.000Z', 'status': 'Pending'});
      expect(a.channel, 'whatsapp');
      expect(a.toJson()['channel'], 'whatsapp');
      final old = LeadActivity.fromJson({'_id': 'a2', 'leadId': 'l1', 'type': 'followup', 'scheduledDate': '2026-11-20T06:30:00.000Z'});
      expect(old.channel, '');
      expect(old.toJson().containsKey('channel'), isFalse, reason: 'nothing is invented for an entry that never had one');
    });

    test('the choices are the server\'s list (call, WhatsApp, visit, meeting, other), with plain labels', () {
      expect(kFollowUpChannels.map((c) => c.$1), ['call', 'whatsapp', 'visit', 'meeting', 'other']);
      expect(followUpChannelName('whatsapp'), 'WhatsApp');
      expect(followUpChannelName('meeting'), 'Meeting');
      expect(followUpChannelName(''), '');
      expect(followUpChannelName('pigeon'), '');
    });
  });

  group('lead source', () {
    test('"Website" is a CRM lead source, and older spellings of it are read as Website', () {
      expect(kLeadSources, contains('Website'));
      expect(coerceLeadSource('Website'), 'Website');
      expect(coerceLeadSource('website form'), 'Website');
      expect(coerceLeadSource('Web site'), 'Website');
      expect(coerceLeadSource('Webinar'), 'Other', reason: 'only the website, not anything that starts with "web"');
      expect(coerceLeadSource('Walk-in'), 'Walk-in');
    });
  });
}
