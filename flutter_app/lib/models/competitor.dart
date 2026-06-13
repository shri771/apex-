class Competitor {
  final int id;
  final String name;
  final String? website;
  final String? description;
  final String type; // direct | indirect | emerging
  final bool active;
  final DateTime createdAt;

  Competitor({
    required this.id,
    required this.name,
    this.website,
    this.description,
    required this.type,
    required this.active,
    required this.createdAt,
  });

  factory Competitor.fromJson(Map<String, dynamic> json) {
    return Competitor(
      id: json['id'] as int,
      name: json['name'] as String,
      website: json['website'] as String?,
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'direct',
      active: json['active'] == true || json['active'] == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
