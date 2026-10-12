import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
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
  bool _reveal = false;
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
    final remaining = unlock?.expiresAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 900);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: AppColors.accentLockedSubtle,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(
            color: AppColors.accentLocked.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  unlock != null ? Icons.lock_open : Icons.lock_outline,
                  color: AppColors.accentLocked,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    unlock != null
                        ? 'Unlocked'
                        : sealing
                        ? 'Seal this document'
                        : 'Sealed',
                    style: AppTypography.base.copyWith(
                      color: AppColors.accentLocked,
                      fontWeight: AppTypography.weightSemibold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            if (unlock != null) ...[
              Text(
                'Unlocked · ${remaining! ~/ 60}m ${remaining % 60}s remaining',
                key: const Key('sealed_countdown'),
                style: AppTypography.mono(
                  AppTypography.sm,
                ).copyWith(color: AppColors.accentLocked),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                'Available in chat until this unlock expires. Content stays '
                'in memory.',
                style: AppTypography.sm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s3),
                decoration: BoxDecoration(
                  color: AppColors.bgBase,
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  unlock.content,
                  key: const Key('sealed_content'),
                  style: AppTypography.sm.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              SizedBox(
                width: double.infinity,
                height: AppSpacing.minTouchTarget,
                child: OutlinedButton.icon(
                  key: const Key('sealed_lock'),
                  onPressed: () => ref
                      .read(unlockSessionProvider.notifier)
                      .forget(widget.documentId),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Lock now'),
                ),
              ),
            ] else if (!_prompt) ...[
              Text(
                sealing
                    ? 'Sealing removes this document’s content from search. '
                          'You choose a passphrase to open it again.'
                    : 'Its content is hidden from search and chat until you '
                          'unlock it with your passphrase.',
                style: AppTypography.sm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              SizedBox(
                width: double.infinity,
                height: AppSpacing.minTouchTarget,
                child: OutlinedButton.icon(
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
              ),
            ] else ...[
              Text(
                sealing
                    ? 'Sealing removes this document’s content from search. Keep your passphrase: it cannot be recovered.'
                    : 'Unlock for up to 15 minutes with the passphrase used to seal this document.',
                style: AppTypography.sm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              TextField(
                key: const Key('sealed_passphrase'),
                controller: _password,
                enabled: !_busy,
                obscureText: !_reveal,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                textInputAction: TextInputAction.done,
                style: AppTypography.sm.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Passphrase',
                  suffixIcon: IconButton(
                    key: const Key('sealed_reveal'),
                    tooltip: _reveal ? 'Hide passphrase' : 'Show passphrase',
                    icon: Icon(
                      _reveal
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _reveal = !_reveal),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s3),
                Semantics(
                  liveRegion: true,
                  container: true,
                  child: Container(
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
                      key: const Key('sealed_error'),
                      style: AppTypography.xs.copyWith(
                        color: AppColors.dangerHover,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s3),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: AppSpacing.minTouchTarget,
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _prompt = false;
                                _reveal = false;
                                _password.clear();
                                _error = null;
                              }),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: AppSpacing.minTouchTarget,
                      child: FilledButton(
                        key: const Key('sealed_confirm'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentLocked,
                          foregroundColor: AppColors.textOnAccent,
                        ),
                        onPressed: _busy || _password.text.isEmpty
                            ? null
                            : _submit,
                        child: Text(
                          _busy
                              ? 'Working…'
                              : sealing
                              ? 'Confirm seal'
                              : 'Unlock',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
