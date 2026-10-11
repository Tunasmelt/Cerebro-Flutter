import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/error_view.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/playground_api.dart';
import 'widgets/playground_stat_tile.dart';

class PlaygroundScreen extends ConsumerStatefulWidget {
  const PlaygroundScreen({super.key});
  @override
  ConsumerState<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends ConsumerState<PlaygroundScreen> {
  String? _owner, _session, _message;
  Widget _loading() => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: CircularProgressIndicator(),
    ),
  );
  Widget _error(Object error, VoidCallback retry) => ErrorView(
    exception: error is AppException
        ? error
        : const UnknownApiException(
            'Could not load the token breakdown. Try again.',
          ),
    onRetry: retry,
  );
  Widget _breakdown(PromptBreakdown prompt) {
    Widget section(
      String title,
      String content,
      int tokens, [
      String? citation,
    ]) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.lg),
            Text(
              '$tokens tokens (est.)',
              style: AppTypography.mono(AppTypography.sm),
            ),
            if (citation != null) Text(citation, style: AppTypography.sm),
            const SizedBox(height: 12),
            SelectableText(
              content,
              style: AppTypography.mono(AppTypography.sm),
            ),
          ],
        ),
      ),
    );
    const titles = {
      'system_instructions': 'System instructions',
      'context': 'Context',
      'user_query': 'User query',
    };
    return Column(
      key: const Key('playground_breakdown'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          prompt.model,
          key: const Key('playground_model'),
          style: AppTypography.mono(AppTypography.base),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            PlaygroundStatTile(
              label: 'INPUT (EST.)',
              value: '${prompt.inputTokens}',
            ),
            PlaygroundStatTile(
              label: 'OUTPUT (EST.)',
              value: '${prompt.responseTokens}',
            ),
            PlaygroundStatTile(
              label: 'TOTAL (EST.)',
              value: '${prompt.totalTokens}',
            ),
            PlaygroundStatTile(
              label: 'COST (EST. USD)',
              value: '\$${prompt.cost.toStringAsFixed(6)}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Reconstructed from the saved turn. Token counts and cost are estimates; section badges exclude prompt formatting.',
        ),
        const SizedBox(height: 16),
        for (final item in prompt.sections)
          section(
            titles[item.label] ?? item.label,
            item.content,
            item.tokens,
            item.citation,
          ),
        section('Response', prompt.response, prompt.responseTokens),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(currentUserIdProvider);
    if (_owner != owner) {
      _owner = owner;
      _session = null;
      _message = null;
    }
    final sessions = ref.watch(playgroundSessionsProvider);
    final session = _session;
    return Scaffold(
      appBar: AppBar(title: const Text('Token Playground')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Read-only breakdown of a saved assistant reply.'),
          const SizedBox(height: 16),
          sessions.when(
            loading: _loading,
            error: (error, _) =>
                _error(error, () => ref.invalidate(playgroundSessionsProvider)),
            data: (items) => items.isEmpty
                ? const Text('No saved conversations. Start a chat first.')
                : DropdownButtonFormField<String>(
                    key: ValueKey(('playground_session', owner, session)),
                    initialValue: session,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Conversation',
                    ),
                    items: [
                      for (final item in items)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            item.preview ??
                                'Conversation ${item.createdAt.toLocal()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _session = value;
                      _message = null;
                    }),
                  ),
          ),
          if (session != null) ...[
            const SizedBox(height: 16),
            ref
                .watch(playgroundTurnsProvider(session))
                .when(
                  loading: _loading,
                  error: (error, _) => _error(
                    error,
                    () => ref.invalidate(playgroundTurnsProvider(session)),
                  ),
                  data: (turns) => turns.isEmpty
                      ? const Text(
                          'This conversation has no saved assistant replies.',
                        )
                      : DropdownButtonFormField<String>(
                          key: ValueKey((
                            'playground_message',
                            owner,
                            session,
                            _message,
                          )),
                          initialValue: _message,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Assistant reply',
                          ),
                          items: [
                            for (var index = 0; index < turns.length; index++)
                              DropdownMenuItem(
                                value: turns[index].id,
                                child: Text(
                                  'Reply ${index + 1}: ${turns[index].content.replaceAll('\n', ' ')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _message = value),
                        ),
                ),
            if (_message case final String message) ...[
              const SizedBox(height: 16),
              ref
                  .watch(
                    playgroundPromptProvider((
                      sessionId: session,
                      messageId: message,
                    )),
                  )
                  .when(
                    loading: _loading,
                    error: (error, _) => _error(
                      error,
                      () => ref.invalidate(
                        playgroundPromptProvider((
                          sessionId: session,
                          messageId: message,
                        )),
                      ),
                    ),
                    data: _breakdown,
                  ),
            ],
          ],
        ],
      ),
    );
  }
}
