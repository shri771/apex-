import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/insight.dart';
import '../models/snapshot.dart';
import '../widgets/market_snapshot_card.dart';

class MarketingScreen extends StatefulWidget {
  final ApiService api;
  final MarketSnapshot snapshot;
  final bool snapshotLoading;

  const MarketingScreen({
    super.key,
    required this.api,
    required this.snapshot,
    this.snapshotLoading = false,
  });

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen> {
  List<Insight> _insights = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final data = await widget.api.getInsights(agent: 'marketing', limit: 30);
    if (!mounted) return;
    setState(() {
      _insights = data;
      _loading = false;
    });
  }

  List<String> get _allKeywords {
    final seen = <String>{};
    final result = <String>[];
    for (final insight in _insights) {
      for (final kp in insight.keyPoints) {
        if (seen.add(kp)) result.add(kp);
      }
    }
    return result;
  }

  /// Insights classified as threats with competitor info
  List<Insight> get _threatInsights => _insights
      .where((i) => i.category == 'threat')
      .toList()
    ..sort((a, b) {
      final sa = (a.metadata?['threat_score'] as num?)?.toInt() ?? 0;
      final sb = (b.metadata?['threat_score'] as num?)?.toInt() ?? 0;
      return sb.compareTo(sa);
    });

  /// Insights classified as opportunities
  List<Insight> get _opportunities =>
      _insights.where((i) => i.category == 'opportunity').toList();

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
          else ...[
            // ── Market Opportunities Section ──────────────────────────────
            _buildSectionHeader('📈 Market Opportunities', const Color(0xFF69f0ae)),
            if (_opportunities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('No opportunities detected yet.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ..._opportunities.map(_buildOpportunityCard),

            const SizedBox(height: 4),

            // ── Competitor Threats Section ────────────────────────────────
            _buildSectionHeader('🚨 Competitor Threats', const Color(0xFFff5252)),
            if (_threatInsights.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('No threats detected yet.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ..._threatInsights.map(_buildCompetitorCard),

            const SizedBox(height: 4),

            // ── Trend Keywords ────────────────────────────────────────────
            _buildSectionHeader('🏷️ Trend Keywords', Colors.indigo),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _allKeywords.isEmpty
                  ? const Text('No keyword data yet.',
                      style: TextStyle(color: Colors.grey))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _allKeywords
                          .take(20)
                          .map((kw) => Chip(
                                label: Text(kw,
                                    style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityCard(Insight insight) {
    final meta = insight.metadata ?? {};
    final oppTitle = meta['opportunity_title'] as String? ?? '';
    final oppDetail = meta['opportunity_detail'] as String? ?? '';
    final demandPct = (meta['demand_trend_pct'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: const Color(0xFF0d2518),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF1b5e20), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: Color(0xFF69f0ae), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    oppTitle.isNotEmpty ? oppTitle : insight.summary,
                    style: const TextStyle(
                      color: Color(0xFF69f0ae),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (demandPct != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: demandPct > 0
                          ? const Color(0xFF1b5e20)
                          : const Color(0xFFb71c1c),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${demandPct > 0 ? '+' : ''}$demandPct%',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              oppDetail.isNotEmpty ? oppDetail : insight.summary,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetitorCard(Insight insight) {
    final meta = insight.metadata ?? {};
    final threatScore = (meta['threat_score'] as num?)?.toInt() ?? 0;
    final evidence = (meta['evidence'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];
    final competitor =
        (meta['competitor_name'] as String?)?.isNotEmpty == true
            ? meta['competitor_name'] as String
            : Uri.tryParse(insight.source)?.host ?? insight.source;

    final scoreColor = threatScore >= 75
        ? Colors.red
        : threatScore >= 50
            ? Colors.orange
            : const Color(0xFF69f0ae);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: const Color(0xFF1c0a0a),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF4a0000), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: competitor + score
            Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: Color(0xFFff5252), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    competitor,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (threatScore > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Threat Score',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 9,
                        ),
                      ),
                      Text(
                        '$threatScore/100',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Score bar
            if (threatScore > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: threatScore / 100,
                  backgroundColor: Colors.white12,
                  color: scoreColor,
                  minHeight: 6,
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

            // Evidence bullets
            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'EVIDENCE',
                style: TextStyle(
                  color: Color(0xFFffab40),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              ...evidence.take(3).map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  ',
                              style: TextStyle(
                                  color: Color(0xFFffab40),
                                  fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(e,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
