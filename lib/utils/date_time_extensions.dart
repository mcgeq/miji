extension DateTimeComparison on DateTime {
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  bool isWithinDays(DateTime target, int days) {
    final DateTime startDate = days < 0 ? add(Duration(days: days)) : this;
    DateTime endDate = days >= 0 ? add(Duration(days: days)) : this;

    if (days < 0) {
      endDate = this;
    }
    return (target.isAfter(startDate) || target.isSameDay(startDate)) &&
        (target.isBefore(endDate) || target.isSameDay(endDate));
  }
}
