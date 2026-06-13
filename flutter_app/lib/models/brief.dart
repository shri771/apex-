class Brief {
  final int id;
  final String weekStart;
  final String filePath;
  final String? summary;
  final DateTime createdAt;

  Brief({
    required this.id,
    required this.weekStart,
    required this.filePath,
    this.summary,
    required this.createdAt,
  });

  factory Brief.fromJson(Map<String, dynamic> json) {
    return Brief(
      id: json['id'] as int,
      weekStart: json['week_start'] as String,
      filePath: json['file_path'] as String,
      summary: json['summary'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
