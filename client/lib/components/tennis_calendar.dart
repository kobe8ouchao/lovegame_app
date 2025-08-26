import 'package:flutter/material.dart';
import 'dart:ui';

class TennisCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const TennisCalendar({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<TennisCalendar> createState() => _TennisCalendarState();
}

class _TennisCalendarState extends State<TennisCalendar> {
  late List<DateTime> _calendarDates;
  late ScrollController _scrollController;
  late DateTime _displayMonth; // 当前显示的月份

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _displayMonth = widget.selectedDate;
    _calendarDates = _generateThreeMonthDates(widget.selectedDate);

    // 在下一帧渲染完成后滚动到选中日期
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });
  }

  @override
  void didUpdateWidget(TennisCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      // 更新显示月份
      setState(() {
        _displayMonth = widget.selectedDate;
      });
      _scrollToSelectedDate();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 滚动到选中的日期
  void _scrollToSelectedDate() {
    final selectedIndex = _calendarDates.indexWhere((date) =>
        date.day == widget.selectedDate.day &&
        date.month == widget.selectedDate.month &&
        date.year == widget.selectedDate.year);

    if (selectedIndex >= 0) {
      // 计算需要滚动的位置，使选中日期居中
      const itemWidth = 60.0; // 每个日期项的宽度
      final screenWidth = MediaQuery.of(context).size.width;
      final offset =
          (selectedIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // 生成三个月的日期（上个月、当前月和下个月）
  List<DateTime> _generateThreeMonthDates(DateTime selectedDate) {
    List<DateTime> dates = [];

    // 上个月
    final DateTime prevMonth =
        DateTime(selectedDate.year, selectedDate.month - 1, 1);
    final int daysInPrevMonth =
        DateTime(selectedDate.year, selectedDate.month, 0).day;

    // 只添加上个月的后半部分（最后10天）
    final int startDayPrev = daysInPrevMonth > 10 ? daysInPrevMonth - 10 : 1;
    for (int i = startDayPrev; i <= daysInPrevMonth; i++) {
      dates.add(DateTime(prevMonth.year, prevMonth.month, i));
    }

    // 当前月
    final int daysInCurrentMonth =
        DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    for (int i = 1; i <= daysInCurrentMonth; i++) {
      dates.add(DateTime(selectedDate.year, selectedDate.month, i));
    }

    // 下个月
    final DateTime nextMonth =
        DateTime(selectedDate.year, selectedDate.month + 1, 1);
    // 只添加下个月的前10天
    const int endDayNext = 10;
    for (int i = 1; i <= endDayNext; i++) {
      dates.add(DateTime(nextMonth.year, nextMonth.month, i));
    }

    return dates;
  }

  // 当滚动时更新显示的月份
  void _updateDisplayMonth() {
    if (_scrollController.hasClients) {
      // 计算当前可见区域中心位置对应的日期索引
      final screenWidth = MediaQuery.of(context).size.width;
      final centerOffset = _scrollController.offset + (screenWidth / 2);
      const itemWidth = 60.0;
      final centerIndex = (centerOffset / itemWidth).floor();

      // 确保索引在有效范围内
      if (centerIndex >= 0 && centerIndex < _calendarDates.length) {
        final centerDate = _calendarDates[centerIndex];
        // 如果月份变化，更新显示月份
        if (_displayMonth.month != centerDate.month ||
            _displayMonth.year != centerDate.year) {
          setState(() {
            _displayMonth = centerDate;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
            child: Text(
              '${_getMonthName(_displayMonth.month)}, ${_displayMonth.year}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            height: 100,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (notification is ScrollEndNotification) {
                  _updateDisplayMonth();
                }
                return true;
              },
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                itemCount: _calendarDates.length,
                itemBuilder: (context, index) {
                  final date = _calendarDates[index];
                  final isSelected = date.day == widget.selectedDate.day &&
                      date.month == widget.selectedDate.month &&
                      date.year == widget.selectedDate.year;
                  final isToday = _isToday(date);
                  final isCurrentMonth = date.month == _displayMonth.month;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: GestureDetector(
                      onTap: () => widget.onDateSelected(date),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 52,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.45)
                                  : isToday
                                      ? Colors.white.withOpacity(0.25)
                                      : isCurrentMonth
                                          ? Colors.white.withOpacity(0.15)
                                          : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 0.5)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _getDayName(date.weekday),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(
                                        isSelected || isCurrentMonth
                                            ? 1.0
                                            : 0.5),
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: isSelected
                                      ? const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        )
                                      : null,
                                  child: Center(
                                    child: Text(
                                      date.day.toString(),
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.black
                                            : Colors.white.withOpacity(
                                                isCurrentMonth ? 1.0 : 0.5),
                                        fontSize: 18,
                                        fontWeight: isSelected || isToday
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day &&
        date.month == now.month &&
        date.year == now.year;
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}
