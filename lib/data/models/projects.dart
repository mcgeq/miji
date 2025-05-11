class Project {
  final String? description;
  final String name;
  final String serialNum;

  Project({
    required this.description,
    required this.name,
    required this.serialNum,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      description: json['description'] as String?,
      name: json['name'] as String? ?? '',
      serialNum: json['serial_num'] as String? ?? '',
    );
  }
}