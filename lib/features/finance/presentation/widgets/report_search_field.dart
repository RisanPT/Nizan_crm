import 'package:flutter/material.dart';

/// A compact search box for filtering a report's rows client-side. Manages its
/// own controller; calls [onChanged] (and shows a clear button) as you type.
class ReportSearchField extends StatefulWidget {
  const ReportSearchField({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<ReportSearchField> createState() => _ReportSearchFieldState();
}

class _ReportSearchFieldState extends State<ReportSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: (v) {
        setState(() {}); // toggle the clear button
        widget.onChanged(v);
      },
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
      ),
    );
  }
}
