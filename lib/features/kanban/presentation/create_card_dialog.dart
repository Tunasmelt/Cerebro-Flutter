import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/widgets/app_form_field.dart';
import '../../../shared/widgets/error_view.dart';
import '../../auth/data/current_user_provider.dart';
import '../../documents/data/documents_list_notifier.dart';
import '../data/kanban_controller.dart';

class CreateCardDialog extends ConsumerStatefulWidget {
  const CreateCardDialog({super.key, required this.column});
  final String column;
  @override
  ConsumerState<CreateCardDialog> createState() => _CreateCardDialogState();
}

class _CreateCardDialogState extends ConsumerState<CreateCardDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late String _column;
  String? _document;
  String? _owner;
  @override
  void initState() {
    super.initState();
    _column = widget.column;
    _owner = ref.read(currentUserIdProvider);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() ||
        ref.read(currentUserIdProvider) != _owner) {
      return;
    }
    final saved = await ref
        .read(kanbanControllerProvider.notifier)
        .create(_column, _title.text, _description.text, _document);
    if (saved && mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(currentUserIdProvider);
    ref.listen(currentUserIdProvider, (_, next) {
      if (next != _owner && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    });
    final state = ref.watch(kanbanControllerProvider);
    final docs = ref.watch(documentsListProvider);
    if (owner != _owner || state.board == null) {
      return const SizedBox.shrink();
    }
    final documents = docs.valueOrNull ?? [];
    final documentAvailable =
        _document == null || documents.any((doc) => doc.id == _document);
    final busy = state.saving || state.loading || owner != _owner;
    return AlertDialog(
      title: const Text('Create card'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppFormField(
                    label: 'Title',
                    child: TextFormField(
                      key: const Key('kanban_title'),
                      controller: _title,
                      enabled: !busy,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a title.'
                          : null,
                    ),
                  ),
                  AppFormField(
                    label: 'Description (optional)',
                    child: TextFormField(
                      key: const Key('kanban_description'),
                      controller: _description,
                      enabled: !busy,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ),
                  AppFormField(
                    label: 'Column',
                    child: DropdownButtonFormField<String>(
                      initialValue: state.board!.columns.contains(_column)
                          ? _column
                          : null,
                      validator: (value) => state.board!.columns.contains(value)
                          ? null
                          : 'Choose a column.',
                      isExpanded: true,
                      items: [
                        for (final column in state.board?.columns ?? <String>[])
                          DropdownMenuItem(value: column, child: Text(column)),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => _column = value!),
                    ),
                  ),
                  if (docs.isLoading) const LinearProgressIndicator(),
                  if (docs.hasError)
                    ErrorView(
                      exception: docs.error is AppException
                          ? docs.error! as AppException
                          : const UnknownApiException(
                              'Could not load documents.',
                            ),
                      onRetry: () =>
                          ref.read(documentsListProvider.notifier).refresh(),
                    ),
                  AppFormField(
                    key: const Key('kanban_document'),
                    label: 'Document (optional)',
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        documentAvailable ? _document : 'unavailable',
                      ),
                      initialValue: documentAvailable ? _document : null,
                      validator: (_) => documentAvailable
                          ? null
                          : 'Choose an available document.',
                      isExpanded: true,
                      hint: const Text('No linked document'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('No linked document'),
                        ),
                        for (final doc in documents)
                          DropdownMenuItem(
                            value: doc.id,
                            child: Text(
                              doc.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: busy || docs.isLoading || docs.hasError
                          ? null
                          : (value) => setState(
                              () => _document = value == '' ? null : value,
                            ),
                    ),
                  ),
                  if (state.error != null) ErrorView(exception: state.error!),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('kanban_save'),
          onPressed: busy ? null : _save,
          child: Text(state.saving ? 'Saving…' : 'Create'),
        ),
      ],
    );
  }
}
