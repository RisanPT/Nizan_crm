import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

enum MilestoneType { birthday, workAnniversary }

class CelebrationMilestone {
  final Employee employee;
  final MilestoneType type;
  final DateTime eventDate;
  final int daysUntil; // 0 = today, 1..7 = upcoming in N days
  final int yearsCompleted; // For anniversaries

  const CelebrationMilestone({
    required this.employee,
    required this.type,
    required this.eventDate,
    required this.daysUntil,
    this.yearsCompleted = 0,
  });

  bool get isToday => daysUntil == 0;

  String get eventTitle {
    if (type == MilestoneType.birthday) {
      return isToday ? "Happy Birthday! 🎂" : "Upcoming Birthday 🎈";
    } else {
      final suffix = _ordinal(yearsCompleted);
      return isToday
          ? "Happy $yearsCompleted$suffix Work Anniversary! 🏆"
          : "$yearsCompleted$suffix Work Anniversary 🎖️";
    }
  }

  String get countdownText {
    if (isToday) return "TODAY! 🎉";
    if (daysUntil == 1) return "Tomorrow (in 1 day)";
    return "In $daysUntil days (${_monthDay(eventDate)})";
  }

  String get celebrationMessage {
    if (type == MilestoneType.birthday) {
      return isToday
          ? "Wishing ${employee.name} a wonderful year ahead filled with happiness and success!"
          : "Get ready to celebrate ${employee.name}'s birthday on ${_monthDay(eventDate)} (in $daysUntil days)!";
    } else {
      return isToday
          ? "Celebrating $yearsCompleted years of dedication and excellence with Team Nizan!"
          : "${employee.name} completes $yearsCompleted years with us on ${_monthDay(eventDate)} (in $daysUntil days). Celebrate their journey!";
    }
  }

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  static String _monthDay(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month]}';
  }
}

/// Helper to scan all active employees and find milestones within the next windowDays (default 30).
List<CelebrationMilestone> findUpcomingMilestones(List<Employee> staff, {int windowDays = 30}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final milestones = <CelebrationMilestone>[];

  for (final emp in staff) {
    if (!emp.isActive) continue;

    // 1. Birthday Check
    if (emp.dateOfBirth != null) {
      final dob = emp.dateOfBirth!.toLocal();
      var thisYearEvent = DateTime(today.year, dob.month, dob.day);
      if (thisYearEvent.isBefore(today)) {
        thisYearEvent = DateTime(today.year + 1, dob.month, dob.day);
      }
      final diff = thisYearEvent.difference(today).inDays;
      if (diff >= 0 && diff <= windowDays) {
        milestones.add(CelebrationMilestone(
          employee: emp,
          type: MilestoneType.birthday,
          eventDate: thisYearEvent,
          daysUntil: diff,
        ));
      }
    }

    // 2. Work Anniversary Check
    if (emp.dateOfJoining != null) {
      final doj = emp.dateOfJoining!.toLocal();
      var thisYearEvent = DateTime(today.year, doj.month, doj.day);
      var annivYear = today.year;
      if (thisYearEvent.isBefore(today)) {
        thisYearEvent = DateTime(today.year + 1, doj.month, doj.day);
        annivYear = today.year + 1;
      }
      final diff = thisYearEvent.difference(today).inDays;
      final years = annivYear - doj.year;
      if (years >= 1 && diff >= 0 && diff <= windowDays) {
        milestones.add(CelebrationMilestone(
          employee: emp,
          type: MilestoneType.workAnniversary,
          eventDate: thisYearEvent,
          daysUntil: diff,
          yearsCompleted: years,
        ));
      }
    }
  }

  // Sort by closest event date first (today first)
  milestones.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
  return milestones;
}

/// Rich celebration popup dialog with confetti physics, particle animation,
/// employee photo and milestone carousel.
class CelebrationPopupDialog extends StatefulWidget {
  final List<CelebrationMilestone> milestones;
  final Function(CelebrationMilestone milestone)? onWish;

  const CelebrationPopupDialog({
    super.key,
    required this.milestones,
    this.onWish,
  });

  static Future<void> show(
    BuildContext context, {
    required List<CelebrationMilestone> milestones,
    Function(CelebrationMilestone milestone)? onWish,
  }) {
    if (milestones.isEmpty) return Future.value();
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => CelebrationPopupDialog(
        milestones: milestones,
        onWish: onWish,
      ),
    );
  }

  @override
  State<CelebrationPopupDialog> createState() => _CelebrationPopupDialogState();
}

