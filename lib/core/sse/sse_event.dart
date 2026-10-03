/// One dispatched Server-Sent Event: the fields the wire format defines,
/// after the parsing rules in the WHATWG HTML spec §9.2 ("Server-sent
/// events") have been applied.
final class SseEvent {
  const SseEvent({
    required this.event,
    required this.data,
    this.id,
    this.retry,
  });

  /// The `event:` field, or `message` when the stream didn't name one.
  final String event;

  /// The `data:` lines joined with `\n` (no trailing newline).
  final String data;

  /// The last `id:` seen on the stream so far (it persists across events,
  /// as the spec's "last event ID buffer" does).
  final String? id;

  /// A `retry:` reconnection hint in milliseconds, if this event carried one.
  final int? retry;

  @override
  String toString() => 'SseEvent($event, $data)';

  @override
  bool operator ==(Object other) =>
      other is SseEvent &&
      other.event == event &&
      other.data == data &&
      other.id == id &&
      other.retry == retry;

  @override
  int get hashCode => Object.hash(event, data, id, retry);
}
