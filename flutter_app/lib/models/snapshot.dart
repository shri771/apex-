class MarketSnapshot {
  final int threats;
  final int opportunities;
  final int buyingSignals;
  final int competitorsTracked;
  final String topRecommendation;

  const MarketSnapshot({
    required this.threats,
    required this.opportunities,
    required this.buyingSignals,
    required this.competitorsTracked,
    required this.topRecommendation,
  });

  factory MarketSnapshot.fromJson(Map<String, dynamic> json) {
    return MarketSnapshot(
      threats: (json['threats'] as num?)?.toInt() ?? 0,
      opportunities: (json['opportunities'] as num?)?.toInt() ?? 0,
      buyingSignals: (json['buying_signals'] as num?)?.toInt() ?? 0,
      competitorsTracked: (json['competitors_tracked'] as num?)?.toInt() ?? 0,
      topRecommendation: json['top_recommendation'] as String? ??
          'Review the latest market intelligence data.',
    );
  }

  factory MarketSnapshot.empty() => const MarketSnapshot(
        threats: 0,
        opportunities: 0,
        buyingSignals: 0,
        competitorsTracked: 0,
        topRecommendation: 'Waiting for data...',
      );
}
