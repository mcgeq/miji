enum Status {
  todo,
  inProgress,
  done;

  int toJson() => index;
  static Status fromJson(int value) => Status.values[value];
}

int? statusToJson(Status? status) => status?.toJson();
