import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/current_user_provider.dart';

class ActiveUnlock {
  const ActiveUnlock({
    required this.documentId,
    required this.claimId,
    required this.key,
    required this.expiresAt,
    required this.content,
  });

  final String documentId;
  final String claimId;
  final String key;
  final DateTime expiresAt;
  final String content;

  bool isValidAt(DateTime now) => now.isBefore(expiresAt);

  Map<String, String> toChatJson() => {
    'document_id': documentId,
    'claim_id': claimId,
    'key': key,
  };
}

final unlockSessionProvider =
    NotifierProvider<UnlockSession, Map<String, ActiveUnlock>>(
      UnlockSession.new,
    );

/// Memory only, shared with chat across navigation. The server remains the
/// authority on expiry; local expiry also removes plaintext from the view.
class UnlockSession extends Notifier<Map<String, ActiveUnlock>>
    with WidgetsBindingObserver {
  Timer? _timer;
  String? _userId;
  int _nextOperation = 0;
  final Map<String, int> _pending = {};

  @override
  Map<String, ActiveUnlock> build() {
    _userId = ref.watch(currentUserIdProvider);
    _timer?.cancel();
    _timer = null;
    _pending.clear();
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _timer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    return {};
  }

  int beginUnlock(String documentId) {
    final operation = ++_nextOperation;
    _pending[documentId] = operation;
    return operation;
  }

  bool remember(ActiveUnlock unlock, {int? operation}) {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null ||
        currentUserId != _userId ||
        !unlock.isValidAt(DateTime.now()) ||
        (operation != null && _pending[unlock.documentId] != operation)) {
      return false;
    }
    _pending.remove(unlock.documentId);
    state = {...state, unlock.documentId: unlock};
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => expire());
    return true;
  }

  void forget(String documentId) {
    _pending.remove(documentId);
    state = {...state}..remove(documentId);
    _stopIfEmpty();
  }

  void expire([DateTime? now]) {
    final instant = now ?? DateTime.now();
    for (final unlock in state.values) {
      if (!unlock.isValidAt(instant)) _pending.remove(unlock.documentId);
    }
    // Publish each second while unlocked so the view's countdown advances.
    state = Map.fromEntries(
      state.entries.where((entry) => entry.value.isValidAt(instant)),
    );
    _stopIfEmpty();
  }

  List<Map<String, String>> activeForChat() {
    expire();
    return state.values.map((unlock) => unlock.toChatJson()).toList();
  }

  void _stopIfEmpty() {
    if (state.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) expire();
  }
}
