import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../auth/data/current_user_provider.dart';
import '../../documents/data/document.dart';
import '../../documents/data/document_detail_provider.dart';
import '../../documents/data/documents_list_notifier.dart';
import '../data/sealed_document_api.dart';
import '../data/unlock_session.dart';

class SealedDocumentControls extends ConsumerStatefulWidget {
  const SealedDocumentControls({
    super.key,
    required this.documentId,
    required this.status,
  });
  final String documentId;
  final DocumentStatus status;

  @override
  ConsumerState<SealedDocumentControls> createState() => _ControlsState();
}

class _ControlsState extends ConsumerState<SealedDocumentControls> {
  final _password = TextEditingController();
  bool _prompt = false;
  bool _busy = false;
  String? _error;
  int _generation = 0;

  @override
  void didUpdateWidget(SealedDocumentControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      _generation++;
      _password.clear();
      _prompt = false;
      _busy = false;
      _error = null;
    }
  }

  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _password.text.isEmpty) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final generation = _generation;
    final documentId = widget.documentId;
    final container = ProviderScope.containerOf(context, listen: false);
    final api = ref.read(sealedDocumentApiProvider);
    final passphrase = _password.text;
    _password.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final sealing = widget.status == DocumentStatus.ready;
    try {
      if (sealing) {
        await api.seal(documentId, passphrase);
        // Sealing can finish after navigation. Refresh the owner's list even
        // when this widget has gone away; never touch another user's state.
        if (container.read(currentUserIdProvider) == userId) {
          container.invalidate(documentDetailProvider(documentId));
          container.invalidate(documentsListProvider);
        }
      } else {
        final operation = ref
            .read(unlockSessionProvider.notifier)
            .beginUnlock(documentId);
        final unlock = await api.unlock(documentId, passphrase);
        if (!mounted ||
            generation != _generation ||
            ref.read(currentUserIdProvider) != userId) {
          return;
        }
        if (!ref
            .read(unlockSessionProvider.notifier)
            .remember(unlock, operation: operation)) {
          throw StateError('Unlock superseded');
        }
      }
      if (!mounted ||
          generation != _generation ||
          ref.read(currentUserIdProvider) != userId) {
        return;
      }
      setState(() => _prompt = false);
    } catch (_) {
      if (mounted &&
          generation == _generation &&
          ref.read(currentUserIdProvider) == userId) {
        setState(
          () => _error = sealing
              ? "Couldn't seal this document. Try again."
              : "Couldn't unlock this document. Try again.",
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserIdProvider, (previous, next) {
      if (previous == next) return;
      _generation++;
      _password.clear();
      setState(() {
        _prompt = false;
        _busy = false;
        _error = null;
      });
    });
    final session = ref.watch(unlockSessionProvider)[widget.documentId];
    final unlock = session != null && session.isValidAt(DateTime.now())
        ? session
        : null;
    final sealing = widget.status == DocumentStatus.ready;
    if (!sealing && widget.status != DocumentStatus.sealed) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (unlock != null) ...[
          Text(
            'Unlocked · ${unlock.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 900) ~/ 60}m '
            '${unlock.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 900) % 60}s remaining',
            key: const Key('sealed_countdown'),
            style: const TextStyle(color: AppColors.accentLocked),
          ),
          const Text(
            'Available in chat until this unlock expires. Content stays in memory.',
          ),
          TextButton.icon(
            key: const Key('sealed_lock'),
            onPressed: () => ref
                .read(unlockSessionProvider.notifier)
                .forget(widget.documentId),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Lock now'),
          ),
          Text(unlock.content, key: const Key('sealed_content')),
        ] else if (!_prompt) ...[
          OutlinedButton.icon(
            key: const Key('sealed_open_prompt'),
            onPressed: () => setState(() {
              _prompt = true;
              _error = null;
            }),
            icon: Icon(
              sealing ? Icons.lock_outline : Icons.lock_open,
              color: AppColors.accentLocked,
            ),
            label: Text(sealing ? 'Seal document' : 'Unlock document'),
          ),
        ] else ...[
          Text(
            sealing
                ? 'Sealing removes this document’s content from search. Keep your passphrase: it cannot be recovered.'
                : 'Unlock for up to 15 minutes with the passphrase used to seal this document.',
          ),
          TextField(
            key: const Key('sealed_passphrase'),
            controller: _password,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            decoration: const InputDecoration(labelText: 'Passphrase'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          Wrap(
            children: [
              FilledButton(
                key: const Key('sealed_confirm'),
                onPressed: _busy || _password.text.isEmpty ? null : _submit,
                child: Text(
                  _busy
                      ? 'Working…'
                      : sealing
                      ? 'Confirm seal'
                      : 'Unlock',
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _prompt = false;
                        _password.clear();
                        _error = null;
                      }),
                child: const Text('Cancel'),
              ),
            ],
          ),
          if (_error != null) Text(_error!, key: const Key('sealed_error')),
        ],
      ],
    );
  }
}
