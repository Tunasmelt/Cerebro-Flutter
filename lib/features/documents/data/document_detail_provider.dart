import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/current_user_provider.dart';
import 'document.dart';
import 'documents_repository_provider.dart';
import 'ingest_polling.dart';
import 'ingest_status.dart';

/// Nothing more will change without the user doing something.
bool isIngestSettled(DocumentDetail d) =>
    d.status != DocumentStatus.processing ||
    IngestStage.fromApi(d.ingestState).isTerminal;

/// True once the poll window ran out while the document was still being
/// processed — the screen then says so instead of silently freezing on the
/// last stage. Reset every time polling restarts.
final ingestPollGaveUpProvider = StateProvider.autoDispose.family<bool, String>(
  (ref, documentId) => false,
);

/// A document's detail, re-fetched every few seconds until its ingest
/// reaches `ready`/`failed` (or the poll window runs out), so the screen
/// shows the real stage advancing. Stops the moment nobody is watching.
///
/// A failure on the first fetch is the stream's error (the screen shows
/// it with Retry); a failure on a later poll is ignored — a dropped
/// connection mid-ingest keeps showing the last known state and tries
/// again rather than replacing it with an error.
final documentDetailProvider = StreamProvider.autoDispose
    .family<DocumentDetail, String>((ref, documentId) {
      // Watched so a cached detail never outlives the user it belongs to.
      ref.watch(currentUserIdProvider);
      final repository = ref.read(documentsRepositoryProvider);
      final interval = ref.watch(ingestPollIntervalProvider);
      final budget = maxPolls(interval, ref.watch(ingestPollLimitProvider));

      final controller = StreamController<DocumentDetail>();
      Timer? timer;
      var alive = true;
      var polls = 0;
      // Fresh window, fresh state (also on Retry / "Check again").
      Future.microtask(() {
        if (!alive) return;
        ref.read(ingestPollGaveUpProvider(documentId).notifier).state = false;
      });
      ref.onDispose(() {
        alive = false;
        timer?.cancel();
        controller.close();
      });

      Future<void> poll() async {
        polls++;
        final first = polls == 1;
        try {
          final detail = await repository.getDocument(documentId);
          if (!alive) return;
          controller.add(detail);
          if (isIngestSettled(detail)) return controller.close();
        } catch (error, stack) {
          if (!alive) return;
          if (first) {
            controller.addError(error, stack);
            return controller.close();
          }
        }
        if (polls >= budget) {
          ref.read(ingestPollGaveUpProvider(documentId).notifier).state = true;
          return controller.close();
        }
        timer = Timer(interval, poll);
      }

      poll();
      return controller.stream;
    });
