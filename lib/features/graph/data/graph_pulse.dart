import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/current_user_provider.dart';
import '../../chat/data/chat_message.dart';

/// How long one pulse is visible (web's `PULSE_DURATION_MS`).
const Duration pulseDuration = Duration(milliseconds: 2000);

/// The pause between the pulses of a replayed conversation: a pulse's own
/// duration plus a beat (web's `REPLAY_PULSE_INTERVAL_MS`).
const Duration replayInterval = Duration(milliseconds: 2400);

/// One retrieval, as the graph shows it: these documents light up.
///
/// [key] changes with every pulse, so the same documents pulsing twice in a
/// row (asking the same question again, replaying a conversation twice) still
/// restarts the animation.
class GraphPulse {
  const GraphPulse({required this.documentIds, required this.key});

  /// Distinct, in the order they were reported.
  final List<String> documentIds;
  final int key;
}

class GraphPulseState {
  const GraphPulseState({
    this.pulse,
    this.replaying = false,
    this.replayIndex = 0,
    this.replayTotal = 0,
  });

  final GraphPulse? pulse;

  /// A past conversation's pulses are being played back one at a time.
  final bool replaying;
  final int replayIndex;
  final int replayTotal;
}

final graphPulseProvider =
    NotifierProvider<GraphPulseController, GraphPulseState>(
      GraphPulseController.new,
    );

/// What the graph pulses, and when.
///
/// Two sources feed it: a live `retrieval` event ([trigger]) and the stored
/// retrievals of a past conversation ([replay]). The graph only reads
/// [GraphPulseState.pulse]; documents it does not know are ignored by the
/// view, not here — this reports exactly what retrieval reported.
class GraphPulseController extends Notifier<GraphPulseState> {
  int _key = 0;

  /// Bumped to cancel a replay in progress (a live pulse, a new replay, a
  /// stop, a new user).
  int _replay = 0;

  @override
  GraphPulseState build() {
    ref.watch(currentUserIdProvider);
    _replay++;
    ref.onDispose(() => _replay++);
    return const GraphPulseState();
  }

  /// A live retrieval: pulse exactly these documents. A live pulse takes over
  /// from a replay still playing. An empty retrieval pulses nothing.
  void trigger(Iterable<String> documentIds) {
    _replay++;
    final replaying = state.replaying;
    if (replaying) state = GraphPulseState(pulse: state.pulse);
    _emit(documentIds);
  }

  /// Plays [steps] back one pulse at a time, [gap] apart — a past
  /// conversation's retrievals in the order they happened. Completes when the
  /// last pulse has been given its time (or the replay was cancelled).
  Future<void> replay(
    List<List<String>> steps, {
    Duration gap = replayInterval,
  }) async {
    final run = ++_replay;
    if (steps.isEmpty) {
      state = GraphPulseState(pulse: state.pulse);
      return;
    }
    state = GraphPulseState(pulse: state.pulse, replaying: true);
    for (var index = 0; index < steps.length; index++) {
      if (run != _replay) return;
      state = GraphPulseState(
        pulse: state.pulse,
        replaying: true,
        replayIndex: index + 1,
        replayTotal: steps.length,
      );
      _emit(steps[index]);
      await Future<void>.delayed(gap);
    }
    if (run == _replay) state = GraphPulseState(pulse: state.pulse);
  }

  /// Stops a replay in progress; a pulse already showing runs out.
  void stopReplay() {
    _replay++;
    state = GraphPulseState(pulse: state.pulse);
  }

  /// Discard a conversation's replay and any visible pulse.
  void clear() {
    _replay++;
    state = const GraphPulseState();
  }

  void _emit(Iterable<String> documentIds) {
    final distinct = <String>[];
    for (final id in documentIds) {
      if (id.isNotEmpty && !distinct.contains(id)) distinct.add(id);
    }
    if (distinct.isEmpty) return;
    state = GraphPulseState(
      pulse: GraphPulse(documentIds: distinct, key: ++_key),
      replaying: state.replaying,
      replayIndex: state.replayIndex,
      replayTotal: state.replayTotal,
    );
  }
}

/// A conversation's retrievals, in the order they happened: one list of
/// document ids per answer that retrieved something. Answers that drew from
/// nothing give no pulse (nor do the user's own messages, which carry none).
List<List<String>> replaySteps(List<ChatMessage> messages) => [
  for (final m in messages)
    if (m.retrievedDocumentIds.isNotEmpty) m.retrievedDocumentIds,
];
