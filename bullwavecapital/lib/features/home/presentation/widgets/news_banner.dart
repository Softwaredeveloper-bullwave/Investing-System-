import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/widgets/scale_tap.dart';
import 'home_theme_a.dart';

/// Live market news ticker — continuous yellow marquee for the home screen.
class NewsHeadlineTicker extends StatefulWidget {
  final List<Map<String, String>> headlines;
  final VoidCallback? onTap;

  const NewsHeadlineTicker({
    super.key,
    required this.headlines,
    this.onTap,
  });

  @override
  State<NewsHeadlineTicker> createState() => _NewsHeadlineTickerState();
}

class _NewsHeadlineTickerState extends State<NewsHeadlineTicker>
    with SingleTickerProviderStateMixin {
  static const _newsYellow = Color(0xFFFFD60A);

  static const _fallbackHeadlines = [
    {'title': 'Nifty 50 eyes fresh highs as FII inflows strengthen', 'subtitle': 'Markets'},
    {'title': 'RBI holds repo rate steady; stance remains accommodative', 'subtitle': 'Policy'},
    {'title': 'IT majors lead gains ahead of earnings season', 'subtitle': 'Stocks'},
    {'title': 'Gold rallies on safe-haven demand amid global volatility', 'subtitle': 'Commodities'},
    {'title': 'Bank Nifty tracks PSU banks amid rate-cut speculation', 'subtitle': 'Banking'},
    {'title': 'FII inflows turn positive for third consecutive session', 'subtitle': 'Flows'},
  ];

  AnimationController? _controller;
  double _segmentWidth = 0;
  String _loopText = '';

  List<Map<String, String>> get _items =>
      widget.headlines.isNotEmpty ? widget.headlines : _fallbackHeadlines;

  String get _joinedHeadlines {
    final titles = _items
        .map((n) => n['title']?.trim() ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
    if (titles.isEmpty) return 'Market news updating…';
    return titles.join('     •     ');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupMarquee());
  }

  @override
  void didUpdateWidget(covariant NewsHeadlineTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.headlines != widget.headlines) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _setupMarquee());
    }
  }

  void _setupMarquee() {
    if (!mounted) return;

    final style = _headlineStyle();
    // Duplicate once so short feeds still exceed the viewport and keep scrolling.
    final base = _joinedHeadlines;
    final loopText = '$base     •     ';

    final painter = TextPainter(
      text: TextSpan(text: loopText, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final width = painter.width;
    if (width <= 0) return;

    _controller?.dispose();
    // Constant ~42 px/sec so news always crawls continuously.
    final seconds = (width / 42).clamp(10.0, 90.0);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (seconds * 1000).round()),
    )..repeat();

    setState(() {
      _segmentWidth = width;
      _loopText = loopText;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  TextStyle _headlineStyle() {
    return const TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0.15,
      color: _newsYellow,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = _headlineStyle();
    final fallback = _joinedHeadlines;

    return ScaleTap(
      onTap: widget.onTap,
      child: Container(
        height: 52,
        decoration: p.cardDecoration(radius: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: _LiveBadge(palette: p),
              ),
              Expanded(
                child: _controller == null || _segmentWidth <= 0 || _loopText.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          fallback,
                          style: style,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : _MarqueeText(
                        controller: _controller!,
                        segmentWidth: _segmentWidth,
                        loopText: _loopText,
                        style: style,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  PhosphorIcons.caretRight,
                  size: 16,
                  color: _newsYellow.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarqueeText extends StatelessWidget {
  final AnimationController controller;
  final double segmentWidth;
  final String loopText;
  final TextStyle style;

  const _MarqueeText({
    required this.controller,
    required this.segmentWidth,
    required this.loopText,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            colors: [
              Color(0x00FFFFFF),
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0.0, 0.05, 0.95, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: Transform.translate(
                offset: Offset(-controller.value * segmentWidth, 0),
                child: Text(
                  '$loopText$loopText',
                  style: style,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  final ThemePalette palette;
  const _LiveBadge({required this.palette});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> {
  bool _pulse = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) setState(() => _pulse = !_pulse);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: widget.palette.primaryPillDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _pulse ? 6 : 5,
            height: _pulse ? 6 : 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.palette.negative,
              boxShadow: [
                BoxShadow(
                  color: widget.palette.negative.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: ThemeAType.label(size: 10, color: widget.palette.negative)
                .copyWith(letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }
}

/// Backward-compatible alias.
typedef NewsBanner = NewsHeadlineTicker;
