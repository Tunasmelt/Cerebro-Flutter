import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How often an in-progress document is re-checked. The backend exposes
/// ingest progress only by polling `GET /documents[/{id}]` (its planned
/// SSE push was dropped — api-documentation.md, Stage 3.6).
final ingestPollIntervalProvider = Provider<Duration>(
  (_) => const Duration(seconds: 3),
);

/// Upper bound on how long one screen keeps polling, so a job the server
/// never finishes can't poll forever. Pull-to-refresh or reopening starts
/// a fresh window.
final ingestPollLimitProvider = Provider<Duration>(
  (_) => const Duration(minutes: 10),
);

/// Polls allowed within [limit] at [interval] (at least one).
int maxPolls(Duration interval, Duration limit) {
  if (interval <= Duration.zero) return 1;
  final n = limit.inMicroseconds ~/ interval.inMicroseconds;
  return n < 1 ? 1 : n;
}
