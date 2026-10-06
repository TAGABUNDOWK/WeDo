import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/event.dart';
import '../../../services/event/event_service.dart';
import '../../../utils/constants.dart';
import 'event_detail_screen.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Groups [events] by local calendar day.
///
/// Every event is indexed under each day it spans (start day through
/// [ChatEvent.endDate], or just the start day when it has no end), so a day
/// can hold many events and a multi-day event appears on every covered day.
/// Each day's list is sorted by start time. The loop is capped at a year so
/// corrupt data (end far before start) can never spin.
Map<DateTime, List<ChatEvent>> buildEventDayIndex(Iterable<ChatEvent> events) {
  final index = <DateTime, List<ChatEvent>>{};
  for (final event in events) {
    final start = _dateOnly(event.date);
    final endDate = event.endDate;
    final end = endDate != null && endDate.isAfter(event.date)
        ? _dateOnly(endDate)
        : start;

    var day = start;
    var guard = 0;
    while (!day.isAfter(end) && guard < 366) {
      index.putIfAbsent(day, () => []).add(event);
      day = DateTime(day.year, day.month, day.day + 1);
      guard++;
    }
  }
  for (final list in index.values) {
    list.sort((a, b) => a.date.compareTo(b.date));
  }
  return index;
}

/// Calendar view of one chat's events: a tappable month grid with per-day
/// event dots, and a list of the selected day's events below it.
class EventCalendarScreen extends StatefulWidget {
  final String? groupId;
  final String? chatId;

  const EventCalendarScreen({super.key, this.groupId, this.chatId});

  @override
  State<EventCalendarScreen> createState() => _EventCalendarScreenState();
}

class _EventCalendarScreenState extends State<EventCalendarScreen> {
  final _eventService = EventService();

  late Stream<List<ChatEvent>> _eventsStream;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _eventsStream = _newStream();
  }

  Stream<List<ChatEvent>> _newStream() => _eventService.getEventsStream(
        chatId: widget.chatId,
        groupId: widget.groupId,
      );

  void _retryStream() {
    setState(() => _eventsStream = _newStream());
  }

  void _selectDay(DateTime day) {
    setState(() => _selectedDay = _dateOnly(day));
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Event Calendar',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: widget.groupId == null && widget.chatId == null
          ? _message(
              icon: Icons.link_off,
              title: 'No chat selected',
              subtitle: 'This calendar is not linked to a chat.',
            )
          : StreamBuilder<List<ChatEvent>>(
              stream: _eventsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _message(
                    icon: Icons.error_outline,
                    title: 'Something went wrong',
                    subtitle: 'Events could not be loaded.',
                    actionLabel: 'Retry',
                    onAction: _retryStream,
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.lavenderAccent,
                    ),
                  );
                }
                return _buildView(snapshot.data ?? const <ChatEvent>[]);
              },
            ),
    );
  }

  Widget _buildView(List<ChatEvent> events) {
    final index = buildEventDayIndex(events);
    final dayEvents = index[_selectedDay] ?? const <ChatEvent>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MonthCalendar(
            focusedMonth: _focusedMonth,
            selectedDay: _selectedDay,
            dayIndex: index,
            onPrevMonth: () => _changeMonth(-1),
            onNextMonth: () => _changeMonth(1),
            onDayTap: _selectDay,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDayHeading(_selectedDay),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                dayEvents.isEmpty
                    ? 'No events'
                    : '${dayEvents.length} ${dayEvents.length == 1 ? 'event' : 'events'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: dayEvents.isEmpty
                ? _message(
                    icon: Icons.event_busy,
                    title: 'No events on this day',
                    subtitle: 'Pick another day to see its events.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: dayEvents.length,
                    itemBuilder: (context, i) => _EventDayTile(
                      event: dayEvents[i],
                      onTap: () => _openDetails(dayEvents[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _openDetails(ChatEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventId: event.id,
          groupId: event.groupId ?? widget.groupId,
          chatId: event.chatId ?? widget.chatId,
        ),
      ),
    );
  }

  String _formatDayHeading(DateTime day) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[day.month - 1]} ${day.day}, ${day.year}';
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: AppColors.lavenderAccent.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: AppColors.lavenderAccent,
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final Map<DateTime, List<ChatEvent>> dayIndex;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDayTap;

  const _MonthCalendar({
    required this.focusedMonth,
    required this.selectedDay,
    required this.dayIndex,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onDayTap,
  });

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final leadingBlanks = first.weekday % 7; // weeks start Sunday

    final cells = <DateTime?>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(null);
    }
    for (var day = 1; day <= daysInMonth; day++) {
      cells.add(DateTime(focusedMonth.year, focusedMonth.month, day));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final rows = <List<DateTime?>>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(cells.sublist(i, i + 7));
    }

    final now = DateTime.now();
    final today = _dateOnly(now);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left,
                    color: AppColors.textSecondary, size: 26),
                onPressed: onPrevMonth,
              ),
              Expanded(
                child: Text(
                  '${_monthNames[focusedMonth.month - 1]} ${focusedMonth.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 26),
                onPressed: onNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final row in rows)
            Row(
              children: [
                for (final day in row)
                  Expanded(
                    child: day == null
                        ? const SizedBox(height: 46)
                        : _DayCell(
                            day: day,
                            isSelected: day == selectedDay,
                            isToday: day == today,
                            eventCount: dayIndex[day]?.length ?? 0,
                            onTap: () => onDayTap(day),
                          ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final int eventCount;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.eventCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color numberColor;
    FontWeight weight = FontWeight.w500;
    if (isSelected) {
      numberColor = AppColors.midnightBg;
      weight = FontWeight.w700;
    } else if (isToday) {
      numberColor = AppColors.lavenderAccent;
      weight = FontWeight.w700;
    } else {
      numberColor = AppColors.textPrimary;
    }

    final dots = eventCount > 3 ? 3 : eventCount;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 46,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: isSelected
                  ? const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.lavenderAccent,
                    )
                  : null,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: numberColor,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: weight,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < dots; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.midnightBg
                            : AppColors.lavenderAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDayTile extends StatelessWidget {
  final ChatEvent event;
  final VoidCallback onTap;

  const _EventDayTile({required this.event, required this.onTap});

  String get _timeLabel {
    final date = event.date;
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final location =
        event.location != null && event.location!.isNotEmpty
            ? event.location
            : event.address;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.lavenderAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _timeLabel,
                style: const TextStyle(
                  color: AppColors.lavenderAccent,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (location != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (event.interestedCount > 0) ...[
              const Icon(Icons.check_circle,
                  size: 14, color: Colors.green),
              const SizedBox(width: 3),
              Text(
                '${event.interestedCount}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
