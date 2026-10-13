import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_exception.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/document_actions_api.dart';
import '../data/document_actions_controller.dart';

/// Write a note and keep it: it is saved as a document of its own, runs through
/// the same processing as an upload, and is then searchable and citable in
/// chat like any other. Pops with `true` once saved.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  bool _saving = false;
  bool _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _text.text.trim().isNotEmpty || _title.text.trim().isNotEmpty;

  int get _length => _text.text.trim().runes.length;

  bool get _canSave => !_saving && validateNoteText(_text.text) == null;

  Future<void> _save() async {
    if (!_canSave) return;
    final owner = ref.read(currentUserIdProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(documentActionsProvider)
          .createNote(text: _text.text, title: _title.text);
      if (!mounted || ref.read(currentUserIdProvider) != owner) return;
      _saved = true;
      context.pop(true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save this note. Your text is still here; try again.";
      });
    }
  }

  Future<void> _confirmLeave() async {
    final discard = await showAppConfirmDialog(
      context,
      title: 'Discard this note?',
      message: "What you've written hasn't been saved.",
      confirmLabel: 'Discard',
      cancelLabel: 'Keep writing',
      destructive: true,
      confirmKey: const Key('note_discard_confirm'),
      cancelKey: const Key('note_discard_cancel'),
    );
    if (discard && mounted) context.pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final over = _length > maxNoteChars;
    return PopScope(
      // Leaving with unsaved text asks first; an empty or saved note just goes.
      canPop: !_hasContent || _saved || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
          title: const Text('New note'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s2),
              child: TextButton(
                key: const Key('note_save'),
                onPressed: _canSave ? _save : null,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  key: const Key('note_title'),
                  label: 'Title (optional)',
                  controller: _title,
                  enabled: !_saving,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.s4),
                Expanded(
                  child: TextField(
                    key: const Key('note_text'),
                    controller: _text,
                    enabled: !_saving,
                    autofocus: true,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTypography.base.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Write your note…',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Saved to Documents and searchable in chat.',
                        style: AppTypography.xs.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '$_length / $maxNoteChars',
                      key: const Key('note_counter'),
                      style: AppTypography.mono(AppTypography.xs).copyWith(
                        color: over
                            ? AppColors.danger
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.s2),
                  Semantics(
                    liveRegion: true,
                    container: true,
                    child: Container(
                      key: const Key('note_error'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s3,
                        vertical: AppSpacing.s2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dangerSubtle,
                        borderRadius: AppRadius.mdRadius,
                      ),
                      child: Text(
                        _error!,
                        style: AppTypography.xs.copyWith(
                          color: AppColors.dangerHover,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
