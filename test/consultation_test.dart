import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/consultations/data/consultation.dart';
import 'package:nizan_crm/features/consultations/data/consultation_summary.dart';
import 'package:nizan_crm/features/consultations/presentation/widgets/consultation_ui.dart';
import 'package:nizan_crm/features/consultations/services/consultation_service.dart';

Map<String, dynamic> _json({bool withNotes = true}) => {
      '_id': 'c1',
      'consultationNo': 'CN-261102-4821',
      'leadId': {
        '_id': 'l1',
        'name': 'Anjali Menon',
        'phone': '9876543210',
        'eventType': 'Wedding',
        'eventDate': '2026-12-12T00:00:00.000Z',
        'location': 'Kochi',
        'status': 'Contacted',
      },
      'stylistId': {'_id': 's1', 'name': 'Riya'},
      'scheduledAt': '2026-11-02T04:30:00.000Z',
      'endsAt': '2026-11-02T05:15:00.000Z',
      'durationMins': 45,
      'status': 'Scheduled',
      'mode': 'Video',
      'meetingProvider': 'Google Meet',
      'meetingLink': 'https://meet.google.com/abc-defg-hij',
      if (withNotes) 'notes': 'Likes a soft glam look',
      'history': [
        {
          'action': 'Scheduled',
          'status': 'Scheduled',
          'at': '2026-10-30T06:00:00.000Z',
          'byName': 'Riya',
          'fields': ['mode'],
        },
      ],
    };

