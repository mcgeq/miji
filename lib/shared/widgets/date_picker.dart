import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_field_style.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:table_calendar/table_calendar.dart';

class DateTimePicker extends StatelessWidget {
  const DateTimePicker({
    super.key,
    required this.selectedDate,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.showTime = true,
    this.label,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool showTime;
  final String? label;

  String get _formattedDate {
    final month = selectedDate.month.toString().padLeft(2, '0');
    final day = selectedDate.day.toString().padLeft(2, '0');
    if (!showTime) return '${selectedDate.year}-$month-$day';
    final hour = selectedDate.hour.toString().padLeft(2, '0');
    final minute = selectedDate.minute.toString().padLeft(2, '0');
    return '${selectedDate.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final controls = theme.controlTokens;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pickDate(context),
        borderRadius: BorderRadius.circular(radius.md),
        child: Container(
          constraints: BoxConstraints(minHeight: controls.compactFieldHeight),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: appFieldFillColor(colorScheme, enabled: true),
            borderRadius: BorderRadius.circular(radius.md),
            border: Border.all(
              color: appFieldBorderColor(colorScheme, enabled: true),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label ?? _formattedDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
      showTime: showTime,
    );
    if (picked == null) return;
    onChanged(picked);
  }
}

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  bool showTime = false,
}) {
  return showAppResponsiveDialog<DateTime>(
    context: context,
    builder: (dialogContext) => _CalendarDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      showTime: showTime,
    ),
  );
}

