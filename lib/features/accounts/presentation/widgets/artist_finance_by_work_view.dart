import 'package:flutter/material.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_common.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart' show NameOption;
import 'package:nizan_crm/features/accounts/presentation/widgets/work_costs_tab.dart';

/// Desktop "By Work": what each work cost, kind by kind — food, travel, stay, materials, FUEL, other —
/// over the period chosen at the top of the screen, with the spend that is not tied to any work
/// listed beside it. This is the real [WorkCostsTab] (the one phones use), not a mock-up: the same
/// numbers, the same search / artist / status filters, the same export — only the frame is the
/// desktop one (centred, so the cards do not stretch across a wide window).
class ArtistFinanceByWorkView extends StatelessWidget {
  /// The period ('YYYY-MM-DD', inclusive; null = no limit) — owned by the screen's period bar.
  final String? from;
  final String? to;

  /// The artists the list can be narrowed to.
  final List<NameOption> artists;

  const ArtistFinanceByWorkView({
    super.key,
    required this.from,
    required this.to,
    this.artists = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AfTheme.background,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: WorkCostsTab(from: from, to: to, artists: artists),
          ),
        ),
      ),
    );
  }
}
