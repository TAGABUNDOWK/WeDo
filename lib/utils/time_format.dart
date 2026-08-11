import 'package:cloud_firestore/cloud_firestore.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

DateTime? _toDateTime(dynamic timestamp) {
  if (timestamp is Timestamp) return timestamp.toDate();
  if (timestamp is DateTime) return timestamp;
  return null;
}

String formatChatTime(dynamic timestamp) {
  final dt = _toDateTime(timestamp);
  if (dt == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDate = DateTime(dt.year, dt.month, dt.day);
  final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final min = dt.minute.toString().padLeft(2, '0');
  final time = '$hour:$min $ampm';
  if (msgDate == today) return time;
  if (dt.year == now.year) return '${_months[dt.month - 1]} ${dt.day}';
  return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String formatListTime(dynamic timestamp) {
  final dt = _toDateTime(timestamp);
  if (dt == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDate = DateTime(dt.year, dt.month, dt.day);
  if (msgDate == today) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }
  if (msgDate == today.subtract(const Duration(days: 1))) return 'Yesterday';
  if (dt.year == now.year) return '${_months[dt.month - 1]} ${dt.day}';
  return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String formatSearchDate(dynamic timestamp) {
  final dt = _toDateTime(timestamp);
  if (dt == null) return '';
  final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final min = dt.minute.toString().padLeft(2, '0');
  return '${_months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$min $ampm';
}

String formatMonthDay(DateTime date) {
  return '${_months[date.month - 1]} ${date.day}';
}
