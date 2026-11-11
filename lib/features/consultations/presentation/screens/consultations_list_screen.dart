import 'package:flutter/material.dart';

import 'consultations_calendar_screen.dart';

/// `/consultations/list`: the Calendar page opened on its List view (calls
/// grouped by day, with search and a status filter). Kept as its own screen
/// so the old address and links keep working.
class ConsultationsListScreen extends StatelessWidget {
  const ConsultationsListScreen({super.key});

  @override
  Widget build(BuildContext context) => const ConsultationsCalendarScreen(initialView: 'list');
}
