import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/features/marketing/data/work_review.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';

// A gallery photo / video's WORK (the booking it came from: client, day, services, place, every artist on it) and the client's review
// of it — the one the CRM sends the morning after, matched by the booking. Small on the cards ([WorkCardLines]), in full in the viewer
// ([WorkDetailsPanel]) and in Artist Quality.

/// The review in one chip: "★ 4.5" in its colour; "Review waiting" (sent, not answered); "No review yet".
class ReviewBadge extends StatelessWidget {
  const ReviewBadge({super.key, required this.work});
  final AssetWork work;

  @override
  Widget build(BuildContext context) {
    final r = work.review;
    if (r == null) return const MktChip('No review yet', color: Mkt.grey);
    if (r.waiting) return const MktChip('Review waiting', color: Mkt.blue, icon: Icons.schedule_rounded);
    if (!r.answered) return const MktChip('Review expired', color: Mkt.grey);
    if (r.score <= 0) return const MktChip('Reviewed', color: Mkt.good);
    return MktChip('★ ${ratingText(r.score)}', color: ratingColor(r.score), solid: true);
  }
}

/// The work under a card's title: day · booking · client, the artists, and the client's rating (a complaint in red).
class WorkCardLines extends StatelessWidget {
  const WorkCardLines({super.key, required this.work, this.compact = false});
  final AssetWork work;

  /// One line for the list view: the same facts side by side.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final w = work;
    final r = w.review;
    final when = [if (w.day.isNotEmpty) workDayText(w.day, pattern: 'd MMM yyyy'), w.title].where((x) => x.isNotEmpty).join(' · ');
    Widget line(IconData icon, String text, {Key? key, Color color = Mkt.ink, FontWeight weight = FontWeight.w600}) => Row(key: key, children: [
          Icon(icon, size: 13, color: Mkt.inkSoft),
          const SizedBox(width: 4),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, weight: weight, color: color))),
        ]);
    final flags = Wrap(spacing: 4, runSpacing: 4, children: [
      ReviewBadge(key: Key('work_badge_${w.bookingId}'), work: w),
      if (r != null && r.complaint) const MktChip('Complaint', color: Mkt.bad, icon: Icons.report_gmailerrorred_rounded),
      if (r != null && r.testimonial.isNotEmpty && r.marketingConsent) const MktChip('Testimonial', color: Mkt.good, icon: Icons.format_quote_rounded),
    ]);
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Wrap(spacing: 8, runSpacing: 3, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text([when, if (w.artistNames.isNotEmpty) w.artistNames].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, weight: FontWeight.w600)),
          flags,
        ]),
      );
    }
    // the client on a line of her own (a narrow card would cut her name off), then the day and booking, then the artists
    final dayBooking = [if (w.day.isNotEmpty) workDayText(w.day, pattern: 'd MMM yyyy'), if (w.bookingNumber.isNotEmpty) '#${w.bookingNumber}'].join(' · ');
    return Column(key: Key('work_lines_${w.bookingId}'), crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 4),
      if (w.client.isNotEmpty) line(Icons.person_outline_rounded, w.client, weight: FontWeight.w800),
      if (dayBooking.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: line(Icons.event_outlined, dayBooking, weight: FontWeight.w500)),
      if (w.artistNames.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: line(Icons.brush_outlined, w.artistNames, weight: FontWeight.w500)),
      const SizedBox(height: 4),
      flags,
    ]);
  }
}

/// Stars out of five for [value] (halves shown).
class Stars extends StatelessWidget {
  const Stars({super.key, required this.value, this.size = 14});
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(value >= i ? Icons.star_rounded : (value >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded), size: size, color: value >= i - 0.5 ? const Color(0xFFF5A524) : Mkt.border),
      ]);
}

/// Everything about the work in the viewer: the booking, client, day, services and place; every artist on it (each gets this rating);
/// and the client's review in full — ratings by area, her answers and her own words, the complaint, the testimonial.
class WorkDetailsPanel extends StatelessWidget {
  const WorkDetailsPanel({super.key, required this.work, this.onArtist});
  final AssetWork work;

  /// Tapping an artist (Artist Quality opens on them); null = the names are not tappable.
  final ValueChanged<WorkArtist>? onArtist;

