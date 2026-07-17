import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../models/trader_note_model.dart';
import '../provider/notes_provider.dart';
import '../widgets/note_editor_sheet.dart';

class InvestmentNotesScreen extends StatefulWidget {
  final String? initialCategory;
  final String title;

  const InvestmentNotesScreen({
    super.key,
    this.initialCategory,
    this.title = 'Investment Journal',
  });

  @override
  State<InvestmentNotesScreen> createState() => _InvestmentNotesScreenState();
}

class _InvestmentNotesScreenState extends State<InvestmentNotesScreen> {
  final _searchController = TextEditingController();
  String? _activeFilter;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialCategory;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotesProvider>().load(category: _activeFilter);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor({TraderNoteModel? note}) async {
    final saved = await NoteEditorSheet.show(
      context,
      note: note,
      defaultCategory: _activeFilter ?? note?.category ?? 'general',
    );
    if (saved == true && mounted) {
      await context.read<NotesProvider>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(title: widget.title),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: ThemeA.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
      ),
      body: Consumer<NotesProvider>(
        builder: (context, notes, _) {
          if (notes.isLoading && notes.notes.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: LoadingCard(height: 200),
            );
          }

          return RefreshIndicator(
            color: AppColors.brandCyan,
            onRefresh: notes.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                PremiumSearchBar(
                  controller: _searchController,
                  hint: 'Search notes, symbols, ideas…',
                  onChanged: notes.setSearchQuery,
                ),
                const SizedBox(height: 14),
                _BeginnerLearnCard(
                  onOpenDocs: () => context.push(AppRoutes.documentCategoryPath('beginner')),
                ),
                const SizedBox(height: 14),
                _FilterChips(
                  active: _activeFilter,
                  onSelected: (value) {
                    setState(() => _activeFilter = value);
                    notes.setCategoryFilter(value);
                  },
                ),
                if (notes.error != null) ...[
                  const SizedBox(height: 12),
                  PremiumAlertBanner(
                    message: notes.error!,
                    type: PremiumAlertType.warning,
                    actionLabel: 'Retry',
                    onAction: notes.refresh,
                  ),
                ],
                const SizedBox(height: 16),
                if (notes.notes.isEmpty)
                  _EmptyNotes(onCreate: () => _openEditor())
                else
                  ...notes.notes.map(
                    (note) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _NoteCard(
                        note: note,
                        onTap: () => _openEditor(note: note),
                        onPin: () => notes.togglePin(note),
                        onDelete: () async {
                          final ok = await _confirmDelete(context, note.title);
                          if (ok && context.mounted) {
                            await notes.deleteNote(note.id);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete note?'),
            content: Text('Remove "$title"? This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _BeginnerLearnCard extends StatelessWidget {
  final VoidCallback onOpenDocs;

  const _BeginnerLearnCard({required this.onOpenDocs});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      onTap: onOpenDocs,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school_rounded, color: Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New to investing?', style: ThemeAType.cardTitle(color: p.textDark)),
                Text(
                  'Read Beginner guides in Documents, then use templates when you write notes.',
                  style: ThemeAType.body(color: p.textGrey, size: 13),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: p.textGrey, size: 20),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String? active;
  final ValueChanged<String?> onSelected;

  const _FilterChips({required this.active, required this.onSelected});

  static const _filters = [
    (null, 'All'),
    ('general', 'General'),
    ('stock', 'Stocks'),
    ('trade_idea', 'Ideas'),
    ('journal', 'Journal'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((item) {
          final selected = active == item.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(item.$2),
              selected: selected,
              onSelected: (_) => onSelected(item.$1),
              selectedColor: ThemeA.primary.withValues(alpha: 0.15),
              checkmarkColor: ThemeA.primary,
              labelStyle: ThemeAType.label(
                size: 13,
                color: selected ? ThemeA.primary : p.textGrey,
              ),
              side: BorderSide(color: selected ? ThemeA.primary : p.borderLight),
              backgroundColor: p.card,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final TraderNoteModel note;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onPin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  note.title.isEmpty ? 'Untitled note' : note.title,
                  style: ThemeAType.cardTitle(color: p.textDark),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onPin,
                icon: Icon(
                  note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  size: 18,
                  color: note.isPinned ? ThemeA.primary : p.textGrey,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: p.textGrey, size: 20),
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                  if (value == 'edit') onTap();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note.preview,
            style: ThemeAType.body(color: p.textGrey, size: 14),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _TagChip(label: note.categoryLabel, color: ThemeA.primary),
              if (note.symbol.isNotEmpty)
                _TagChip(label: note.symbol, color: AppColors.brandCyan),
              Text(
                DateFormatter.displayWithTime(note.updatedAt),
                style: ThemeAType.label(size: 12, color: p.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: ThemeAType.label(size: 11, color: color),
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyNotes({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.note_alt_outlined, size: 56, color: p.textMuted),
          const SizedBox(height: 16),
          Text('No notes yet', style: ThemeAType.sectionTitle(color: p.textDark)),
          const SizedBox(height: 8),
          Text(
            'Capture trade ideas, stock research, and daily journal entries in one place.',
            textAlign: TextAlign.center,
            style: ThemeAType.body(color: p.textGrey),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Write your first note'),
          ),
        ],
      ),
    );
  }
}
