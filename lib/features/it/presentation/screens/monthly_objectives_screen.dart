import 'package:flutter/material.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/monthly_objectives_view.dart';

/// Monthly objectives as a page of its own — open to every signed-in team member, like Help Desk, so a department's people can reach
/// their month without holding the Company Projects permission (that one can be switched off per role). What each person sees is
/// decided by the server: their own department's objectives, what has been given to them, and — for administrators and the CEO — every
/// department's.
class MonthlyObjectivesScreen extends StatelessWidget {
  const MonthlyObjectivesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: context.crmColors.background, body: const MonthlyObjectivesView());
}
