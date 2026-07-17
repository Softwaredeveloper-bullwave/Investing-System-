import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/theme_a.dart';
import 'wavy_text.dart';

/// Glassmorphism AI buddy avatar — blue gradient tile + face + optional "wavy" label.
class AiOrbLogo extends StatefulWidget {
  final double size;
  final bool showArc;
  final bool animate;
  final bool showName;

  const AiOrbLogo({
    super.key,
    this.size = 56,
    this.showArc = true,
    this.animate = true,
    this.showName = false,
  });

  @override
  State<AiOrbLogo> createState() => _AiOrbLogoState();
}

class _AiOrbLogoState extends State<AiOrbLogo> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.animate) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AiOrbLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.animate) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.size * 0.28;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = widget.animate ? _pulse.value : 0.0;
        final glow = 0.18 + t * 0.14;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.showArc)
                Container(
                  width: widget.size * 1.18,
                  height: widget.size * 1.18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius * 1.18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: glow),
                        blurRadius: 18 + t * 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1D4ED8),
                      Color(0xFF2563EB),
                      Color(0xFF0EA5E9),
                      Color(0xFF38BDF8),
                    ],
                    stops: [0.0, 0.35, 0.72, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35 + t * 0.1),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _AiBuddyFacePainter(
                          breathe: t,
                          compact: widget.showName,
                        ),
                        size: Size.square(widget.size),
                      ),
                      if (widget.showName)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: widget.size * 0.07,
                          child: Text(
                            kWavyChatbotName.toLowerCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: (widget.size * 0.17).clamp(8, 11),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.6,
                              height: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AiBuddyFacePainter extends CustomPainter {
  final double breathe;
  final bool compact;

  _AiBuddyFacePainter({this.breathe = 0, this.compact = false});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * (compact ? 0.44 : 0.53);
    final scale = 1.0 + breathe * 0.04;
    final blobW = size.width * 0.58 * scale;
    final blobH = size.height * 0.5 * scale;
    final blobRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: blobW, height: blobH),
      Radius.circular(blobH * 0.42),
    );

    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28 + breathe * 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: blobW * 1.08, height: blobH * 1.08),
        Radius.circular(blobH * 0.46),
      ),
      glowPaint,
    );

    final blobPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.25),
        radius: 0.95,
        colors: [
          Colors.white.withValues(alpha: 0.97),
          Colors.white.withValues(alpha: 0.72),
          Colors.white.withValues(alpha: 0.38),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(blobRect.outerRect);
    canvas.drawRRect(blobRect, blobPaint);

    final highlight = Paint()
      ..shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 0.75,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCenter(
          center: Offset(cx, cy - blobH * 0.18),
          width: blobW * 0.7,
          height: blobH * 0.45,
        ),
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy - blobH * 0.15),
          width: blobW * 0.62,
          height: blobH * 0.34,
        ),
        Radius.circular(blobH * 0.2),
      ),
      highlight,
    );

    final eyeW = size.width * 0.058;
    final eyeH = size.height * 0.115;
    final eyeY = cy - size.height * 0.015;
    final eyeGap = size.width * 0.105;
    final eyePaint = Paint()..color = Colors.white;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - eyeGap, eyeY), width: eyeW, height: eyeH),
      eyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + eyeGap, eyeY), width: eyeW, height: eyeH),
      eyePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AiBuddyFacePainter old) =>
      old.breathe != breathe || old.compact != compact;
}

/// Large listening-state orb with pulse rings.
class AiListeningOrb extends StatefulWidget {
  final double size;
  final bool active;

  const AiListeningOrb({
    super.key,
    this.size = 120,
    this.active = true,
  });

  @override
  State<AiListeningOrb> createState() => _AiListeningOrbState();
}

class _AiListeningOrbState extends State<AiListeningOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AiListeningOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.active) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = widget.active ? _pulse.value : 0.0;
        final ringScale = 1.0 + t * 0.18;

        return SizedBox(
          width: widget.size * 1.4,
          height: widget.size * 1.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: ringScale,
                child: Container(
                  width: widget.size * 1.15,
                  height: widget.size * 1.15,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.size * 0.32),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.2 + t * 0.25),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: 1.0 + t * 0.06,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.size * 0.28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.35 + t * 0.2),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: AiOrbLogo(size: widget.size, showArc: false, animate: widget.active),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Chat bubble — white cards (light) / glass (dark).
class AiGlassBubble extends StatelessWidget {
  final Widget child;
  final bool isUser;
  final Widget? trailing;

  const AiGlassBubble({
    super.key,
    required this.child,
    required this.isUser,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (!isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 48),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiOrbLogo(size: 28, showArc: false, animate: false),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: p.cardDecoration(radius: 20),
                    child: DefaultTextStyle(
                      style: ThemeAType.body(size: 14, color: p.textDark),
                      child: child,
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 48),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: p.isDark
              ? BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.brandPrimary.withValues(alpha: 0.35),
                      AppColors.brandPink.withValues(alpha: 0.22),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                )
              : p.heroCardDecoration(radius: 22),
          child: DefaultTextStyle(
            style: ThemeAType.body(
              size: 14,
              color: p.isDark ? Colors.white.withValues(alpha: 0.95) : p.heroCardFg,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Pill suggestion chip for AI chat.
class AiSuggestionPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const AiSuggestionPill({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: p.isDark
              ? BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                )
              : p.cardDecoration(radius: 999),
          child: Text(
            label,
            style: ThemeAType.label(size: 12, color: p.textDark),
          ),
        ),
      ),
    );
  }
}
