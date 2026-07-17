import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../models/market_mood_model.dart';

class MoodDetectorScreen extends StatefulWidget {
  const MoodDetectorScreen({super.key});

  @override
  State<MoodDetectorScreen> createState() => _MoodDetectorScreenState();
}

class _MoodDetectorScreenState extends State<MoodDetectorScreen> {
  MarketMoodModel? _mood;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final mood = await BullwaveApi.instance.getMarketMood();
      if (!mounted) return;
      setState(() {
        _mood = mood;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not read the market mood right now.';
        _loading = false;
      });
    }
  }

  Color _moodColor(ThemePalette p, String mood) {
    switch (mood) {
      case 'extreme_fear':
        return const Color(0xFFDC2626);
      case 'fear':
        return const Color(0xFFF97316);
      case 'greed':
        return const Color(0xFF84CC16);
      case 'extreme_greed':
        return p.positive;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: 'AI Mood Detector',
        subtitle: 'Market sentiment, read live',
      ),
      body: RefreshIndicator(
        color: p.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            if (_loading) ...[
              const SizedBox(height: 120),
              const Center(child: CircularProgressIndicator()),
            ] else if (_error != null)
              _ErrorState(message: _error!, onRetry: _load)
            else if (_mood != null)
              _MoodContent(mood: _mood!, moodColor: _moodColor(p, _mood!.mood)),
          ],
        ),
      ),
    );
  }
}

class _MoodContent extends StatelessWidget {
  final MarketMoodModel mood;
  final Color moodColor;

  const _MoodContent({required this.mood, required this.moodColor});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Today\'s mood',
                    style: ThemeAType.cardTitle(color: p.textGrey, size: 13),
                  ),
                  const Spacer(),
                  if (mood.aiGenerated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'AI',
                        style: ThemeAType.label(size: 10, color: p.primary).copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                mood.moodLabel,
                style: ThemeAType.heading(size: 30, color: moodColor),
              ),
              const SizedBox(height: 16),
              _MoodGauge(score: mood.score, color: moodColor),
              const SizedBox(height: 20),
              Text(
                mood.commentary,
                style: ThemeAType.body(color: p.textDark, size: 14).copyWith(height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Nifty 50 today',
                value: '${mood.indexChangePercent >= 0 ? '+' : ''}${mood.indexChangePercent.toStringAsFixed(2)}%',
                color: mood.indexChangePercent >= 0 ? p.positive : p.negative,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Advancers',
                value: '${mood.advancers}/${mood.universeSize}',
                color: p.positive,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Decliners',
                value: '${mood.decliners}/${mood.universeSize}',
                color: p.negative,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MoodGauge extends StatelessWidget {
  final double score;
  final Color color;

  const _MoodGauge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final clamped = score.clamp(0, 100) / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(
                height: 14,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFDC2626),
                      Color(0xFFF97316),
                      Color(0xFFF59E0B),
                      Color(0xFF84CC16),
                      Color(0xFF15803D),
                    ],
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final x = (constraints.maxWidth * clamped).clamp(0.0, constraints.maxWidth - 4);
                  return Positioned(
                    left: x,
                    child: Container(
                      width: 4,
                      height: 14,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Extreme fear', style: ThemeAType.label(size: 10, color: p.textMuted)),
            Text(
              score.toStringAsFixed(0),
              style: ThemeAType.label(size: 16, color: color).copyWith(fontWeight: FontWeight.w800),
            ),
            Text('Extreme greed', style: ThemeAType.label(size: 10, color: p.textMuted)),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ThemeAType.label(size: 10, color: p.textMuted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: ThemeAType.label(size: 14, color: color).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: p.negative.withValues(alpha: 0.8)),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: ThemeAType.body(color: p.textGrey, size: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: p.primary,
              side: BorderSide(color: p.primary.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