class _CelebrationPopupDialogState extends State<CelebrationPopupDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late List<_ConfettiParticle> _particles;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    final rnd = math.Random();
    _particles = List.generate(45, (i) => _ConfettiParticle(rnd));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final current = widget.milestones[_currentIndex];
    final total = widget.milestones.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Confetti particle overlay animation
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _animCtrl,
                    builder: (ctx, child) {
                      return CustomPaint(
                        painter: _ConfettiPainter(_particles, _animCtrl.value),
                      );
                    },
                  ),
                ),
              ),

              // Main Celebration Card Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF601A29).withValues(alpha: 0.35),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFC9A66B),
                    width: 1.8,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Festive Header Banner
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF601A29), Color(0xFF8B263E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC9A66B).withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  current.type == MilestoneType.birthday
                                      ? Icons.cake_rounded
                                      : Icons.military_tech_rounded,
                                  color: const Color(0xFFC9A66B),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Team Celebration Alert',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFF5F3EF),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    // Card Body
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Employee Avatar with Golden Glowing Halo Ring
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulsing Golden Glow
                              AnimatedBuilder(
                                animation: _animCtrl,
                                builder: (ctx, child) {
                                  final pulse = (math.sin(_animCtrl.value * 2 * math.pi) + 1) / 2;
                                  return Container(
                                    width: 122 + (pulse * 8),
                                    height: 122 + (pulse * 8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          const Color(0xFFC9A66B).withValues(alpha: 0.4 + (pulse * 0.2)),
                                          const Color(0xFFC9A66B).withValues(alpha: 0.0),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Golden Rim Ring
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xFFC9A66B), Color(0xFFFDFBF7), Color(0xFFC9A66B)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 48,
                                  backgroundColor: const Color(0xFF601A29).withValues(alpha: 0.12),
                                  backgroundImage: current.employee.profileImage.isNotEmpty
                                      ? NetworkImage(current.employee.profileImage)
                                      : null,
                                  child: current.employee.profileImage.isEmpty
                                      ? Text(
                                          current.employee.name.isNotEmpty
                                              ? current.employee.name.substring(0, 1).toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Color(0xFF601A29),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 36,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              // Floating Celebration Badge icon at bottom right
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF601A29),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    current.type == MilestoneType.birthday
                                        ? Icons.cake_rounded
                                        : Icons.emoji_events_rounded,
                                    color: const Color(0xFFC9A66B),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Employee Name & Identification
                          Text(
                            current.employee.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF601A29).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: const Color(0xFF601A29).withValues(alpha: 0.25),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  current.employee.displayCode,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF601A29),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC9A66B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  current.employee.department ?? 'Team Nizan',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF601A29),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Milestone Banner & Countdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF601A29).withValues(alpha: 0.06),
                                  const Color(0xFFC9A66B).withValues(alpha: 0.14),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFC9A66B).withValues(alpha: 0.45),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  current.eventTitle,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF601A29),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: current.isToday
                                        ? const Color(0xFF1E7E34)
                                        : const Color(0xFFC9A66B),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    current.countdownText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  current.celebrationMessage,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: crm.textSecondary,
                                    height: 1.35,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Carousel Navigation if more than 1 celebration milestone
                          if (total > 1) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF601A29).withValues(alpha: 0.08),
                                  ),
                                  onPressed: _currentIndex > 0
                                      ? () => setState(() => _currentIndex--)
                                      : null,
                                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(total, (idx) {
                                    final isActive = idx == _currentIndex;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      width: isActive ? 18 : 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? const Color(0xFF601A29)
                                            : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    );
                                  }),
                                ),
                                IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF601A29).withValues(alpha: 0.08),
                                  ),
                                  onPressed: _currentIndex < total - 1
                                      ? () => setState(() => _currentIndex++)
                                      : null,
                                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Action Buttons Row
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    side: BorderSide(color: crm.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF601A29),
                                    foregroundColor: const Color(0xFFF5F3EF),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    widget.onWish?.call(current);
                                  },
                                  icon: const Icon(Icons.celebration_rounded, size: 18),
                                  label: const Text(
                                    'Post Wishes 🎉',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Confetti Particle Physics ───────────────────────────────────────────────

class _ConfettiParticle {
  late double x;
  late double y;
  late double size;
  late Color color;
  late double speed;
  late double angle;
  late double spin;

  _ConfettiParticle(math.Random rnd) {
    reset(rnd);
    y = rnd.nextDouble() * 500;
  }

  void reset(math.Random rnd) {
    x = rnd.nextDouble() * 450;
    y = -20;
    size = rnd.nextDouble() * 7 + 4;
    speed = rnd.nextDouble() * 2 + 1.2;
    angle = rnd.nextDouble() * math.pi * 2;
    spin = (rnd.nextDouble() - 0.5) * 0.15;

    const colors = [
      Color(0xFFC9A66B), // Gold
      Color(0xFF601A29), // Maroon
      Color(0xFFE11D48), // Rose
      Color(0xFF0D9488), // Teal
      Color(0xFFF59E0B), // Amber
      Color(0xFF4F46E5), // Indigo
      Color(0xFF10B981), // Emerald
    ];
    color = colors[rnd.nextInt(colors.length)];
  }

  void update(math.Random rnd) {
    y += speed * 2.2;
    x += math.sin(angle) * 1.5;
    angle += spin;
    if (y > 600) {
      reset(rnd);
    }
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double animationValue;
  final math.Random _rnd = math.Random();

  _ConfettiPainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      p.update(_rnd);
      paint.color = p.color;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.angle);

      // Ribbon rect or circle
      if (p.size > 8) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size * 1.5, height: p.size * 0.7),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
