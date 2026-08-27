import 'package:cloud_firestore/cloud_firestore.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

DateTime? _toDateTime(dynamic timestamp) {
  if (timestamp is Timestamp) return timestamp.toDate();
  if (timestamp is DateTime) return timestamp;
  return null;
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
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
  if (dt.year == now.year) return '${_monthsShort[dt.month - 1]} ${dt.day}';
  return '${_monthsShort[dt.month - 1]} ${dt.day}, ${dt.year}';
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
  if (dt.year == now.year) return '${_monthsShort[dt.month - 1]} ${dt.day}';
  return '${_monthsShort[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String formatSearchDate(dynamic timestamp) {
  final dt = _toDateTime(timestamp);
  if (dt == null) return '';
  final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final min = dt.minute.toString().padLeft(2, '0');
  return '${_monthsShort[dt.month - 1]} ${dt.day}, ${dt.year} \u2022 $hour:$min $ampm';
}

String formatDateSeparator(dynamic timestamp) {
  final dt = _toDateTime(timestamp);
  if (dt == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDate = DateTime(dt.year, dt.month, dt.day);
  if (msgDate == today) return 'Today';
  if (msgDate == today.subtract(const Duration(days: 1))) return 'Yesterday';
  if (dt.year == now.year) {
    return '${_months[dt.month - 1]} ${dt.day}';
  }
  return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String formatCallBubbleTime(dynamic timestamp) {
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
  if (msgDate == today.subtract(const Duration(days: 1))) {
    return 'Yesterday \u2022 $time';
  }
  if (dt.year == now.year) {
    return '${_monthsShort[dt.month - 1]} ${dt.day} \u2022 $time';
  }
  return '${_monthsShort[dt.month - 1]} ${dt.day}, ${dt.year} \u2022 $time';
}

String formatMonthDay(DateTime date) {
  return '${_monthsShort[date.month - 1]} ${date.day}';
}

String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String formatSeconds(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
