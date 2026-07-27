import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/services/ai_voice_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/ai_orb_widgets.dart';
import '../../../../core/widgets/wavy_text.dart';
import '../../../authentication/presentation/provider/auth_provider.dart';
import '../provider/stock_features_provider.dart';

class AiAssistantScreen extends StatefulWidget {
  final bool startWithVoice;

  const AiAssistantScreen({super.key, this.startWithVoice = false});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const _prefAutoSend = 'ai_auto_send';
  static const _prefAutoMic = 'ai_auto_mic';
  static const _prefVoiceReply = 'ai_voice_reply';

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _voice = AiVoiceService.instance;

  bool _voiceReplyEnabled = true;
  bool _autoSendEnabled = true;
  bool _autoMicEnabled = true;
  bool _voiceReady = false;
  String? _voiceErrorMsg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<StockFeaturesProvider>().loadAiChat();
      await _loadVoicePrefs();
      if (widget.startWithVoice) {
        _autoMicEnabled = true;
      }
      await _refreshVoice();
      if ((_autoMicEnabled || widget.startWithVoice) && mounted) {
        await _startMicIfIdle();
      }
    });
  }

  Future<void> _loadVoicePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoSendEnabled = prefs.getBool(_prefAutoSend) ?? true;
      _autoMicEnabled = prefs.getBool(_prefAutoMic) ?? true;
      _voiceReplyEnabled = prefs.getBool(_prefVoiceReply) ?? true;
    });
  }

  Future<void> _saveVoicePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _refreshVoice() async {
    await _voice.initialize();
    if (!mounted) return;
    setState(() {
      _voiceReady = true;
      _voiceErrorMsg = null;
      if (!_voice.ttsAvailable) _voiceReplyEnabled = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _voice.stopListening();
    _voice.stopSpeaking();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _onSpeechResult(String text, bool isFinal) {
    if (!mounted) return;
    if (text == 'Listening… tap Stop when done') {
      setState(() => _controller.text = '');
      return;
    }
    setState(() => _controller.text = text);
    if (isFinal && _autoSendEnabled && text.trim().isNotEmpty && !text.startsWith('Listening')) {
      _send(text);
    }
  }

  Future<void> _send(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    final features = context.read<StockFeaturesProvider>();
    if (features.isAiLoading) return;

    await _voice.stopListening();
    _controller.clear();
    if (mounted) setState(() {});

    await features.sendAiMessage(query);
    if (!mounted) return;

    _scrollToBottom();

    if (_voiceReplyEnabled && _voice.ttsAvailable && features.aiError == null) {
      final last = features.aiMessages.isNotEmpty ? features.aiMessages.last : null;
      if (last != null && last.role == 'assistant') {
        try {
          setState(() => _voiceErrorMsg = null);
          await _voice.speak(last.content);
        } on ApiException catch (e) {
          setState(() => _voiceErrorMsg = e.message);
        } catch (_) {
          setState(() => _voiceErrorMsg = 'Could not play AI voice.');
        }
      }
    }

    if (_autoMicEnabled && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _startMicIfIdle();
    }
  }

  Future<void> _startMicIfIdle() async {
    final features = context.read<StockFeaturesProvider>();
    if (features.isAiLoading || _voice.isListening || _voice.isSpeaking) return;

    final started = await _voice.startListening(
      onResult: _onSpeechResult,
      preferDeviceStt: _autoSendEnabled,
    );
    if (!mounted || !started) return;
    setState(() {});
  }

  Future<void> _toggleMic() async {
    if (_voice.isListening) {
      try {
        await _voice.stopListening(onResult: _onSpeechResult);
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
          );
        }
      }
      if (mounted) setState(() {});
      return;
    }
    await _startMicIfIdle();
  }

  Future<void> _speakBubble(String text) async {
    try {
      setState(() => _voiceErrorMsg = null);
      await _voice.speak(text);
    } on ApiException catch (e) {
      setState(() => _voiceErrorMsg = e.message);
    } catch (_) {
      setState(() => _voiceErrorMsg = 'Could not play voice.');
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final auth = context.watch<AuthProvider>();
    final firstName = auth.user?.displayName.split(' ').first ?? 'Investor';
    final isListening = _voice.isListening;

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PremiumMeshBackground(
            glowPrimary: p.primary,
            glowSecondary: p.isDark ? AppColors.brandPink : p.heroCard,
          ),
          if (p.isDark) const PremiumFilmGrain(),
          SafeArea(
            child: Column(
              children: [
                _ChatHeader(
                  voiceReplyEnabled: _voiceReplyEnabled,
                  ttsAvailable: _voiceReady && _voice.ttsAvailable,
                  onToggleVoice: () async {
                    final next = !_voiceReplyEnabled;
                    setState(() => _voiceReplyEnabled = next);
                    await _saveVoicePref(_prefVoiceReply, next);
                  },
                  onClear: () => context.read<StockFeaturesProvider>().clearAiChat(),
                ),
                if (isListening)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      _controller.text.isNotEmpty ? _controller.text : 'Listening…',
                      textAlign: TextAlign.center,
                      style: ThemeAType.body(size: 16, color: p.textDark),
                    ),
                  ),
                Expanded(
                  child: Consumer<StockFeaturesProvider>(
                    builder: (context, features, _) {
                      _scrollToBottom();

                      if (features.aiMessages.isEmpty && !features.isAiLoading) {
                        return _GreetingPanel(
                          greeting: '${_greeting()}, $firstName',
                          isListening: isListening,
                          onTalk: _toggleMic,
                          onPortfolio: () => _send('Summarize my portfolio holdings and P&L'),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        itemCount: features.aiMessages.length + (features.isAiLoading ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (features.isAiLoading && i == features.aiMessages.length) {
                            return AiGlassBubble(
                              isUser: false,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: p.textGrey,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Thinking…'),
                                ],
                              ),
                            );
                          }

                          final m = features.aiMessages[i];
                          final isUser = m.role == 'user';

                          return AiGlassBubble(
                            isUser: isUser,
                            trailing: !isUser && _voice.ttsAvailable
                                ? IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    tooltip: 'Listen',
                                    icon: Icon(
                                      _voice.isSpeaking
                                          ? Icons.stop_circle_outlined
                                          : Icons.volume_up_rounded,
                                      size: 18,
                                      color: p.textGrey,
                                    ),
                                    onPressed: _voice.isSpeaking
                                        ? () => _voice.stopSpeaking()
                                        : () => _speakBubble(m.content),
                                  )
                                : null,
                            child: Text(m.content),
                          );
                        },
                      );
                    },
                  ),
                ),
                if (isListening)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AiListeningOrb(size: 100, active: true),
                  ),
                Consumer<StockFeaturesProvider>(
                  builder: (context, features, _) {
                    final err = features.aiError ?? _voiceErrorMsg;
                    if (err != null) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text(
                          err,
                          style: ThemeAType.label(size: 12, color: p.negative),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                Consumer<StockFeaturesProvider>(
                  builder: (context, features, _) {
                    if (features.aiSuggestions.isEmpty) return const SizedBox.shrink();
                    return SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: features.aiSuggestions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) => AiSuggestionPill(
                          label: features.aiSuggestions[i],
                          onTap: features.isAiLoading
                              ? null
                              : () => _send(features.aiSuggestions[i]),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _ChatInputBar(
                  controller: _controller,
                  isListening: isListening,
                  isLoading: context.watch<StockFeaturesProvider>().isAiLoading,
                  autoSend: _autoSendEnabled,
                  autoMic: _autoMicEnabled,
                  onToggleMic: _toggleMic,
                  onSend: () => _send(_controller.text),
                  onToggleAutoSend: (v) async {
                    setState(() => _autoSendEnabled = v);
                    await _saveVoicePref(_prefAutoSend, v);
                  },
                  onToggleAutoMic: (v) async {
                    setState(() => _autoMicEnabled = v);
                    await _saveVoicePref(_prefAutoMic, v);
                    if (v) {
                      await _startMicIfIdle();
                    } else {
                      await _voice.stopListening();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final bool voiceReplyEnabled;
  final bool ttsAvailable;
  final VoidCallback onToggleVoice;
  final VoidCallback onClear;

  const _ChatHeader({
    required this.voiceReplyEnabled,
    required this.ttsAvailable,
    required this.onToggleVoice,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _CircleBtn(
            icon: Icons.close_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: p.isDark
                ? BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: p.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  )
                : p.cardDecoration(radius: 999),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AiOrbLogo(size: 24, showArc: false, animate: false),
                const SizedBox(width: 10),
                WavyText(
                  text: kWavyChatbotName,
                  fontSize: 16,
                  color: p.textDark,
                ),
              ],
            ),
          ),
          const Spacer(),
          if (ttsAvailable)
            _CircleBtn(
              icon: voiceReplyEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              onTap: onToggleVoice,
              active: voiceReplyEnabled,
            )
          else
            const SizedBox(width: 44),
          _CircleBtn(icon: Icons.delete_outline_rounded, onTap: onClear),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 40,
          height: 40,
          decoration: p.isDark
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                )
              : p.cardDecoration(radius: 20),
          child: Icon(
            icon,
            size: 20,
            color: active
                ? (p.isDark ? p.primary : p.heroCard)
                : (p.isDark ? Colors.white.withValues(alpha: 0.85) : p.textDark),
          ),
        ),
      ),
    );
  }
}

class _GreetingPanel extends StatelessWidget {
  final String greeting;
  final bool isListening;
  final VoidCallback onTalk;
  final VoidCallback onPortfolio;

  const _GreetingPanel({
    required this.greeting,
    required this.isListening,
    required this.onTalk,
    required this.onPortfolio,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isListening) ...[
            const AiOrbLogo(size: 52, showArc: true, animate: true, showName: true),
            const SizedBox(height: 16),
            WavyText(
              text: kWavyChatbotName,
              fontSize: 34,
              color: p.textDark,
            ),
            const SizedBox(height: 6),
            Text(
              'Your Capital Bullwave AI assistant',
              style: ThemeAType.secondary(size: 14, color: p.textGrey),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            '$greeting 👋',
            style: ThemeAType.secondary(size: 15, color: p.textGrey),
          ),
          const SizedBox(height: 8),
          Text(
            'How may I help\nyou today?',
            style: ThemeAType.heading(size: 32, color: p.textDark),
          ),
          const SizedBox(height: 28),
          _ActionCard(
            title: 'Talk with AI',
            subtitle: 'Voice questions about markets',
            icon: Icons.mic_rounded,
            featured: true,
            onTap: onTalk,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  title: 'Chat',
                  subtitle: 'Type a question',
                  icon: Icons.chat_bubble_outline_rounded,
                  compact: true,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionCard(
                  title: 'Portfolio',
                  subtitle: 'Holdings & P&L',
                  icon: Icons.pie_chart_outline_rounded,
                  compact: true,
                  onTap: onPortfolio,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool compact;
  final bool featured;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.compact = false,
    this.featured = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final fg = featured
        ? (p.isDark ? p.textDark : p.heroCardFg)
        : p.textDark;
    final subtitleColor = featured
        ? (p.isDark ? p.textGrey : p.heroCardMuted)
        : p.textGrey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 14 : 18),
          decoration: featured
              ? (p.isDark ? p.accentCardDecoration(radius: 20) : p.heroCardDecoration(radius: 20))
              : p.cardDecoration(radius: 20),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: p.iconCircleDecoration(),
                      child: Icon(icon, color: p.textDark, size: 18),
                    ),
                    const SizedBox(height: 10),
                    Text(title, style: ThemeAType.cardTitle(size: 14, color: fg)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: ThemeAType.label(size: 11, color: subtitleColor),
                      ),
                    ],
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: p.isDark
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.onPrimary.withValues(alpha: 0.15),
                            )
                          : BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                      child: Icon(icon, color: fg, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: ThemeAType.cardTitle(size: 16, color: fg)),
                          Text(
                            subtitle,
                            style: ThemeAType.secondary(size: 12, color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.north_east_rounded, color: fg.withValues(alpha: 0.75), size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final bool isLoading;
  final bool autoSend;
  final bool autoMic;
  final VoidCallback onToggleMic;
  final VoidCallback onSend;
  final ValueChanged<bool> onToggleAutoSend;
  final ValueChanged<bool> onToggleAutoMic;

  const _ChatInputBar({
    required this.controller,
    required this.isListening,
    required this.isLoading,
    required this.autoSend,
    required this.autoMic,
    required this.onToggleMic,
    required this.onSend,
    required this.onToggleAutoSend,
    required this.onToggleAutoMic,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              _MiniToggle(label: 'Auto send', on: autoSend, onChanged: onToggleAutoSend),
              const SizedBox(width: 8),
              _MiniToggle(label: 'Auto mic', on: autoMic, onChanged: onToggleAutoMic),
            ],
          ),
          const SizedBox(height: 10),
          _buildInputShell(context, p),
        ],
      ),
    );
  }

  Widget _buildInputShell(BuildContext context, ThemePalette p) {
    final inputRow = Row(
      children: [
        GestureDetector(
          onTap: isLoading ? null : onToggleMic,
          child: Container(
            width: 44,
            height: 44,
            decoration: isListening
                ? (p.isDark
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [p.primary.withValues(alpha: 0.8), p.primaryDark],
                        ),
                      )
                    : p.heroCardDecoration(radius: 22))
                : BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.isDark ? Colors.white.withValues(alpha: 0.06) : p.iconBg,
                    border: Border.all(
                      color: p.isDark ? Colors.white.withValues(alpha: 0.08) : p.iconBorder,
                    ),
                  ),
            child: Icon(
              isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: isListening
                  ? (p.isDark ? Colors.white : p.heroCardFg)
                  : (p.isDark ? p.primary : p.textDark),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isLoading,
            style: ThemeAType.body(size: 14, color: p.textDark),
            decoration: InputDecoration(
              hintText: autoSend
                  ? 'Speak or type — auto sends on pause'
                  : 'Ask about stocks & portfolio…',
              hintStyle: ThemeAType.secondary(size: 13, color: p.textMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onSubmitted: (_) => onSend(),
          ),
        ),
        GestureDetector(
          onTap: isLoading ? null : onSend,
          child: Container(
            width: 44,
            height: 44,
            decoration: p.isDark
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [p.primary.withValues(alpha: 0.85), const Color(0xFF6366F1)],
                    ),
                  )
                : p.heroCardDecoration(radius: 22),
            child: Icon(
              Icons.arrow_upward_rounded,
              color: p.isDark ? p.onPrimary : p.heroCardFg,
              size: 22,
            ),
          ),
        ),
      ],
    );

    if (p.isDark) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: inputRow,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: p.cardDecoration(radius: 999),
      child: inputRow,
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final String label;
  final bool on;
  final ValueChanged<bool> onChanged;

  const _MiniToggle({
    required this.label,
    required this.on,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return GestureDetector(
      onTap: () => onChanged(!on),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on
              ? (p.isDark ? p.primarySoft : p.primarySoft)
              : (p.isDark ? Colors.white.withValues(alpha: 0.05) : p.surface),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: on
                ? (p.isDark ? p.primaryBorder : p.primaryBorder)
                : (p.isDark ? Colors.white.withValues(alpha: 0.08) : p.borderLight),
          ),
        ),
        child: Text(
          label,
          style: ThemeAType.label(
            size: 10,
            color: on ? p.textDark : p.textMuted,
          ),
        ),
      ),
    );
  }
}
