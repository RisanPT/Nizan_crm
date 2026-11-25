import 'package:nizan_crm/features/it/domain/models/strategic_vision_model.dart';

/// The strategic waves when the strategic vision has none of its own (the roadmap's defaults): Horizon 1 2026–2028, Horizon 2 2029–2033,
/// Horizon 3 2034–2041.
const List<({int number, int from, int to})> kDefaultHorizonYears = [
  (number: 1, from: 2026, to: 2028),
  (number: 2, from: 2029, to: 2033),
  (number: 3, from: 2034, to: 2041),
];

/// The strategic horizon wave a project belongs to by the year it lands: the wave whose years hold [year]; a year before the first wave
/// → the first, after the last → the last. [horizons] — the strategic vision's waves; empty → [kDefaultHorizonYears].
int horizonForYear(int year, List<StrategicHorizon> horizons) {
  final waves = horizons.isNotEmpty
      ? ([for (final h in horizons) (number: h.horizonNumber, from: h.startYear, to: h.endYear)]..sort((a, b) => a.from.compareTo(b.from)))
      : kDefaultHorizonYears;
  for (final w in waves) {
    if (year >= w.from && year <= w.to) return w.number;
  }
  return year < waves.first.from ? waves.first.number : waves.last.number;
}

/// The wave for a project's dates: by its end date (when it lands), else its start date.
int horizonForDates({required DateTime start, DateTime? end, List<StrategicHorizon> horizons = const []}) => horizonForYear((end ?? start).year, horizons);
