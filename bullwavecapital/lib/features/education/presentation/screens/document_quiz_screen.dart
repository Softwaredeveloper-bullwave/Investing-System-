import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../models/investment_doc_model.dart';
import '../provider/education_provider.dart';

class DocumentQuizScreen extends StatefulWidget {
  final String quizId;

  const DocumentQuizScreen({super.key, required this.quizId});

  @override
  State<DocumentQuizScreen> createState() => _DocumentQuizScreenState();
}

class _DocumentQuizScreenState extends State<DocumentQuizScreen> {
  int _index = 0;
  int? _selected;
  int _score = 0;
  bool _answered = false;
  bool _finished = false;
  bool _loading = true;
  InvestmentDocQuiz? _quiz;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    final provider = context.read<EducationProvider>();
    await provider.loadCatalog();
    final quiz = await provider.fetchQuiz(widget.quizId);
    if (!mounted) return;
    setState(() {
      _quiz = quiz;
      _loading = false;
    });
  }

  void _submitAnswer() {
    final quiz = _quiz;
    if (quiz == null || _selected == null || _answered) return;
    final correct = _selected == quiz.questions[_index].correctIndex;
    setState(() {
      _answered = true;
      if (correct) _score++;
    });
  }

  void _next() {
    final quiz = _quiz;
    if (quiz == null) return;
    if (_index >= quiz.questions.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _answered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Quiz'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final quiz = _quiz;
    if (quiz == null || quiz.questions.isEmpty) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Quiz'),
        body: const Center(child: Text('Quiz not found')),
      );
    }

    if (_finished) {
      return _ResultsView(
        quiz: quiz,
        score: _score,
        onRetry: () => setState(() {
          _index = 0;
          _selected = null;
          _score = 0;
          _answered = false;
          _finished = false;
        }),
      );
    }

    final question = quiz.questions[_index];
    final p = context.palette;
    final progress = (_index + 1) / quiz.questions.length;
    final prompt = question.prompt.isNotEmpty
        ? question.prompt
        : 'Question ${_index + 1}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(title: quiz.title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: p.borderLight,
              color: ThemeA.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Question ${_index + 1} of ${quiz.questions.length}',
            style: ThemeAType.label(size: 12, color: p.textMuted),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Text(
              prompt,
              style: ThemeAType.sectionTitle(size: 18, color: p.textDark).copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          ...question.options.asMap().entries.map((entry) {
            final i = entry.key;
            final label = entry.value;
            final selected = _selected == i;
            Color? borderColor;
            if (_answered) {
              if (i == question.correctIndex) {
                borderColor = AppColors.green;
              } else if (selected) {
                borderColor = AppColors.error;
              }
            } else if (selected) {
              borderColor = ThemeA.primary;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                onTap: _answered ? null : () => setState(() => _selected = i),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      _answered
                          ? (i == question.correctIndex
                              ? Icons.check_circle_rounded
                              : (selected ? Icons.cancel_rounded : Icons.radio_button_off))
                          : (selected ? Icons.radio_button_checked : Icons.radio_button_off),
                      color: borderColor ?? p.textGrey,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(label, style: ThemeAType.body(color: p.textDark)),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_answered) ...[
            const SizedBox(height: 8),
            PremiumAlertBanner(
              message: question.explanation,
              type: _selected == question.correctIndex
                  ? PremiumAlertType.success
                  : PremiumAlertType.info,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _answered
                ? _next
                : (_selected == null ? null : _submitAnswer),
            child: Text(_answered
                ? (_index >= quiz.questions.length - 1 ? 'See results' : 'Next question')
                : 'Check answer'),
          ),
        ],
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  final InvestmentDocQuiz quiz;
  final int score;
  final VoidCallback onRetry;

  const _ResultsView({
    required this.quiz,
    required this.score,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final total = quiz.questions.length;
    final pct = total == 0 ? 0 : ((score / total) * 100).round();
    final message = pct >= 80
        ? 'Excellent — strong grasp of the material!'
        : pct >= 50
            ? 'Good effort — re-read weak topics in Documents.'
            : 'Keep learning — start with Beginner guides and retry.';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(title: quiz.title),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Icon(
              pct >= 50 ? Icons.emoji_events_outlined : Icons.menu_book_outlined,
              size: 64,
              color: ThemeA.primary,
            ),
            const SizedBox(height: 16),
            Text('$score / $total correct', style: ThemeAType.sectionTitle(size: 28, color: p.textDark)),
            Text('$pct%', style: ThemeAType.sectionTitle(color: ThemeA.primary)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: ThemeAType.body(color: p.textGrey)),
            const Spacer(),
            FilledButton(onPressed: onRetry, child: const Text('Retry quiz')),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Documents')),
          ],
        ),
      ),
    );
  }
}
