import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../models/paper_trading_model.dart';
import '../provider/paper_trading_provider.dart';
import '../widgets/simulation_badge.dart';

const _moods = ['confident', 'neutral', 'anxious', 'fomo', 'disciplined'];

/// Trading journal — reflection notes a learner attaches to their paper
/// trading, independent of any single trade.
class PaperJournalScreen extends StatefulWidget {
  const PaperJournalScreen({super.key});

  @override
  State<PaperJournalScreen> createState() => _PaperJournalScreenState();
}

class _PaperJournalScreenState extends State<PaperJournalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaperTradingProvider>().loadJournal();
    });
  }

  Future<void> _openEntrySheet() async {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    final symbolController = TextEditingController();
    final lessonController = TextEditingController();
    String mood = '';
    int rating = 3;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New journal entry', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: symbolController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Symbol (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lessonController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Lesson learned', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: _moods.map((m) {
                    return ChoiceChip(
                      label: Text(m),
                      selected: mood == m,
                      onSelected: (_) => setSheetState(() => mood = mood == m ? '' : m),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Rating', style: TextStyle(fontWeight: FontWeight.w700)),
                    Expanded(
                      child: Slider(
                        value: rating.toDouble(),
                        min: 1, max: 5, divisions: 4,
                        label: '$rating',
                        onChanged: (v) => setSheetState(() => rating = v.round()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(content: Text('Title is required.')),
                        );
                        return;
                      }
                      Navigator.of(sheetContext).pop(true);
                    },
                    child: const Text('Save Entry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved != true || !mounted) return;
    if (titleController.text.trim().isEmpty) return;

    final ok = await context.read<PaperTradingProvider>().createJournalEntry(
          title: titleController.text.trim(),
          notes: notesController.text.trim(),
          symbol: symbolController.text.trim(),
          lessonLearned: lessonController.text.trim(),
          mood: mood,
          rating: rating,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Journal entry saved.' : 'Could not save entry.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _delete(PaperJournalEntryModel entry) async {
    await context.read<PaperTradingProvider>().deleteJournalEntry(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: 'Trading Journal',
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _openEntrySheet),
        ],
      ),
      body: Consumer<PaperTradingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingJournal && provider.journal.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: LoadingList(itemCount: 4, itemHeight: 90),
            );
          }
          final entries = provider.journal;
          return RefreshIndicator(
            color: AppColors.brandOrange,
            onRefresh: () => context.read<PaperTradingProvider>().loadJournal(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Align(alignment: Alignment.centerLeft, child: SimulationOnlyBadge(compact: true)),
                const SizedBox(height: 14),
                if (entries.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    decoration: AppDecorations.card(context),
                    child: Column(
                      children: [
                        Icon(Icons.menu_book_outlined, size: 40, color: colors.textMuted),
                        const SizedBox(height: 10),
                        Text('No journal entries yet', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Reflect on a trade with the + button above.', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                      ],
                    ),
                  )
                else
                  ...entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _JournalCard(entry: e, onDelete: () => _delete(e)),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final PaperJournalEntryModel entry;
  final VoidCallback onDelete;

  const _JournalCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              if (entry.rating != null)
                Row(
                  children: List.generate(5, (i) => Icon(
                        i < entry.rating! ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 14, color: AppColors.brandOrange,
                      )),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (entry.symbol.isNotEmpty || entry.mood.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                if (entry.symbol.isNotEmpty)
                  _Tag(label: entry.symbol, color: AppColors.blue),
                if (entry.mood.isNotEmpty)
                  _Tag(label: entry.mood, color: AppColors.brandPurple),
              ],
            ),
          ],
          if (entry.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(entry.notes, style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.35)),
          ],
          if (entry.lessonLearned.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Lesson: ${entry.lessonLearned}', style: TextStyle(color: colors.textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }
}
