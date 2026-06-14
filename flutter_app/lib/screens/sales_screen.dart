import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/insight.dart';
import '../models/snapshot.dart';
import '../widgets/market_snapshot_card.dart';

class SalesScreen extends StatefulWidget {
  final ApiService api;
  final MarketSnapshot snapshot;
  final bool snapshotLoading;

  const SalesScreen({
    super.key,
    required this.api,
    required this.snapshot,
    this.snapshotLoading = false,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Insight> _insights = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final data = await widget.api.getInsights(agent: 'sales', limit: 30);
    if (!mounted) return;
    final sorted = List<Insight>.from(data)
      ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
    setState(() {
      _insights = sorted;
      _loading = false;
    });
  }

  Color _intentColor(double? score) {
    if (score == null) return Colors.grey;
    if (score >= 0.7) return Colors.green;
    if (score >= 0.4) return Colors.orange;
    return Colors.grey;
  }

  Color _intentBgColor(double? score) {
    if (score == null) return Colors.grey.shade900;
    if (score >= 0.7) return const Color(0xFF0d2518);
    if (score >= 0.4) return const Color(0xFF1c1400);
    return Colors.grey.shade900;
  }

  String _companyLabel(Insight insight) {
    final meta = insight.metadata ?? {};
    final company = meta['company'] as String?;
    if (company != null && company.isNotEmpty && company != 'unknown') {
      return company;
    }
    try {
      final host = Uri.parse(insight.source).host;
      if (host.isNotEmpty) return host;
    } catch (_) {}
    return insight.source.isEmpty ? 'Unknown' : insight.source;
  }

  String _signalType(Insight insight) {
    final meta = insight.metadata ?? {};
    return (meta['signal_type'] as String? ?? 'other').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          MarketSnapshotCard(
            snapshot: widget.snapshot,
            isLoading: widget.snapshotLoading,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_insights.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text('No sales signals yet. Pull to refresh.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Text(
                '🎯 Buying Signals  ·  ${_insights.length} leads',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFFffab40),
                ),
              ),
            ),
            ..._insights.map(_buildLeadCard),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildLeadCard(Insight insight) {
    final score = insight.score;
    final intentPct = score != null ? (score * 100).round() : 0;
    final company = _companyLabel(insight);
    final signalType = _signalType(insight);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      color: _intentBgColor(score),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _intentColor(score).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: company + intent score
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          signalType,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                // Intent Score
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'INTENT SCORE',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '$intentPct/100',
                      style: TextStyle(
                        color: _intentColor(score),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Progress bar
            if (score != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score.clamp(0.0, 1.0),
                  backgroundColor: Colors.white10,
                  color: _intentColor(score),
                  minHeight: 5,
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Summary
            Text(
              insight.summary,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
