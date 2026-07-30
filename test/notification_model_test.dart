import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/notifications/data/app_notification.dart';

void main() {
  group('AppNotification.fromJson', () {
    test('parses a populated leadId into id + name', () {
      final n = AppNotification.fromJson({
        '_id': 'n1',
        'type': 'followup_missed',
        'title': 'Missed follow-up',
        'body': 'Follow-up for Asha was missed.',
        'leadId': {'_id': 'lead123', 'name': 'Asha'},
        'read': false,
        'createdAt': '2026-07-30T10:00:00.000Z',
      });
      expect(n.id, 'n1');
      expect(n.type, 'followup_missed');
      expect(n.leadId, 'lead123');
      expect(n.leadName, 'Asha');
      expect(n.read, isFalse);
    });

    test('parses a plain-string leadId', () {
      final n = AppNotification.fromJson({
        '_id': 'n2',
        'type': 'new_lead',
        'leadId': 'lead999',
        'read': true,
        'createdAt': '2026-07-30T10:00:00.000Z',
      });
      expect(n.leadId, 'lead999');
      expect(n.leadName, isNull);
      expect(n.read, isTrue);
    });

    test('tolerates missing optional fields', () {
      final n = AppNotification.fromJson({'_id': 'n3', 'type': 'booking_created'});
      expect(n.leadId, isNull);
      expect(n.bookingId, isNull);
      expect(n.title, '');
      expect(n.body, '');
      expect(n.read, isFalse);
    });

    test('copyWith flips read state only', () {
      final n = AppNotification.fromJson({'_id': 'n4', 'type': 'lost_result'});
      final read = n.copyWith(read: true);
      expect(read.read, isTrue);
      expect(read.id, n.id);
      expect(read.type, n.type);
    });
  });

  group('NotificationPage.fromJson', () {
    test('parses items + unread count', () {
      final page = NotificationPage.fromJson({
        'items': [
          {'_id': 'a', 'type': 'new_lead', 'createdAt': '2026-07-30T10:00:00.000Z'},
          {'_id': 'b', 'type': 'followup_due', 'createdAt': '2026-07-30T10:00:00.000Z'},
        ],
        'unreadCount': 5,
        'totalPages': 2,
        'page': 1,
      });
      expect(page.items.length, 2);
      expect(page.unreadCount, 5);
      expect(page.totalPages, 2);
    });

    test('defaults an empty payload safely', () {
      final page = NotificationPage.fromJson({});
      expect(page.items, isEmpty);
      expect(page.unreadCount, 0);
    });
  });
}
