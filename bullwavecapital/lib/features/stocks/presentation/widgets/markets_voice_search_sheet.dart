import 'package:flutter/material.dart';

import '../../../../core/services/ai_voice_service.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/ai_orb_widgets.dart';
import '../../../../core/widgets/scale_tap.dart';

/// Voice search sheet for Markets — speak to fill the stock search query live.
Future<String?> showMarketsVoiceSearchSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MarketsVoiceSearchSheet(),
  );
}

class _MarketsVoiceSearchSheet extends StatefulWidget {
  const _MarketsVoiceSearchSheet();

  @override
  State<_MarketsVoiceSearchSheet> createState() => _MarketsVoiceSearchSheetState();
}

class _MarketsVoiceSearchSheetState extends State<_MarketsVoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  final _voice = AiVoiceService.instance;
  late final AnimationController _pulse;

  String _transcript = '';
  String? _error;
  bool _ready = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _pulse.dispose();
    _voice.stopListening();
    super.dispose();
  }

  Future<void> _start() async {
    await _voice.initialize();
    if (!mounted) return;
    setState(() => _ready = true);
    await _beginListening();
  }

  Future<void> _beginListening() async {
    setState(() {
      _error = null;
      _listening = true;
    });
    final started = await _voice.startListening(
      preferDeviceStt: true,
      onResult: (text, isFinal) {
        if (!mounted) return;
        final cleaned = _cleanTranscript(text);
        setState(() {
          _transcript = cleaned;
          _listening = !isFinal;
        });
        if (isFinal && cleaned.isNotEmpty) {
          Navigator.of(context).pop(cleaned);
        }
      },
    );
    if (!mounted) return;
    if (!started) {
      setState(() {
        _listening = false;
        _error = 'Microphone permission denied or speech not available.';
      });
    }
  }

  String _cleanTranscript(String raw) {
    var text = raw.trim();
    if (text.toLowerCase().startsWith('listening')) return '';
    // Prefer the last spoken symbol-like token for stock search.
    final upper = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ');
    final parts = upper.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return text;
    // If user said "search reliance" / "find tcs stock", keep useful words.
    final stop = {'SEARCH', 'FIND', 'SHOW', 'STOCK', 'SHARE', 'FOR', 'THE', 'OF', 'PLEASE'};
    final meaningful = parts.where((p) => !stop.contains(p)).toList();
    if (meaningful.isEmpty) return text;
    return meaningful.join(' ');
  }

  Future<void> _toggle() async {
    if (_voice.isListening) {
      await _voice.stopListening();
      if (!mounted) return;
      setState(() => _listening = false);
      if (_transcript.trim().isNotEmpty) {
        Navigator.of(context).pop(_transcript.trim());
      }
      return;
    }
    await _beginListening();
  }

  void _useTranscript() {
    final q = _transcript.trim();
    if (q.isEmpty) return;
    Navigator.of(context).pop(q);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: p.borderLight),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Voice search',
                style: ThemeAType.sectionTitle(color: p.textDark, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                _listening
                    ? 'Speak a stock name or symbol…'
                    : 'Tap the mic and say what to search',
                style: ThemeAType.body(color: p.textGrey, size: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final t = _listening ? _pulse.value : 0.0;
                  return Container(
                    width: 110 + t * 12,
                    height: 110 + t * 12,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: p.primary.withValues(alpha: 0.18 + t * 0.2),
                          blurRadius: 24 + t * 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: ScaleTap(
                  onTap: _ready ? _toggle : null,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_listening ? p.primary : p.surface).withValues(alpha: 0.95),
                      border: Border.all(
                        color: p.primary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      size: 40,
                      color: _listening ? p.bg : p.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _listening ? 'Listening…' : (_ready ? 'Ready' : 'Preparing mic…'),
                style: ThemeAType.label(
                  size: 13,
                  color: _listening ? p.primary : p.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surface.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.borderLight),
                ),
                child: Text(
                  _transcript.isEmpty
                      ? 'Try: “Reliance”, “TCS”, “HDFC Bank”…'
                      : _transcript,
                  textAlign: TextAlign.center,
                  style: ThemeAType.cardTitle(
                    color: _transcript.isEmpty ? p.textMuted : p.textDark,
                    size: 16,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: ThemeAType.body(color: p.negative, size: 13),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _transcript.trim().isEmpty ? null : _useTranscript,
                      child: const Text('Search'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const AiOrbLogo(size: 36, showArc: false, animate: true, showName: false),
            ],
          ),
        ),
      ),
    );
  }
}
