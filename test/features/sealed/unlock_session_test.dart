import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/sealed/data/unlock_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ActiveUnlock claim(DateTime expiry, {String documentId = 'doc'}) =>
    ActiveUnlock(
      documentId: documentId,
      claimId: 'claim',
      key: 'test-key',
      expiresAt: expiry,
      content: 'private content',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'account switch rejects pending response before session is read again',
    () {
      final user = StateProvider<String?>((ref) => 'one');
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(user)),
        ],
      );
      addTearDown(container.dispose);
      final session = container.read(unlockSessionProvider.notifier);
      final pending = session.beginUnlock('doc');
      container.read(user.notifier).state = 'two';
      expect(
        session.remember(
          claim(DateTime.now().add(const Duration(minutes: 15))),
          operation: pending,
        ),
        isFalse,
      );
      expect(container.read(unlockSessionProvider), isEmpty);
    },
  );

  test('signed-out responses and already expired responses are rejected', () {
    final user = StateProvider<String?>((ref) => 'one');
    final container = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWith((ref) => ref.watch(user))],
    );
    addTearDown(container.dispose);
    final session = container.read(unlockSessionProvider.notifier);
    final pending = session.beginUnlock('doc');
    expect(
      session.remember(claim(DateTime.now()), operation: pending),
      isFalse,
    );
    container.read(user.notifier).state = null;
    expect(
      session.remember(
        claim(DateTime.now().add(const Duration(minutes: 15))),
        operation: pending,
      ),
      isFalse,
    );
    container.read(user.notifier).state = 'one';
    container.read(unlockSessionProvider);
    expect(
      session.remember(
        claim(DateTime.now().add(const Duration(minutes: 15))),
        operation: pending,
      ),
      isFalse,
    );
    expect(container.read(unlockSessionProvider), isEmpty);
  });

  test(
    'multiple documents expire and lock independently; timer restarts',
    () async {
      final container = ProviderContainer(
        overrides: [currentUserIdProvider.overrideWithValue('one')],
      );
      addTearDown(container.dispose);
      final session = container.read(unlockSessionProvider.notifier);
      final early = DateTime.now().add(const Duration(minutes: 1));
      final later = early.add(const Duration(minutes: 1));
      session.remember(claim(early, documentId: 'early'));
      session.remember(claim(later, documentId: 'later'));
      final otherPending = session.beginUnlock('pending');
      session.expire(early);
      expect(container.read(unlockSessionProvider).keys, ['later']);
      expect(
        session.remember(
          claim(later, documentId: 'pending'),
          operation: otherPending,
        ),
        isTrue,
      );
      session.forget('later');
      expect(session.activeForChat().single['document_id'], 'pending');
      session.forget('pending');
      session.remember(
        claim(DateTime.now().add(const Duration(milliseconds: 30))),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(container.read(unlockSessionProvider), isEmpty);
    },
  );

  test(
    'dispose cancels active expiry timer and removes lifecycle observer',
    () async {
      final container = ProviderContainer(
        overrides: [currentUserIdProvider.overrideWithValue('one')],
      );
      container
          .read(unlockSessionProvider.notifier)
          .remember(
            claim(DateTime.now().add(const Duration(milliseconds: 30))),
          );
      container.dispose();
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      // An uncancelled timer/observer writes to disposed provider and fails this test.
    },
  );

  test('claim is valid immediately before expiry and expired at/after it', () {
    final issued = DateTime.utc(2026, 10, 11);
    final expiry = issued.add(const Duration(minutes: 15));
    final unlock = claim(expiry);
    expect(
      unlock.isValidAt(expiry.subtract(const Duration(microseconds: 1))),
      isTrue,
    );
    expect(unlock.isValidAt(expiry), isFalse);
    expect(
      unlock.isValidAt(expiry.add(const Duration(microseconds: 1))),
      isFalse,
    );
  });

  test('expired claims lose content/key and never enter chat payloads', () {
    final container = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWithValue('one')],
    );
    addTearDown(container.dispose);
    final session = container.read(unlockSessionProvider.notifier);
    final expiry = DateTime.now().add(const Duration(minutes: 15));
    session.remember(claim(expiry));
    expect(session.activeForChat(), [
      {'document_id': 'doc', 'claim_id': 'claim', 'key': 'test-key'},
    ]);
    session.expire(expiry);
    expect(container.read(unlockSessionProvider), isEmpty);
    expect(session.activeForChat(), isEmpty);
  });

  test(
    'user change clears claims; the next user gets a working timer',
    () async {
      final user = StateProvider<String?>((ref) => 'one');
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(user)),
        ],
      );
      addTearDown(container.dispose);
      final session = container.read(unlockSessionProvider.notifier);
      session.remember(claim(DateTime.now().add(const Duration(minutes: 15))));
      container.read(user.notifier).state = null;
      expect(container.read(unlockSessionProvider), isEmpty);
      container.read(user.notifier).state = 'two';
      container.read(unlockSessionProvider);
      session.remember(
        claim(DateTime.now().add(const Duration(milliseconds: 30))),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(container.read(unlockSessionProvider), isEmpty);
    },
  );

  test('resume drops expired claims without restarting the app', () async {
    final container = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWithValue('one')],
    );
    addTearDown(container.dispose);
    final session = container.read(unlockSessionProvider.notifier);
    session.remember(
      claim(DateTime.now().add(const Duration(milliseconds: 1))),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    session.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(container.read(unlockSessionProvider), isEmpty);
  });

  test(
    'only the newest pending unlock can commit; lock also cancels pending work',
    () {
      final container = ProviderContainer(
        overrides: [currentUserIdProvider.overrideWithValue('one')],
      );
      addTearDown(container.dispose);
      final session = container.read(unlockSessionProvider.notifier);
      final first = session.beginUnlock('doc');
      final second = session.beginUnlock('doc');
      final unlock = claim(DateTime.now().add(const Duration(minutes: 15)));
      expect(session.remember(unlock, operation: first), isFalse);
      expect(session.remember(unlock, operation: second), isTrue);
      session.forget('doc');
      expect(session.remember(unlock, operation: second), isFalse);
      final third = session.beginUnlock('doc');
      session.forget('doc');
      expect(session.remember(unlock, operation: third), isFalse);
      expect(container.read(unlockSessionProvider), isEmpty);
    },
  );
}
