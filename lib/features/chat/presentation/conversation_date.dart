const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Oct 3, 9:05 PM" — when a conversation began, for the history list. The
/// year is added only when it isn't [now]'s, to keep recent rows short.
String formatConversationWhen(DateTime when, {DateTime? now}) {
  final local = when.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour < 12 ? 'AM' : 'PM';
  final year = local.year == reference.year ? '' : ', ${local.year}';
  return '${_months[local.month - 1]} ${local.day}$year, $hour12:$minute $suffix';
}
