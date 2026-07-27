import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../models/trader_note_model.dart';
import '../../../education/data/education_ui.dart';
import '../provider/notes_provider.dart';

class NoteEditorSheet extends StatefulWidget {
  final TraderNoteModel? note;
  final String defaultCategory;

  const NoteEditorSheet({
    super.key,
    this.note,
    this.defaultCategory = 'general',
  });

  static Future<bool?> show(
    BuildContext context, {
    TraderNoteModel? note,
    String defaultCategory = 'general',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteEditorSheet(note: note, defaultCategory: defaultCategory),
    );
  }

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _symbolController;
  late String _category;
  late bool _isPinned;
  bool _isSaving = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController = TextEditingController(text: note?.title ?? '');
    _bodyController = TextEditingController(text: note?.body ?? '');
    _symbolController = TextEditingController(text: note?.symbol ?? '');
    _category = note?.category ?? widget.defaultCategory;
    _isPinned = note?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _symbolController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty && body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title or note content')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final saved = await context.read<NotesProvider>().saveNote(
          id: widget.note?.id,
          title: title.isEmpty ? 'Untitled note' : title,
          body: body,
          symbol: _symbolController.text.trim().toUpperCase(),
          category: _category,
          isPinned: _isPinned,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (saved != null) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Note updated' : 'Note saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final err = context.read<NotesProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Could not save note'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: p.borderLight),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit note' : 'New note',
                        style: ThemeAType.sectionTitle(color: p.textDark),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _isPinned = !_isPinned),
                      icon: Icon(
                        _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                        color: _isPinned ? ThemeA.primary : p.textGrey,
                      ),
                    ),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isEditing ? 'Update' : 'Save'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!_isEditing) ...[
                  Text('Beginner templates', style: ThemeAType.label(size: 12, color: p.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: BeginnerNoteTemplates.templates.map((template) {
                      return ActionChip(
                        label: Text(template.title, style: ThemeAType.label(size: 12, color: p.textDark)),
                        onPressed: () {
                          _titleController.text = template.title;
                          _bodyController.text = template.body;
                          setState(() => _category = 'general');
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _titleController,
                  style: ThemeAType.cardTitle(color: p.textDark),
                  decoration: InputDecoration(
                    hintText: 'Title — e.g. RELIANCE breakout plan',
                    hintStyle: ThemeAType.body(color: p.textMuted),
                    filled: true,
                    fillColor: p.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _symbolController,
                        style: ThemeAType.body(color: p.textDark),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Symbol (optional)',
                          hintStyle: ThemeAType.body(color: p.textMuted),
                          prefixIcon: Icon(Icons.tag_rounded, color: p.textGrey, size: 20),
                          filled: true,
                          fillColor: p.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: p.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'general', child: Text('General')),
                          DropdownMenuItem(value: 'stock', child: Text('Stock')),
                          DropdownMenuItem(value: 'trade_idea', child: Text('Trade Idea')),
                          DropdownMenuItem(value: 'journal', child: Text('Journal')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _category = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyController,
                  minLines: 10,
                  maxLines: 18,
                  style: ThemeAType.body(color: p.textDark, size: 15),
                  decoration: InputDecoration(
                    hintText:
                        'Write your research, entry/exit plan, risk notes, or daily market reflections…',
                    hintStyle: ThemeAType.body(color: p.textMuted),
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: p.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
