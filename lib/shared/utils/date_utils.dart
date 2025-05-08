DateTime dateTimeFromJson(String json) => DateTime.parse(json);

String? dateTimeToJson(DateTime? date) => date?.toIso8601String();
