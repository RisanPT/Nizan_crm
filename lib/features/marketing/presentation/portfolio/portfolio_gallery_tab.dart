import 'package:flutter/material.dart';

import 'package:nizan_crm/features/marketing/presentation/portfolio/asset_library_view.dart';

export 'package:nizan_crm/features/marketing/presentation/portfolio/asset_library_view.dart' show AssetLibraryView, kGallerySearchHelp;

/// Creative Portfolio → Gallery: the asset library with its six figures on top ([AssetLibraryView]).
class PortfolioGalleryTab extends StatelessWidget {
  const PortfolioGalleryTab({super.key});

  @override
  Widget build(BuildContext context) => const AssetLibraryView();
}
