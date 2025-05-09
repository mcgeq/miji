enum Priority {
  low,
  medium,
  high;

  int toJson() => index;
  static Priority fromJson(int value) => Priority.values[value];
}

int? priorityToJson(Priority? priority) => priority?.toJson();
