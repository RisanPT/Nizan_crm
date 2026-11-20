// IMPORTING TASKS INTO THE PLAN WIZARD — a list of tasks pasted as text becomes task drafts.
//
// One task per line. A leading bullet or number ("- ", "• ", "3. ", "2) ") is dropped. A line may end with the number of days the
// task takes, after a comma, a semicolon or a tab (a column copied from a spreadsheet arrives tab-separated): "Wireframes, 3",
// "Wireframes\t3", "Wireframes; 3 days", "Wireframes 3d". Anything else is the title, kept whole.

/// A task read from a pasted line.
typedef ImportedTask = ({String title, int days});

/// How many tasks one paste may add (a slip of the finger should not bury the plan).
const int maxImportedTasks = 200;
const int maxImportedDays = 365;
const int maxTitleLength = 120;

final _bullet = RegExp(r'^\s*(?:[-*•·–—]+|\(?\d{1,3}[.)])\s+');
// "…, 3" / "…; 3 days" / "…<tab>3" — the number is the last field
final _daysField = RegExp(
  r'^(.*?)\s*[,;\t]\s*(\d{1,4})\s*(?:d|day|days)?\s*$',
  caseSensitive: false,
);
// "… 3d" / "… 3 days" — a number with a unit, ending the line
final _daysSuffix = RegExp(
  r'^(.*\S)\s+(\d{1,4})\s*(?:d|day|days)\s*$',
  caseSensitive: false,
);

final _hasLetter = RegExp(r'\p{L}', unicode: true);
final _onlyLength = RegExp(r'^\d{1,4}\s*(?:d|day|days)$', caseSensitive: false);

/// The tasks in [text], in order, at most [maxImportedTasks]. Blank lines and lines with no title are skipped; [defaultDays] is used
/// when a line gives no days (or gives 0, or more than a year).
List<ImportedTask> parseTaskLines(String text, {int defaultDays = 3}) {
  final out = <ImportedTask>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    var line = raw.replaceFirst(_bullet, '').trim();
    if (line.isEmpty) continue;
    var days = defaultDays;
    final m = _daysField.firstMatch(line) ?? _daysSuffix.firstMatch(line);
    if (m != null) {
      final n = int.tryParse(m.group(2)!) ?? 0;
      final title = m.group(1)!.trim();
      // a number after the title is only "days" when something is left to be the title
      if (title.isNotEmpty) {
        line = title;
        if (n >= 1 && n <= maxImportedDays) days = n;
      }
    }
    line = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    // a line with no letters in it ("3", ", 4") or that is only a length ("5 days") has no title: it is not a task
    if (line.isEmpty ||
        !_hasLetter.hasMatch(line) ||
        _onlyLength.hasMatch(line)) {
      continue;
    }
    if (line.length > maxTitleLength) {
      line = line.substring(0, maxTitleLength).trimRight();
    }
    out.add((title: line, days: days));
    if (out.length >= maxImportedTasks) break;
  }
  return out;
}
