enum Priority {
  low,
  medium,
  high;

  int toJson() => index;
  static Priority fromJson(int value) => Priority.values[value];
}
