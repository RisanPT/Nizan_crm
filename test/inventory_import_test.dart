import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/inventory/utils/inventory_import.dart';

Uint8List _csv(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('parseInventoryImport (CSV)', () {
    test('maps header aliases and parses numbers', () {
      final r = parseInventoryImport(
        _csv('Product,Brand,Qty,Price\n'
            'Matte Foundation,MAC,5,1200\n'
            'Setting Spray,Urban Decay,3,900.5\n'),
        'stock.csv',
      );
      expect(r.items.length, 2);
      expect(r.skipped, 0);
      expect(r.items.first['name'], 'Matte Foundation');
      expect(r.items.first['brand'], 'MAC');
      expect(r.items.first['quantity'], 5);
      expect(r.items.first['price'], 1200);
      expect(r.items[1]['price'], 900.5);
    });

    test('skips rows with no name and reports it', () {
      final r = parseInventoryImport(
        _csv('name,quantity\n'
            'Lipstick,4\n'
            ',7\n'
            'Blush,2\n'),
        'stock.csv',
      );
      expect(r.items.length, 2);
      expect(r.skipped, 1);
      expect(r.totalRows, 3);
      expect(r.warnings.any((w) => w.contains('skipped')), isTrue);
    });

    test('errors clearly when there is no name column', () {
      final r = parseInventoryImport(
        _csv('brand,quantity\nMAC,5\n'),
        'stock.csv',
      );
      expect(r.items, isEmpty);
      expect(r.warnings.any((w) => w.toLowerCase().contains('name')), isTrue);
    });

    test('empty file yields a warning, no items', () {
      final r = parseInventoryImport(_csv('\n\n'), 'stock.csv');
      expect(r.items, isEmpty);
      expect(r.warnings, isNotEmpty);
    });

    test('skips a title row above the real header', () {
      final r = parseInventoryImport(
        _csv('STOCK LIST\n'
            'PRODUCT,BRAND,QUANTITY\n'
            'Powder,RCMA,6\n'),
        'stock.csv',
      );
      expect(r.items.length, 1);
      expect(r.items.first['name'], 'Powder');
      expect(r.items.first['quantity'], 6);
    });

    test('forward-fills the product name onto variant rows', () {
      final r = parseInventoryImport(
        _csv('PRODUCT,BRAND,SHADE,QUANTITY\n'
            'Lens,FreshLook,Grey,7\n'
            ',Bella,Honey,4\n' // variant: blank name, has brand/shade → inherits Lens
            ',,,9\n' // no name, no brand/shade → skipped
            'Lashes,Europaris,LV1,2\n'),
        'stock.csv',
      );
      expect(r.items.length, 3);
      expect(r.items[0]['name'], 'Lens');
      expect(r.items[1]['name'], 'Lens'); // inherited
      expect(r.items[1]['shade'], 'Honey');
      expect(r.items[2]['name'], 'Lashes');
      expect(r.skipped, 1);
    });

    test('extracts a leading number from text quantities', () {
      final r = parseInventoryImport(
        _csv('name,quantity\nTissue,2 BOX\n'),
        'stock.csv',
      );
      expect(r.items.single['quantity'], 2);
    });
  });
}