  @override
  Widget build(BuildContext context) {
    final w = work;
    final r = w.review;
    Widget fact(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 15, color: Mkt.inkSoft),
            const SizedBox(width: 6),
            SizedBox(width: 74, child: Text(label, style: mktText(11.5, color: Mkt.inkSoft))),
            Expanded(child: Text(value, style: mktText(12, weight: FontWeight.w600))),
          ]),
        );
    return Container(
      key: const Key('work_panel'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Mkt.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Mkt.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.work_outline_rounded, size: 16, color: Mkt.primary),
          const SizedBox(width: 6),
          Expanded(child: Text('The work', style: mktText(13, weight: FontWeight.w800, color: Mkt.primary))),
          ReviewBadge(work: w),
        ]),
        const SizedBox(height: 8),
        if (w.bookingNumber.isNotEmpty) fact(Icons.confirmation_number_outlined, 'Booking', '#${w.bookingNumber}'),
        if (w.client.isNotEmpty) fact(Icons.person_outline_rounded, 'Client', w.client),
        if (w.eventDay.isNotEmpty) fact(Icons.event_outlined, 'Event day', workDayText(w.eventDay)),
        if (w.workDay.isNotEmpty && w.workDay != w.eventDay) fact(Icons.today_outlined, 'Filmed on', workDayText(w.workDay)),
        if (w.services.isNotEmpty) fact(Icons.spa_outlined, 'Service', w.services.join(', ')),
        if (w.place.isNotEmpty) fact(Icons.place_outlined, 'Place', w.place),
        const SizedBox(height: 4),
        Text(w.artists.length > 1 ? 'Artists on this work — each gets its rating' : 'Artist on this work', style: mktText(11.5, color: Mkt.inkSoft)),
        const SizedBox(height: 4),
        if (w.artists.isEmpty) Text('No artist was assigned on the booking.', style: mktText(12, color: Mkt.inkSoft)),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final a in w.artists)
            if (onArtist == null)
              // not tappable here (already the artist's own page): a plain label, not a greyed-out button
              Chip(
                key: Key('work_artist_${a.key}'),
                avatar: MktAvatar(a.name, size: 20),
                label: Text('${a.name}${a.role.isEmpty ? '' : ' · ${a.role}'}', style: mktText(11.5, weight: FontWeight.w600)),
                visualDensity: VisualDensity.compact,
                side: const BorderSide(color: Mkt.border),
                backgroundColor: Colors.white,
              )
            else
              ActionChip(
                key: Key('work_artist_${a.key}'),
                tooltip: "Open ${a.name}'s quality",
                avatar: MktAvatar(a.name, size: 20),
                label: Text('${a.name}${a.role.isEmpty ? '' : ' · ${a.role}'}', style: mktText(11.5, weight: FontWeight.w600)),
                visualDensity: VisualDensity.compact,
                side: const BorderSide(color: Mkt.border),
                backgroundColor: Colors.white,
                onPressed: () => onArtist!(a),
              ),
        ]),
        const Divider(height: 22),
        _ReviewBody(review: r),
      ]),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.review});
  final WorkReview? review;

  @override
  Widget build(BuildContext context) {
    final r = review;
    final when = DateFormat('d MMM, h:mm a');
    if (r == null) {
      return Text('No review yet. The client gets the review form the morning after the work is marked completed.', key: const Key('work_review_none'), style: mktText(12, color: Mkt.inkSoft));
    }
    if (!r.answered) {
      return Text(
        r.waiting ? 'The review form was sent${r.sentAt == null ? '' : ' on ${when.format(r.sentAt!)}'} — waiting for the client.' : 'The review form expired without an answer.',
        key: const Key('work_review_waiting'),
        style: mktText(12, color: Mkt.inkSoft),
      );
    }
    Widget quote(String label, String text, {Color color = Mkt.ink, Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.only(top: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: mktText(11, color: Mkt.inkSoft, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('“$text”', style: mktText(12.5, color: color, weight: FontWeight.w500).copyWith(fontStyle: FontStyle.italic)),
          ]),
        );
    return Column(key: const Key('work_review'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text("Client's review", style: mktText(12.5, weight: FontWeight.w800)),
        const Spacer(),
        if (r.submittedAt != null) Text(when.format(r.submittedAt!), style: mktText(10.5, color: Mkt.inkSoft)),
      ]),
      if (r.complaint || r.followUpRequired)
        Container(
          key: const Key('work_review_complaint'),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: Mkt.bad.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: Mkt.bad.withValues(alpha: 0.3))),
          child: Row(children: [
            const Icon(Icons.report_gmailerrorred_rounded, size: 16, color: Mkt.bad),
            const SizedBox(width: 6),
            Expanded(child: Text(r.complaint ? 'Marked as a complaint${r.followUpRequired ? ' — follow-up needed' : ''}' : 'Follow-up needed', style: mktText(12, weight: FontWeight.w700, color: Mkt.bad))),
          ]),
        ),
      const SizedBox(height: 8),
      Wrap(spacing: 16, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (r.score > 0)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Stars(value: r.score, size: 17),
            const SizedBox(width: 6),
            Text('${ratingText(r.score)} / 5', key: const Key('work_review_score'), style: mktText(13, weight: FontWeight.w800, color: ratingColor(r.score))),
          ]),
        if (r.nps != null) Text('Would recommend: ${r.nps}/10', style: mktText(12, weight: FontWeight.w600)),
      ]),
      if (r.areas.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final a in r.areas)
            Container(
              key: Key('work_area_${a.key}'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: a.value < 4 ? ratingColor(a.value).withValues(alpha: 0.5) : Mkt.border)),
              child: Text('${a.label} ${ratingText(a.value)}★', style: mktText(11, weight: FontWeight.w700, color: a.value < 4 ? ratingColor(a.value) : Mkt.ink)),
            ),
        ]),
      ],
      for (final (q, a) in r.answers) Padding(padding: const EdgeInsets.only(top: 6), child: Text('$q: $a', style: mktText(11.5))),
      if (r.couldBeBetter.isNotEmpty) quote('What could have been better', r.couldBeBetter, color: r.needsAttention ? Mkt.bad : Mkt.ink, key: const Key('work_review_better')),
      if (r.artistImprove.isNotEmpty) quote('What the artist could improve', r.artistImprove, color: r.needsAttention ? Mkt.bad : Mkt.ink),
      if (r.likedMost.isNotEmpty) quote('What she liked most', r.likedMost),
      if (r.artistDidWell.isNotEmpty) quote('What the artist did well', r.artistDidWell),
      if (r.testimonial.isNotEmpty) quote(r.marketingConsent ? 'Testimonial — she agreed we can use it' : 'Testimonial — not for marketing (no consent)', r.testimonial),
    ]);
  }
}
