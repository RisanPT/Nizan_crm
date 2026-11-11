import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/domain/markdown_edit.dart';

// The formatting buttons above a task's description.

TextEditingValue _v(String text, int start, [int? end]) =>
    TextEditingValue(text: text, selection: TextSelection(baseOffset: start, extentOffset: end ?? start));

String _sel(TextEditingValue v) => v.selection.textInside(v.text);

void main() {
  group('bold / italic', () {
    test('wraps the selected words and keeps them selected', () {
      final r = wrapSelection(_v('plan the launch', 5, 8), '**', '**');
      expect(r.text, 'plan **the** launch');
      expect(_sel(r), 'the');
    });

    test('nothing selected: a placeholder is put between the markers, selected to type over', () {
      final r = wrapSelection(_v('plan ', 5), '**', '**', placeholder: 'bold text');
      expect(r.text, 'plan **bold text**');
      expect(_sel(r), 'bold text');
    });

    test('pressing it again takes the markers off (selection inside them)', () {
      final r = wrapSelection(_v('plan **the** launch', 7, 10), '**', '**');
      expect(r.text, 'plan the launch');
      expect(_sel(r), 'the');
    });

    test('…or with the markers inside the selection', () {
      final r = wrapSelection(_v('plan **the** launch', 5, 12), '**', '**'); // exactly "**the**"
      expect(r.text, 'plan the launch');
      expect(_sel(r), 'the');
    });

    test('italic does not strip one star off a bold word', () {
      final r = wrapSelection(_v('plan **the** launch', 7, 10), '*', '*');
      expect(r.text, 'plan ***the*** launch');
    });

    test('italic on a bold selection that includes the stars wraps rather than unwraps', () {
      final r = wrapSelection(_v('**the**', 0, 7), '*', '*');
      expect(r.text, '***the***');
    });

    test('works at the very start and end of the text, and with no selection info at all', () {
      expect(wrapSelection(_v('abc', 0, 3), '*', '*').text, '*abc*');
      expect(wrapSelection(const TextEditingValue(text: 'abc'), '*', '*', placeholder: 'x').text, 'abc*x*');
    });
  });

  group('lists', () {
    test('one line becomes a bullet, caret stays at the end of the line', () {
      final r = toggleList(_v('Define scope', 3), ordered: false);
      expect(r.text, '- Define scope');
      expect(r.selection.isCollapsed, isTrue);
      expect(r.selection.baseOffset, r.text.length);
    });

    test('every line the selection touches, and only those', () {
      const text = 'intro\nalpha\nbeta\ngamma\noutro';
      final r = toggleList(_v(text, 8, 13), ordered: false); // inside alpha … inside beta
      expect(r.text, 'intro\n- alpha\n- beta\ngamma\noutro');
    });

    test('numbers count from 1 and skip blank lines', () {
      final r = toggleList(_v('one\n\ntwo\nthree', 0, 14), ordered: true);
      expect(r.text, '1. one\n\n2. two\n3. three');
    });

    test('pressing it again takes the markers off', () {
      final r = toggleList(_v('- one\n- two', 0, 11), ordered: false);
      expect(r.text, 'one\ntwo');
      final n = toggleList(_v('1. one\n2. two', 0, 13), ordered: true);
      expect(n.text, 'one\ntwo');
    });

    test('bullets to numbers swaps the markers; a half-done list is completed, not cleared', () {
      expect(toggleList(_v('- one\n- two', 0, 11), ordered: true).text, '1. one\n2. two');
      expect(toggleList(_v('- one\ntwo', 0, 9), ordered: false).text, '- one\n- two');
    });

    test('an empty document starts a list; the first line is reachable at offset 0', () {
      expect(toggleList(_v('', 0), ordered: false).text, '- ');
      expect(toggleList(_v('first\nsecond', 0), ordered: true).text, '1. first\nsecond');
    });
  });

  group('link', () {
    test('the selected words become the link text; the address is selected to type over', () {
      final r = insertLink(_v('see the spec', 4, 12));
      expect(r.text, 'see [the spec](https://)');
      expect(_sel(r), 'https://');
    });

    test('nothing selected: a placeholder text', () {
      final r = insertLink(_v('', 0));
      expect(r.text, '[link text](https://)');
      expect(_sel(r), 'https://');
    });
  });
}
