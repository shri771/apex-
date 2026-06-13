import 'dart:convert';

class Insight {
  final int id;
  final String agent;
  final int runId;
  final String source;
  final String? rawText;
  final String summary;
  final String category;
  final String severity;
  final double? score;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? expiresAt;

  Insight({
    required this.id,
    required this.agent,
    required this.runId,
    required this.source,
    this.rawText,
    required this.summary,
    required this.category,
    required this.severity,
    this.score,
    this.metadata,
    required this.createdAt,
    this.expiresAt,
  });

  factory Insight.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? meta;
    // extra_data is the actual DB/API field; metadata is a legacy fallback
    final rawMeta = json['extra_data'] ?? json['metadata'];
    if (rawMeta != null) {
      if (rawMeta is String) {
        try {
          meta = jsonDecode(rawMeta as String) as Map<String, dynamic>;
        } catch (_) {}
      } else if (rawMeta is Map) {
        meta = Map<String, dynamic>.from(rawMeta as Map);
      }
    }
    return Insight(
      id: json['id'] as int,
      agent: json['agent'] as String,
      runId: json['run_id'] as int,
      source: json['source'] as String,
      rawText: json['raw_text'] as String?,
      summary: json['summary'] as String,
      category: json['category'] as String,
      severity: json['severity'] as String,
      score: (json['score'] as num?)?.toDouble(),
      metadata: meta,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  List<String> get keyPoints {
    final pts = metadata?['key_points'];
    if (pts is List) return pts.map((e) => e.toString()).toList();
    return [];
  }
}
