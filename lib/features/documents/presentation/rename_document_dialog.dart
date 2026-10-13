import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/document_actions_api.dart';
import '../data/document_actions_controller.dart';

/// Asks for a new name and saves it. Resolves to `true` once renamed, `false`
/// if the user cancelled (or left it unchanged).
Future<bool> showRenameDocumentDialog(
  BuildContext context, {
  required String documentId,
  required String currentTitle,
}) async {
  final renamed = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _RenameDialog(documentId: documentId, currentTitle: currentTitle),
  );
  return renamed == true;
}

class _RenameDialog extends ConsumerStatefulWidget {
  const _RenameDialog({required this.documentId, required this.currentTitle});

  final String documentId;
  final String currentTitle;

  @override
  ConsumerState<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends ConsumerState<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.currentTitle);
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Select the whole name so typing replaces it.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.currentTitle.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final title = _controller.text;
    final problem = validateDocumentTitle(title);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (title.trim() == widget.currentTitle.trim()) {
      Navigator.of(context).pop(false); // nothing changed, nothing to send
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(documentActionsProvider).rename(widget.documentId, title);
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "Couldn't rename this document. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            key: const Key('rename_field'),
            label: 'Name',
            controller: _controller,
            enabled: !_busy,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            errorText: _error,
          ),
          if (_busy) ...[
            const SizedBox(height: AppSpacing.s3),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Only the name changes; the content stays as it is.',
            style: AppTypography.xs.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('rename_cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('rename_save'),
          onPressed: _busy ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
