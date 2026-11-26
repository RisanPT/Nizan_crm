import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/marketing/data/asset_search.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';

/// Keywords as chips. Type one and press Enter (or a comma); paste a whole list ("bridal, reel; #kerala #bride" → four); pick from the
/// library's own keywords while typing, each with how many assets already carry it — the way to keep "bridal" from turning into
/// "bride", "brides" and "bridal look". Each is kept one way (lower case, no #, single spaces), the same as the server keeps it. A
/// duplicate, one too long or one too many is said under the field and not added.
///
/// [controller] holds what is typed but not yet added: the form adds it on Save (nothing typed is lost), and with [commitOnBlur] it is
/// added when the field is left.
class KeywordInput extends ConsumerStatefulWidget {
  const KeywordInput({
    super.key,
    required this.keywords,
    required this.onChanged,
    required this.controller,
    this.label = 'Keywords',
    this.hint = 'Type a keyword, press Enter — or paste a list',
    this.note,
    this.max = kMaxKeywords,
    this.fieldKey = const Key('asset_tags'),
    this.commitOnBlur = true,
    this.suggest = true,
  });
  final List<String> keywords;
  final ValueChanged<List<String>> onChanged;
  final TextEditingController controller;
  final String label, hint;
  final String? note;
  final int max;
  final Key fieldKey;
  final bool commitOnBlur, suggest;

  @override
  ConsumerState<KeywordInput> createState() => _KeywordInputState();
}

class _KeywordInputState extends ConsumerState<KeywordInput> {
  late final _focus = FocusNode(onKeyEvent: _onKey);
  Timer? _debounce;
  String _typed = '';
  String? _notice;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus
      ..removeListener(_focusChanged)
      ..dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (!_focus.hasFocus && widget.commitOnBlur && widget.controller.text.trim().isNotEmpty) _submit(keepFocus: false);
    if (mounted) setState(() {});
  }

  // Backspace in an empty field takes the last keyword off (a keyboard; on a phone each chip has its ×)
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.backspace && widget.controller.text.isEmpty && widget.keywords.isNotEmpty) {
      _remove(widget.keywords.last);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _commit(Iterable<String> pieces) {
    final r = addKeywords(widget.keywords, pieces, max: widget.max);
    setState(() => _notice = r.notice);
    if (r.keywords.length != widget.keywords.length) widget.onChanged(r.keywords);
  }

  void _remove(String k) {
    setState(() => _notice = null);
    widget.onChanged([...widget.keywords]..remove(k));
  }

  void _onText(String v) {
    final pieces = splitKeywords(v);
    var rest = v;
    if (pieces.length > 1) {
      // everything before the last separator is a keyword; what follows it is still being typed
      _commit(pieces.sublist(0, pieces.length - 1));
      rest = pieces.last.trimLeft();
      widget.controller.value = TextEditingValue(text: rest, selection: TextSelection.collapsed(offset: rest.length));
    } else if (_notice != null) {
      setState(() => _notice = null);
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _typed = normalizeKeyword(rest));
    });
  }

  void _submit({bool keepFocus = true}) {
    _commit(splitKeywords(widget.controller.text));
    widget.controller.clear();
    _debounce?.cancel();
    setState(() => _typed = '');
    if (keepFocus) _focus.requestFocus();
  }

  void _pick(String k) {
    widget.controller.clear();
    _commit([k]);
    setState(() => _typed = '');
  }

  Widget _suggestions() {
    if (!widget.suggest || (!_focus.hasFocus && _typed.isEmpty)) return const SizedBox.shrink();
    final async = ref.watch(keywordSuggestProvider(_typed));
    final list = async.value?.items.where((k) => !widget.keywords.contains(k.keyword)).take(8).toList() ?? const <KeywordCount>[];
    final exact = list.any((k) => k.keyword == _typed);
    if (list.isEmpty && _typed.isEmpty) return const SizedBox.shrink();
    // a tap here is not a tap "outside" the field: it does not close the suggestions before it lands
    return TextFieldTapRegion(
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(_typed.isEmpty ? 'Often used:' : 'In the library:', style: mktText(11, color: Mkt.inkSoft, weight: FontWeight.w600)),
          for (final k in list)
            ActionChip(
              key: Key('kw_suggest_${k.keyword}'),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: Mkt.primarySoft,
              side: const BorderSide(color: Mkt.border),
              label: Text('${k.keyword}  ${k.count}', style: mktText(11.5, weight: FontWeight.w600)),
              onPressed: () => _pick(k.keyword),
            ),
          if (_typed.isNotEmpty && !exact && !widget.keywords.contains(_typed) && async.hasValue)
            Text(list.isEmpty ? 'A new keyword — press Enter to add "$_typed".' : 'Or press Enter to add "$_typed" as a new one.', key: const Key('kw_new_hint'), style: mktText(11, color: Mkt.inkSoft)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.keywords.length >= widget.max;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      TextField(
        key: widget.fieldKey,
        controller: widget.controller,
        focusNode: _focus,
        enabled: !full || widget.controller.text.isNotEmpty,
        onChanged: _onText,
        onSubmitted: (_) => _submit(),
        // Enter adds the keyword and keeps the cursor here for the next one
        onEditingComplete: () {},
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: full ? 'The most keywords an asset carries' : widget.hint,
          isDense: true,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.sell_outlined, size: 18),
          suffixText: '${widget.keywords.length} / ${widget.max}',
          suffixIcon: widget.controller.text.trim().isEmpty ? null : IconButton(key: const Key('kw_add'), tooltip: 'Add', icon: const Icon(Icons.add_rounded), onPressed: _submit),
        ),
      ),
      if (widget.keywords.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in widget.keywords)
              InputChip(
                key: Key('kw_chip_$k'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                label: Text(k, style: mktText(12, weight: FontWeight.w600)),
                deleteIcon: const Icon(Icons.close_rounded, size: 15),
                deleteButtonTooltipMessage: 'Remove $k',
                onDeleted: () => _remove(k),
              ),
          ]),
        ),
      if (_notice != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_notice!, key: const Key('kw_notice'), style: mktText(11.5, weight: FontWeight.w600, color: Mkt.warn))),
      _suggestions(),
      if (widget.note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(widget.note!, style: mktText(11, color: Mkt.inkSoft))),
    ]);
  }
}