void main() {
  group('Consultation.fromJson', () {
    test('parses a populated consultation', () {
      final c = Consultation.fromJson(_json());
      expect(c.id, 'c1');
      expect(c.lead.name, 'Anjali Menon');
      expect(c.lead.eventDate, isNotNull);
      expect(c.stylistId, 's1');
      expect(c.stylistName, 'Riya');
      expect(c.durationMins, 45);
      expect(c.isScheduled, isTrue);
      expect(c.isVideo, isTrue);
      expect(c.meetingProvider, 'Google Meet');
      expect(c.history.single.action, 'Scheduled');
      expect(c.history.single.fields, ['mode']);
      expect(c.endsAt.difference(c.scheduledAt).inMinutes, 45);
    });

    test('notesVisible reflects whether the server sent notes', () {
      expect(Consultation.fromJson(_json()).notesVisible, isTrue);
      expect(Consultation.fromJson(_json(withNotes: false)).notesVisible, isFalse);
    });

    test('tolerates an unpopulated lead / stylist id and missing fields', () {
      final c = Consultation.fromJson({
        '_id': 'c2',
        'leadId': 'l9',
        'stylistId': 's9',
        'scheduledAt': '2026-11-02T04:30:00.000Z',
      });
      expect(c.lead.id, 'l9');
      expect(c.lead.name, '');
      expect(c.stylistId, 's9');
      expect(c.status, 'Scheduled');
      expect(c.endsAt.difference(c.scheduledAt).inMinutes, 45);
    });
  });

  group('LeadConsultations.fromJson', () {
    test('parses derived status and list', () {
      final r = LeadConsultations.fromJson({
        'lead': {'_id': 'l1', 'name': 'Anjali'},
        'derivedStatus': 'Consultation Scheduled',
        'consultations': [_json(withNotes: false)],
      });
      expect(r.derivedStatus, 'Consultation Scheduled');
      expect(r.consultations.single.id, 'c1');
    });
  });

  group('ConsultationSummary.fromJson', () {
    test('parses counts, report rows, lists and follow-ups', () {
      final s = ConsultationSummary.fromJson({
        'range': {'from': '2026-11-01', 'to': '2026-11-30'},
        'scope': 'all',
        'statusCounts': {'total': 5, 'Scheduled': 2, 'Completed': 2, 'Cancelled': 0, 'No-show': 1},
        'perStylist': [
          {
            'stylistId': 's1',
            'name': 'Asha',
            'total': 4,
            'scheduled': 1,
            'completed': 2,
            'cancelled': 0,
            'noShow': 1,
            'attendedRate': 0.6666667,
          },
          {'stylistId': 's2', 'name': 'Bina', 'total': 1, 'scheduled': 1, 'attendedRate': null},
        ],
        'enquiryStatus': {'New': 3, 'Contacted': 1, 'Consultation Scheduled': 2},
        'today': [_json(withNotes: false)],
        'upcoming': [],
        'needsOutcome': [_json(withNotes: false)],
        'followUps': {
          'count': 7,
          'items': [
            {
              'leadId': 'l1',
              'name': 'Anjali',
              'phone': '9876543210',
              'followUpDate': '2026-11-01T04:30:00.000Z',
              'overdue': true,
            },
          ],
        },
      });
      expect(s.isTeam, isTrue);
      expect(s.total, 5);
      expect(s.count('Completed'), 2);
      expect(s.count('Nonexistent'), 0);
      expect(s.perStylist.first.attendedRate, closeTo(0.667, 0.001));
      expect(s.perStylist.last.attendedRate, isNull);
      // Report order is kept (Dart maps preserve insertion order).
      expect(s.enquiryStatus.keys.toList(), ['New', 'Contacted', 'Consultation Scheduled']);
      expect(s.today.single.lead.name, 'Anjali Menon');
      expect(s.needsOutcome, hasLength(1));
      expect(s.followUpCount, 7);
      expect(s.followUps.single.overdue, isTrue);
      expect(s.followUps.single.followUpDate, isNotNull);
    });

    test('an empty / minimal response does not throw', () {
      final s = ConsultationSummary.fromJson({});
      expect(s.isTeam, isFalse);
      expect(s.total, 0);
      expect(s.perStylist, isEmpty);
      expect(s.followUps, isEmpty);
    });
  });

  group('WhatsApp invite', () {
    test('whatsAppNumber adds the India code to a 10-digit mobile', () {
      expect(whatsAppNumber('98765 43210'), '919876543210');
      expect(whatsAppNumber('09876543210'), '919876543210');
      expect(whatsAppNumber('+91 98765-43210'), '919876543210');
      expect(whatsAppNumber(''), '');
    });

    test('buildInviteMessage includes the time, stylist and link', () {
      final msg = buildInviteMessage(Consultation.fromJson(_json()));
      expect(msg, contains('Hello Anjali'));
      expect(msg, contains('45 minutes'));
      expect(msg, contains('with Riya'));
      expect(msg, contains('https://meet.google.com/abc-defg-hij'));
    });

    test('in-person invite shows the location instead of a link', () {
      final json = _json()
        ..['mode'] = 'In-person'
        ..['meetingLink'] = ''
        ..['location'] = 'Team N Studio, Kochi';
      final msg = buildInviteMessage(Consultation.fromJson(json));
      expect(msg, contains('Location: Team N Studio, Kochi'));
      expect(msg, isNot(contains('video call')));
    });
  });

  group('Service helpers', () {
    test('day() formats a zero-padded date', () {
      expect(ConsultationService.day(DateTime(2026, 3, 5)), '2026-03-05');
    });

    test('statuses map to distinct colours', () {
      final colours = kConsultationStatuses.map(consultationStatusColor).toSet();
      expect(colours.length, kConsultationStatuses.length);
    });

    test('sameDay compares calendar days only', () {
      expect(sameDay(DateTime(2026, 11, 2, 1), DateTime(2026, 11, 2, 23)), isTrue);
      expect(sameDay(DateTime(2026, 11, 2), DateTime(2026, 11, 3)), isFalse);
    });
  });

  group('after-call details', () {
    test('new fields and reference images are parsed', () {
      final c = Consultation.fromJson({
        ..._json(),
        'conveyed': 'Suggested soft glam',
        'lookOutfit': 'Red Kanjivaram',
        'referenceImages': [
          {
            '_id': 'i1',
            'url': 'https://res.cloudinary.com/demo/image/upload/v1/team_n_crm/consultations/a.jpg',
            'caption': 'Saree',
            'uploadedByName': 'Asha',
            'uploadedAt': '2026-11-05T05:30:00.000Z',
          },
        ],
      });
      expect(c.conveyed, 'Suggested soft glam');
      expect(c.afterCallText['lookOutfit'], 'Red Kanjivaram');
      expect(c.referenceImages.single.caption, 'Saree');
      expect(c.referenceImages.single.uploadedAt, isNotNull);
      expect(c.hasAfterCallDetails, isTrue);
      expect(c.referenceImages.single.thumbUrl,
          contains('/image/upload/c_fill,w_400,h_400,q_auto/v1/'));
    });

    test('a call with nothing recorded has no after-call details', () {
      final c = Consultation.fromJson(_json(withNotes: false));
      expect(c.hasAfterCallDetails, isFalse);
      expect(c.referenceImages, isEmpty);
    });

    test('every form section has a readable label for the history', () {
      expect(afterCallFieldLabel('lookHair'), 'Hairstyle');
      expect(afterCallFieldLabel('referenceImages'), 'Reference images');
      expect(afterCallFieldLabel('meetingLink'), 'meetingLink');
      expect(kAfterCallFields.map((f) => f.key).toSet().length, kAfterCallFields.length);
    });

    test('only JPEG, PNG and WebP files are accepted for upload', () {
      Uint8List bytes(List<int> head) => Uint8List.fromList([...head, ...List.filled(16, 0)]);
      expect(PickedImage.sniffMime(bytes([0xFF, 0xD8, 0xFF, 0xE0])), 'image/jpeg');
      expect(PickedImage.sniffMime(bytes([0x89, 0x50, 0x4E, 0x47])), 'image/png');
      expect(
        PickedImage.sniffMime(bytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits])),
        'image/webp',
      );
      expect(PickedImage.sniffMime(bytes('%PDF'.codeUnits)), isNull);
      expect(PickedImage.sniffMime(Uint8List(4)), isNull);
    });
  });
}
