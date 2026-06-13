class AlertModel {
  final int id;
  final int? insightId;
  final String title;
  final String body;
  final bool dismissed;
  final DateTime createdAt;

  AlertModel({
    required this.id,
    this.insightId,
    required this.title,
    required this.body,
    required this.dismissed,
    required this.createdAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as int,
      insightId: json['insight_id'] as int?,
      title: json['title'] as String,
      body: json['body'] as String,
      dismissed: json['dismissed'] == true || json['dismissed'] == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
