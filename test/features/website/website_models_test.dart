import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/features/website/data/upload_check.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';

// Team N Website: the schema the backend sends (fixture generated from the
// backend registry, config/websiteSections.js), the CRM-side upload pre-check
// and who can open the menu.

Map<String, dynamic> loadSchemaJson() => (jsonDecode(
        File('test/features/website/fixtures/website_schema.json').readAsStringSync()) as Map)
    .cast<String, dynamic>();

AuthSession session(String role, [List<String> permissions = const []]) => AuthSession(
    token: 't', userId: 'u', name: 'U', email: 'u@x', role: role, permissions: permissions);

void main() {
  group('schema from the backend', () {
    final schema = WebsiteSchema.fromJson(loadSchemaJson());

    test('all 18 sections with pages and fields', () {
      expect(schema.sections.length, 18);
      expect(schema.sections['seoBook']!.page, 'book');
      expect(schema.sections['seoBook']!.fields['description']!.maxLength, 160);
      expect(schema.sections['hero']!.page, 'home');
      expect(schema.sections['contact']!.page, 'global');
      expect(schema.sections['hero']!.fields['title']!.required, isFalse); // empty = keep the website's text
      expect(schema.sections['faq']!.fields['items']!.fields['answer']!.required, isTrue);
      expect(schema.sections['hero']!.fields['title']!.maxLength, 60);
    });

    test('image fields carry their upload rule', () {
      final rule = schema.sections['hero']!.fields['imageDesktop']!.upload!;
      expect(rule.minWidth, 1600);
      expect(rule.minHeight, 900);
      expect(rule.maxBytes, 5 * 1024 * 1024);
      expect(rule.extensions, containsAll(['.jpg', '.jpeg', '.png', '.webp']));
      expect(rule.pickerExtensions, contains('jpg'));
      expect(rule.ratio, [1.6, 1.9]);
      expect(rule.hint, contains('max 5 MB'));
    });

    test('lists keep their sub-fields; packages and gallery are described', () {
      final faq = schema.sections['faq']!.fields['items']!;
      expect(faq.type, 'list');
      expect(faq.maxItems, 20);
      expect(faq.fields.keys, ['question', 'answer']);
      expect(schema.packageFields['features']!.type, 'textList');
      expect(schema.packageFields['coverImage']!.upload!.key, 'packageCover');
      expect(schema.galleryCategories.map((c) => c.key), ['makeup', 'hair', 'styling', 'events']);
      expect(schema.galleryUpload!.extensions, isNot(contains('.png')));
      expect(schema.categoryLabel('hair'), 'Hairstyling');
    });
  });

  test('deepCopyJson gives an independent copy', () {
    final original = <String, dynamic>{
      'items': [
        {'q': 'a'}
      ]
    };
    final copy = deepCopyJson(original) as Map<String, dynamic>;
    ((copy['items'] as List).first as Map)['q'] = 'changed';
    expect(((original['items'] as List).first as Map)['q'], 'a');
    expect((copy['items'] as List).first, isA<Map<String, dynamic>>());
  });

  group('upload pre-check (the server checks again)', () {
    final portrait = WebsiteSchema.fromJson(loadSchemaJson()).sections['about']!.fields['portrait']!.upload!;

    test('good file passes', () {
      expect(checkPickedImage(portrait, filename: 'feeniya.JPG', bytes: 500000, width: 960, height: 1200), isNull);
    });
    test('wrong type, too big, too small, wrong shape', () {
      expect(checkPickedImage(portrait, filename: 'a.png', bytes: 1, width: 960, height: 1200),
          contains('not allowed here'));
      expect(checkPickedImage(portrait, filename: 'a.jpg', bytes: 4 * 1024 * 1024),
          contains('The limit here is 3 MB'));
      expect(checkPickedImage(portrait, filename: 'a.jpg', bytes: 1, width: 800, height: 1000),
          contains('at least 900 × 1125'));
      expect(checkPickedImage(portrait, filename: 'a.jpg', bytes: 1, width: 2000, height: 1200),
          contains('wrong shape'));
    });
    test('size unknown in the browser → left to the server', () {
      expect(checkPickedImage(portrait, filename: 'a.webp', bytes: 1), isNull);
    });
    test('mime from extension', () {
      expect(imageMimeFor('x.JPEG'), 'image/jpeg');
      expect(imageMimeFor('x.webp'), 'image/webp');
      expect(imageMimeFor('x.svg'), '');
    });
  });

  group('who sees Team N Website (same rule as the backend)', () {
    test('admin always; manager not by default', () {
      expect(Access.of(session('admin')).canSeeWebsite, isTrue);
      expect(Access.of(session('manager', ['clients', 'sales'])).canSeeWebsite, isFalse);
    });
    test('website key opens every area; a sub-key only its own', () {
      final mkt = Access.of(session('marketing_admin', ['marketing', 'website']));
      expect(mkt.canSeeWebsite, isTrue);
      expect(mkt.canSeeWebsiteArea('packages'), isTrue);

      final gal = Access.of(session('custom', ['website.gallery']));
      expect(gal.canSeeWebsite, isTrue);
      expect(gal.canSeeWebsiteArea('gallery'), isTrue);
      expect(gal.canSeeWebsiteArea('content'), isFalse);

      expect(Access.of(session('sales', ['sales'])).canSeeWebsite, isFalse);
    });
  });
}
