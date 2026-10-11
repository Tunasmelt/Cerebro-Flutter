import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/upload/storage_uploader.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void _background(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void _resume(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  testWidgets('production retry waits until the app resumes', (tester) async {
    final container = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWithValue('owner')],
    );
    addTearDown(container.dispose);
    final storage =
        container.read(storageUploaderProvider) as DioStorageUploader;
    _background(tester);
    var finished = false;
    final retry = storage.retryAfterBackground!().then((allowed) {
      finished = true;
      return allowed;
    });
    await tester.pump();
    expect(finished, isFalse);
    _resume(tester);
    expect(await retry, isTrue);
  });

  testWidgets('foreground failures do not wait or automatically retry', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWithValue('owner')],
    );
    addTearDown(container.dispose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final storage =
        container.read(storageUploaderProvider) as DioStorageUploader;
    expect(await storage.retryAfterBackground!(), isFalse);
  });

  testWidgets(
    'disposal cancels a pending resume and denies old-session writes',
    (tester) async {
      final container = ProviderContainer(
        overrides: [currentUserIdProvider.overrideWithValue('owner')],
      );
      final storage =
          container.read(storageUploaderProvider) as DioStorageUploader;
      _background(tester);
      final retry = storage.retryAfterBackground!();
      container.dispose();
      expect(await retry, isFalse);
      expect(storage.canContinue!(), isFalse);
      _resume(tester);
    },
  );

  testWidgets("an account switch cancels the old user's pending retry", (
    tester,
  ) async {
    final identity = StateProvider<String?>((_) => 'owner');
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(identity)),
      ],
    );
    addTearDown(container.dispose);
    final storage =
        container.read(storageUploaderProvider) as DioStorageUploader;
    _background(tester);
    final retry = storage.retryAfterBackground!();
    container.read(identity.notifier).state = 'other';
    _resume(tester);
    await tester.pump();
    expect(await retry, isFalse);
    expect(storage.canContinue!(), isFalse);
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