Future<DateTime?> showAppMonthPicker({
  required BuildContext context,
  required DateTime initialMonth,
  required DateTime firstMonth,
  required DateTime lastMonth,
}) {
  return showAppResponsiveDialog<DateTime>(
    context: context,
    builder: (dialogContext) => _MonthPickerDialog(
      initialMonth: initialMonth,
      firstMonth: firstMonth,
      lastMonth: lastMonth,
    ),
  );
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({
    required this.initialMonth,
    required this.firstMonth,
    required this.lastMonth,
  });

  final DateTime initialMonth;
  final DateTime firstMonth;
  final DateTime lastMonth;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;
  late DateTime _selectedMonth;
  late DateTime _firstMonth;
  late DateTime _lastMonth;

  @override
  void initState() {
    super.initState();
    _firstMonth = _monthOnly(widget.firstMonth);
    _lastMonth = _monthOnly(widget.lastMonth);
    _selectedMonth = _clampMonth(_monthOnly(widget.initialMonth));
    _year = _selectedMonth.year;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final canPreviousYear = _year > _firstMonth.year;
    final canNextYear = _year < _lastMonth.year;

    return AppDialogScaffold(
      title: '选择月份',
      maxWidth: 360,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Tooltip(
                message: '上一年',
                child: IconButton(
                  onPressed: canPreviousYear
                      ? () => setState(() => _year -= 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ),
              Expanded(
                child: Text(
                  '$_year 年',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Tooltip(
                message: '下一年',
                child: IconButton(
                  onPressed: canNextYear
                      ? () => setState(() => _year += 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final value = DateTime(_year, month);
              final enabled =
                  !_monthOnly(value).isBefore(_firstMonth) &&
                  !_monthOnly(value).isAfter(_lastMonth);
              final selected =
                  _selectedMonth.year == _year && _selectedMonth.month == month;
              final backgroundColor = selected
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.58);
              final foregroundColor = selected
                  ? colorScheme.onPrimary
                  : enabled
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.42);

              return Material(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(radius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(radius.md),
                  onTap: enabled
                      ? () => Navigator.of(context).pop(DateTime(_year, month))
                      : null,
                  child: Center(
                    child: Text(
                      '$month月',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: null,
      ),
    );
  }

  DateTime _clampMonth(DateTime value) {
    if (value.isBefore(_firstMonth)) {
      return _firstMonth;
    }
    if (value.isAfter(_lastMonth)) {
      return _lastMonth;
    }
    return value;
  }

  DateTime _monthOnly(DateTime value) {
    return DateTime(value.year, value.month);
  }
}

Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
}) {
  return showAppResponsiveDialog<DateTimeRange>(
    context: context,
    builder: (dialogContext) => _DateRangeDialog(
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialDateRange,
    ),
  );
}

class _DateRangeDialog extends StatefulWidget {
  const _DateRangeDialog({
    required this.firstDate,
    required this.lastDate,
    this.initialDateRange,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange? initialDateRange;

  @override
  State<_DateRangeDialog> createState() => _DateRangeDialogState();
}

class _DateRangeDialogState extends State<_DateRangeDialog> {
  late DateTime _focusedDate;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOn;

  @override
  void initState() {
    super.initState();
    final initialRange = widget.initialDateRange;
    _rangeStart = initialRange?.start;
    _rangeEnd = initialRange?.end;
    _focusedDate = initialRange?.start ?? DateTime.now();
    if (_focusedDate.isBefore(widget.firstDate)) {
      _focusedDate = widget.firstDate;
    } else if (_focusedDate.isAfter(widget.lastDate)) {
      _focusedDate = widget.lastDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;

    return AppDialogScaffold(
      title: '选择日期范围',
      maxWidth: 430,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _RangeDateChip(
                  label: '开始',
                  value: _rangeStart,
                  active: _rangeStart != null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RangeDateChip(
                  label: '结束',
                  value: _rangeEnd,
                  active: _rangeEnd != null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(radius.md),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.38),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TableCalendar(
                focusedDay: _focusedDate,
                firstDay: widget.firstDate,
                lastDay: widget.lastDate,
                rangeStartDay: _rangeStart,
                rangeEndDay: _rangeEnd,
                rangeSelectionMode: _rangeSelectionMode,
                selectedDayPredicate: (day) {
                  return isSameDay(_rangeStart, day) ||
                      isSameDay(_rangeEnd, day);
                },
                onRangeSelected: (start, end, focusedDay) {
                  setState(() {
                    _rangeStart = start;
                    _rangeEnd = end;
                    _focusedDate = focusedDay;
                    _rangeSelectionMode = RangeSelectionMode.toggledOn;
                  });
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _rangeStart = selectedDay;
                    _rangeEnd = selectedDay;
                    _focusedDate = focusedDay;
                    _rangeSelectionMode = RangeSelectionMode.toggledOn;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDate = focusedDay;
                },
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: CalendarStyle(
                  rangeHighlightColor: colorScheme.primaryContainer.withValues(
                    alpha: 0.45,
                  ),
                  rangeStartDecoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  rangeEndDecoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _canConfirm
            ? () {
                final start = _startOfDay(_rangeStart!);
                final end = _startOfDay(_rangeEnd ?? _rangeStart!);
                Navigator.of(context).pop(
                  DateTimeRange(
                    start: start.isAfter(end) ? end : start,
                    end: start.isAfter(end) ? start : end,
                  ),
                );
              }
            : null,
        confirmTooltip: '确定',
      ),
    );
  }

  bool get _canConfirm => _rangeStart != null;

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

class _RangeDateChip extends StatelessWidget {
  const _RangeDateChip({
    required this.label,
    required this.value,
    required this.active,
  });

  final String label;
  final DateTime? value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? colorScheme.primaryContainer.withValues(alpha: 0.62)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(
          color: active
              ? colorScheme.primary.withValues(alpha: 0.34)
              : colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              active ? Icons.event_available_rounded : Icons.event_note_rounded,
              size: 18,
              color: active
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value == null ? '未选择' : _dateText(value!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateText(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _CalendarDialog extends StatefulWidget {
  const _CalendarDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.showTime,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool showTime;

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late DateTime _selectedDate;
  late DateTime _focusedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _focusedDate = widget.initialDate;
  }

  String get _formattedDate {
    final month = _selectedDate.month.toString().padLeft(2, '0');
    final day = _selectedDate.day.toString().padLeft(2, '0');
    final hour = _selectedDate.hour.toString().padLeft(2, '0');
    final minute = _selectedDate.minute.toString().padLeft(2, '0');
    return '${_selectedDate.year}-$month-$day $hour:$minute';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppDialogScaffold(
      title: widget.showTime ? '选择日期时间' : '选择日期',
      maxWidth: 390,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formattedDate,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TableCalendar(
            focusedDay: _focusedDate,
            firstDay: widget.firstDate,
            lastDay: widget.lastDate,
            selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = DateTime(
                  selectedDay.year,
                  selectedDay.month,
                  selectedDay.day,
                  _selectedDate.hour,
                  _selectedDate.minute,
                );
                _focusedDate = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDate = focusedDay;
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          ),
          if (widget.showTime) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: () => Navigator.of(context).pop(_selectedDate),
        confirmTooltip: '确定',
      ),
    );
  }
}
