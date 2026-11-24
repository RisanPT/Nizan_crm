import 'package:flutter/material.dart';

import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';

// The small pieces every Socials tab is built from.

/// The pipeline stage a post's status falls in (the same mapping as the server: utils/marketingSocialsStats.js).
String stageKeyOf(String status) => switch (status) {
      'idea' || 'planned' => 'planned',
      'in-progress' => 'producing',
      'in-review' => 'in_review',
      'scheduled' => 'scheduled',
      'published' => 'published',
      _ => 'cancelled',
    };

Color stageColor(String stage) => switch (stage) {
      'published' => Mkt.good,
      'scheduled' => Mkt.violet2,
      'producing' => Mkt.warn,
      'in_review' => Mkt.blue,
      'cancelled' => Mkt.bad,
      _ => Mkt.grey,
    };

const kPostStatuses = [
  ('idea', 'Idea'),
  ('planned', 'Planned'),
  ('in-progress', 'In Production'),
  ('in-review', 'In Review'),
  ('scheduled', 'Scheduled'),
  ('published', 'Published'),
  ('cancelled', 'Cancelled'),
];
String postStatusLabel(String s) => kPostStatuses.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;

const kPostFormats = [
  ('reel', 'Reel'),
  ('trial_reel', 'Trial Reel'),
  ('story', 'Story'),
  ('post', 'Feed Post'),
  ('carousel', 'Carousel'),
  ('collab', 'Collab Post'),
  ('video', 'Video'),
  ('image', 'Image'),
  ('blog', 'Blog'),
  ('other', 'Other'),
];
String postFormatLabel(String t) => kPostFormats.firstWhere((e) => e.$1 == t, orElse: () => (t, t)).$2;

const kPlatforms = [
  ('instagram', 'Instagram'),
  ('youtube', 'YouTube'),
  ('facebook', 'Facebook'),
  ('whatsapp', 'WhatsApp'),
  ('website', 'Website'),
  ('pinterest', 'Pinterest'),
  ('snapchat', 'Snapchat'),
  ('linkedin', 'LinkedIn'),
  ('other', 'Other'),
];
String platformName(String p) => kPlatforms.firstWhere((e) => e.$1 == p, orElse: () => (p, p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')).$2;

Color formatColor(String t) => switch (t) {
      'reel' => Mkt.pink,
      'trial_reel' => Mkt.warn,
      'story' => Mkt.violet2,
      'carousel' || 'post' || 'image' => Mkt.blue,
      'collab' => Mkt.teal,
      'video' => Mkt.bad,
      _ => Mkt.grey,
    };

IconData formatIcon(String t) => switch (t) {
      'reel' || 'trial_reel' || 'video' => Icons.play_circle_outline_rounded,
      'story' => Icons.auto_stories_outlined,
      'carousel' => Icons.view_carousel_outlined,
      'collab' => Icons.people_alt_outlined,
      'blog' => Icons.article_outlined,
      _ => Icons.image_outlined,
    };

IconData platformIcon(String p) => switch (p) {
      'instagram' => Icons.camera_alt_outlined,
      'youtube' => Icons.smart_display_outlined,
      'facebook' => Icons.facebook_outlined,
      'whatsapp' => Icons.chat_outlined,
      'pinterest' => Icons.push_pin_outlined,
      'snapchat' => Icons.photo_camera_front_outlined,
      'linkedin' => Icons.work_outline_rounded,
      'website' => Icons.language_rounded,
      _ => Icons.public_rounded,
    };

/// A post's picture: its thumbnail when it has one (a link), else a tinted tile with its format's icon.
class PostThumb extends StatelessWidget {
  const PostThumb({super.key, required this.url, required this.contentType, this.width = 56, this.height = 56, this.radius = 10});
  final String url;
  final String contentType;
  final double width, height, radius;

  @override
  Widget build(BuildContext context) {
    final c = formatColor(contentType);
    final fallback = Container(width: width, height: height, color: Mkt.tint(c, 0.14), child: Icon(formatIcon(contentType), size: (height * 0.42).clamp(14, 34).toDouble(), color: c));
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty ? fallback : Image.network(url, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback, loadingBuilder: (_, child, p) => p == null ? child : fallback),
    );
  }
}

/// Image of an asset (a thumbnail link) or a tinted tile by kind.
class AssetThumb extends StatelessWidget {
  const AssetThumb({super.key, required this.asset, this.height = 130});
  final Asset asset;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = asset.media == 'video' ? Mkt.pink : (asset.media == 'design' ? Mkt.violet2 : (asset.media == 'document' ? Mkt.grey : Mkt.blue));
    final icon = asset.media == 'video' ? Icons.play_circle_outline_rounded : (asset.media == 'document' ? Icons.description_outlined : (asset.media == 'design' ? Icons.palette_outlined : Icons.image_outlined));
    final fallback = Container(height: height, width: double.infinity, color: Mkt.tint(c, 0.12), child: Icon(icon, size: 36, color: c));
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: asset.thumbUrl.isEmpty ? fallback : Image.network(asset.thumbUrl, height: height, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback, loadingBuilder: (_, child, p) => p == null ? child : fallback),
    );
  }
}

/// "↑ +12% vs last week" (green), "↓ −8% vs last week" (red), "No change" (grey) — null when there is nothing to compare with.
({String text, bool? good})? deltaOf(int? change, {String tail = 'vs last week'}) {
  if (change == null) return null;
  if (change == 0) return (text: 'No change', good: null);
  return (text: '${change > 0 ? '↑ +' : '↓ −'}${change.abs()}% $tail', good: change > 0);
}
