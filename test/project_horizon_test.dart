import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/domain/horizon_for_dates.dart';
import 'package:nizan_crm/features/it/domain/models/strategic_vision_model.dart';

// The strategic wave a project belongs to follows the year it lands (its end date, else its start).
void main() {
  test('the default waves: 2026–28 → 1, 2029–33 → 2, 2034–41 → 3; before the first → 1, after the last → 3', () {
    expect([for (final y in [2026, 2028, 2029, 2033, 2034, 2041]) horizonForYear(y, const [])], [1, 1, 2, 2, 3, 3]);
    expect([horizonForYear(2024, const []), horizonForYear(2050, const [])], [1, 3]);
  });

  test("the strategic vision's own waves win over the defaults", () {
    const waves = [
      StrategicHorizon(horizonNumber: 2, name: 'Scale', startYear: 2028, endYear: 2030),
      StrategicHorizon(horizonNumber: 1, name: 'Found', startYear: 2025, endYear: 2027),
      StrategicHorizon(horizonNumber: 3, name: 'Global', startYear: 2031, endYear: 2035),
    ];
    expect([for (final y in [2025, 2027, 2028, 2030, 2031, 2040, 2020]) horizonForYear(y, waves)], [1, 1, 2, 2, 3, 3, 1]);
  });

  test('by the end date when there is one, else the start date', () {
    expect(horizonForDates(start: DateTime(2026, 11, 23), end: DateTime(2029, 3, 1)), 2);
    expect(horizonForDates(start: DateTime(2034, 1, 1)), 3);
  });
}
