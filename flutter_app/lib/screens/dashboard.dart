import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/insight.dart';
import '../models/alert.dart';
import '../models/snapshot.dart';
import '../widgets/market_snapshot_card.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService api;
  final MarketSnapshot snapshot;
  final bool snapshotLoading;

  const DashboardScreen({
    super.key,
    required this.api,
    required this.snapshot,
    this.snapshotLoading = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Insight> _insights = [];
  List<AlertModel> _alerts = [];
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetch());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final results = await Future.wait([
      widget.api.getInsights(limit: 50),
      widget.api.getAlerts(),
    ]);
    if (!mounted) return;
    setState(() {
      _insights = results[0] as List<Insight>;
      _alerts = results[1] as List<AlertModel>;
      _loading = false;
    });
  }

  Future<void> _dismissAlert(int alertId) async {
    try {
      await widget.api.dismissAlert(alertId);
      await _fetch();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to dismiss alert')),
      );
    }
  }

  void _showInsightDetail(Insight insight) {
    final meta = insight.metadata ?? {};
    final threatScore = (meta['threat_score'] as num?)?.toInt();
    final evidence = (meta['evidence'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final competitor = meta['competitor_name'] as String? ?? '';
    final keyPoints = insight.keyPoints;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1e1e2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(_agentIcon(insight.agent), color: Colors.indigo, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                insight.category.toUpperCase(),
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Threat Score gauge
              if (threatScore != null && threatScore > 0) ...[
                _buildThreatScoreBar(threatScore),
                const SizedBox(height: 12),
              ],

              // Competitor name
              if (competitor.isNotEmpty) ...[
                _sectionLabel('COMPETITOR'),
                const SizedBox(height: 4),
                Text(competitor,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 12),
              ],

              // Summary
              _sectionLabel('SUMMARY'),
              const SizedBox(height: 4),
              Text(insight.summary, style: const TextStyle(fontSize: 13, height: 1.5)),
              const SizedBox(height: 12),

              // Evidence
              if (evidence.isNotEmpty) ...[
                _sectionLabel('EVIDENCE'),
                const SizedBox(height: 4),
                ...evidence.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ',
                            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(e,
                              style: const TextStyle(fontSize: 12, height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Key Points
              if (keyPoints.isNotEmpty) ...[
                _sectionLabel('KEY POINTS'),
                const SizedBox(height: 4),
                ...keyPoints.map(
                  (kp) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('›  ',
                            style: TextStyle(color: Colors.indigo)),
                        Expanded(
                          child: Text(kp, style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Meta
              Text('Agent: ${insight.agent}',
                  style: Theme.of(context).textTheme.bodySmall),
              Text('Source: ${insight.source}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildThreatScoreBar(int score) {
    final color = score >= 75
        ? Colors.red
        : score >= 50
            ? Colors.orange
            : Colors.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionLabel('THREAT SCORE'),
            Text(
              '$score / 100',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.white12,
            color: color,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Based on: mentions · sentiment · hiring · launches',
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFFffab40),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      );

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'threat':
        return const Color(0xFFb71c1c);
      case 'opportunity':
        return const Color(0xFF1b5e20);
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _agentIcon(String agent) {
    switch (agent.toLowerCase()) {
      case 'marketing':
        return Icons.trending_up;
      case 'product':
        return Icons.star_rate;
      case 'sales':
        return Icons.business;
      case 'strategy':
        return Icons.article;
      default:
        return Icons.analytics;
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MarketSnapshotCard(
          snapshot: widget.snapshot,
          isLoading: widget.snapshotLoading,
        ),
        if (_alerts.isNotEmpty) _buildAlertBanner(_alerts.first),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: _insights.isEmpty
                      ? const Center(child: Text('No insights yet. Pull to refresh.'))
                      : ListView.builder(
                          itemCount: _insights.length,
                          itemBuilder: (_, i) => _buildInsightCard(_insights[i]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildAlertBanner(AlertModel alert) {
    return Material(
      color: Colors.red.shade900,
      child: InkWell(
        onTap: () {
          if (alert.insightId != null) {
            final insight =
                _insights.where((i) => i.id == alert.insightId).firstOrNull;
            if (insight != null) _showInsightDetail(insight);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => _dismissAlert(alert.id),
                child: const Text('Dismiss',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard(Insight insight) {
    final meta = insight.metadata ?? {};
    final threatScore = (meta['threat_score'] as num?)?.toInt();
    final competitor = meta['competitor_name'] as String? ?? '';
    final category = insight.category.toLowerCase();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showInsightDetail(insight),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_agentIcon(insight.agent), size: 30, color: Colors.indigo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Category chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _categoryColor(insight.category),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            insight.category.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Threat Score badge (if available and it's a threat)
                        if (threatScore != null &&
                            threatScore > 0 &&
                            category == 'threat') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: threatScore >= 75
                                  ? Colors.red.shade900
                                  : threatScore >= 50
                                      ? Colors.orange.shade900
                                      : Colors.green.shade900,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Score: $threatScore/100',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          _relativeTime(insight.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (competitor.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        competitor,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Color(0xFFffab40),
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(insight.summary,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 3),
                    Text(
                      insight.agent,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
