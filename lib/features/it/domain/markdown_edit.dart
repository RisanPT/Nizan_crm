import 'package:flutter/services.dart' show TextEditingValue, TextSelection;

// The formatting buttons above a task's description (Bold, Italic, bullets, numbers, link). The description is
// stored as Markdown (it is shown that way everywhere), so each button just edits the text around the selection.
//
// Pure — test/markdown_edit_test.dart.

TextSelection _selectionOf(TextEditingValue v) =>
    v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);

/// Wraps the selection in [left] / [right] (`**bold**`, `*italic*`); with nothing selected, puts [placeholder]
/// between them, selected, ready to be typed over. Pressing it again on text that is already wrapped takes the
/// markers off.
TextEditingValue wrapSelection(TextEditingValue v, String left, String right, {String placeholder = 'text'}) {
  final text = v.text;
  final sel = _selectionOf(v);
  final s = sel.start;
  final e = sel.end;
  final chosen = text.substring(s, e);

  // already wrapped, with the markers just outside the selection?
  final outside = s >= left.length &&
      e + right.length <= text.length &&
      text.substring(s - left.length, s) == left &&
      text.substring(e, e + right.length) == right;
  // `*` inside `**` is bold, not italic: do not strip one star off a bold word
  final insideBold = left == '*' && s - left.length - 1 >= 0 && text[s - left.length - 1] == '*';
  if (outside && !insideBold) {
    return TextEditingValue(
      text: text.substring(0, s - left.length) + chosen + text.substring(e + right.length),
      selection: TextSelection(baseOffset: s - left.length, extentOffset: e - left.length),
    );
  }

  // already wrapped, with the markers inside the selection?
  if (chosen.length >= left.length + right.length && chosen.startsWith(left) && chosen.endsWith(right) && !(left == '*' && chosen.startsWith('**'))) {
    final inner = chosen.substring(left.length, chosen.length - right.length);
    return TextEditingValue(
      text: text.replaceRange(s, e, inner),
      selection: TextSelection(baseOffset: s, extentOffset: s + inner.length),
    );
  }

  final body = chosen.isEmpty ? placeholder : chosen;
  return TextEditingValue(
    text: text.replaceRange(s, e, '$left$body$right'),
    selection: TextSelection(baseOffset: s + left.length, extentOffset: s + left.length + body.length),
  );
}

final _bullet = RegExp(r'^\s*[-*•]\s+');
final _number = RegExp(r'^\s*\d+[.)]\s+');

/// Turns every line the selection touches into a bullet (`- `) or a numbered item (`1. `, `2. `, …). If they
/// all already are one, it takes the markers off instead. Changing bullets to numbers swaps the markers.
TextEditingValue toggleList(TextEditingValue v, {required bool ordered}) {
  final text = v.text;
  final sel = _selectionOf(v);
  final start = sel.start == 0 ? 0 : text.lastIndexOf('\n', sel.start - 1) + 1;
  var end = text.indexOf('\n', sel.end);
  if (end == -1) end = text.length;

  final lines = text.substring(start, end).split('\n');
  final marker = ordered ? _number : _bullet;
  final filled = lines.where((l) => l.trim().isNotEmpty).toList();
  final remove = filled.isNotEmpty && filled.every(marker.hasMatch);

  var n = 0;
  final out = [
    for (final l in lines)
      if (l.trim().isEmpty && lines.length > 1)
        l
      else if (remove)
        l.replaceFirst(marker, '')
      else
        '${ordered ? '${++n}. ' : '- '}${l.replaceFirst(_bullet, '').replaceFirst(_number, '')}',
  ].join('\n');

  return TextEditingValue(
    text: text.replaceRange(start, end, out),
    selection: sel.isCollapsed
        ? TextSelection.collapsed(offset: start + out.length)
        : TextSelection(baseOffset: start, extentOffset: start + out.length),
  );
}

/// Inserts `[text](https://)` — the selected words become the link text, and the address is left selected to be typed.
TextEditingValue insertLink(TextEditingValue v) {
  final text = v.text;
  final sel = _selectionOf(v);
  final chosen = text.substring(sel.start, sel.end);
  final label = chosen.isEmpty ? 'link text' : chosen;
  const url = 'https://';
  final urlStart = sel.start + 1 + label.length + 2;
  return TextEditingValue(
    text: text.replaceRange(sel.start, sel.end, '[$label]($url)'),
    selection: TextSelection(baseOffset: urlStart, extentOffset: urlStart + url.length),
  );
}
