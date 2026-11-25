import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/website/services/website_service.dart';

/// Opens the public website in a new tab.
Future<void> openWebsite(BuildContext context) async {
  final ok = await launchUrl(
    Uri.parse(websiteBaseUrl),
    webOnlyWindowName: '_blank',
  );
  if (!ok && context.mounted) {
    showErrorSnackBar(context, 'Could not open the website.');
  }
}

/// Opens the website showing every saved draft (link valid for one hour).
Future<void> openDraftPreview(BuildContext context, WidgetRef ref) async {
  try {
    final token = await ref.read(websiteServiceProvider).getPreviewToken();
    final url = Uri.parse(
      websiteBaseUrl,
    ).replace(queryParameters: {'preview': token});
    final ok = await launchUrl(url, webOnlyWindowName: '_blank');
    if (!ok && context.mounted) {
      showErrorSnackBar(context, 'Could not open the website.');
    }
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
}
