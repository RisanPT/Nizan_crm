import 'package:flutter/material.dart';

/// Pages of the public website, in menu order, as used by the backend
/// registry's `page` field (config/websiteSections.js). Sections are grouped
/// under these in Website Studio.
const websitePageNames = <String, String>{
  'home': 'Home page',
  'packages': 'Packages page',
  'portfolio': 'Portfolio page',
  'book': 'Book page',
  'contact': 'Contact page',
  'policies': 'Policies page',
  'global': 'Whole website',
};

const websitePageIcons = <String, IconData>{
  'home': Icons.home_outlined,
  'packages': Icons.sell_outlined,
  'portfolio': Icons.photo_library_outlined,
  'book': Icons.event_available_outlined,
  'contact': Icons.call_outlined,
  'policies': Icons.gavel_outlined,
  'global': Icons.public,
};
