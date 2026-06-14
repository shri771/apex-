import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../services/api_service.dart';
import '../models/brief.dart';
import '../models/insight.dart';
import '../models/snapshot.dart';
import '../widgets/market_snapshot_card.dart';

class StrategyScreen extends StatefulWidget {
  final ApiService api;
  final MarketSnapshot snapshot;
  final bool snapshotLoading;

  const StrategyScreen({
    super.key,
    required this.api,
    required this.snapshot,
    this.snapshotLoading = false,
  });

  @override
  State<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends State<StrategyScreen> {
  List<Brief> _briefs = [];
  Insight? _latestStrategyInsight;
  bool _loading = true;
  int? _openingBriefId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      widget.api.getBriefs(),
      widget.api.getInsights(agent: 'strategy', limit: 1),
    ]);
    if (!mounted) return;
    final briefs = results[0] as List<Brief>;
    final strategyInsights = results[1] as List<Insight>;
    setState(() {
      _briefs = briefs;
      _latestStrategyInsight =
          strategyInsights.isNotEmpty ? strategyInsights.first : null;
      _loading = false;
    });
  }

  Future<void> _openBrief(Brief brief) async {
    setState(() => _openingBriefId = brief.id);
    try {
      final filePath = await widget.api.downloadBrief(brief.id);
      final result = await OpenFilex.open(filePath);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open brief: ${result.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download brief: $e')),
      );
    } finally {
      if (mounted) setState(() => _openingBriefId = null);
    }
  }

  String _formatWeek(String weekStart) {
    try {
      final date = DateTime.parse(weekStart);
      return 'Week of ${DateFormat('MMM dd, yyyy').format(date)}';
    } catch (_) {
      return weekStart;
    }
  }

  List<Map<String, dynamic>> get _recommendedActions {
    if (_latestStrategyInsight == null) return [];
    final meta = _latestStrategyInsight!.metadata ?? {};
    final raw = meta['recommended_actions'];
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
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
                // ── Recommended Actions ─────────────────────────────────
                if (_recommendedActions.isNotEmpty) ...[
                  _buildSectionHeader(
                      '⚡ Recommended Actions', const Color(0xFFffab40)),
                  ..._recommendedActions
                      .asMap()
                      .entries
                      .map((e) => _buildActionCard(e.key + 1, e.value)),
                  const SizedBox(height: 8),
                ],

                // ── Weekly Briefs ───────────────────────────────────────
                _buildSectionHeader('📄 Weekly Briefs', Colors.indigo),
                if (_briefs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('No briefs available yet. Pull to refresh.',
                        style: TextStyle(color: Colors.grey)),
                  )
                else
                  ..._briefs.map(_buildBriefCard),

                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
        if (_openingBriefId != null)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
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

  Widget _buildActionCard(int index, Map<String, dynamic> action) {
    final impact = (action['impact'] as String? ?? 'medium').toLowerCase();
    final confidence = (action['confidence'] as num?)?.toInt() ?? 70;
    final actionText = action['action'] as String? ?? '';
    final detail = action['detail'] as String? ?? '';

    final impactColor = impact == 'high'
        ? const Color(0xFF69f0ae)
        : impact == 'medium'
            ? const Color(0xFFffab40)
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: impactColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Index circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    actionText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),

            if (detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                detail,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 10),

            // Impact + Confidence badges
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: impactColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: impactColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    'Impact: ${impact[0].toUpperCase()}${impact.substring(1)}',
                    style: TextStyle(
                      color: impactColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Confidence: $confidence%',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBriefCard(Brief brief) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openingBriefId == null ? () => _openBrief(brief) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.description, size: 36, color: Colors.indigo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatWeek(brief.weekStart),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (brief.summary != null && brief.summary!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        brief.summary!.length > 100
                            ? '${brief.summary!.substring(0, 100)}…'
                            : brief.summary!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
