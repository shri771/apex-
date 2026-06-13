import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../models/insight.dart';
import '../widgets/agent_chip.dart';
import '../widgets/section_card.dart';
import '../widgets/severity_badge.dart';

class SalesScreen extends StatefulWidget {
  final ApiService api;
  const SalesScreen({super.key, required this.api});

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
    final data = await widget.api.getInsights(agent: 'demand_lead_signals', limit: 30);
    if (!mounted) return;
    final sorted = List<Insight>.from(data)
      ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
    setState(() {
      _insights = sorted;
      _loading = false;
    });
  }

  Future<void> _runPipeline() async {
    try {
      await widget.api.triggerPipeline();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pipeline started — check back in a few minutes')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start pipeline')),
      );
    }
  }

  String _urgency(Insight insight) {
    final u = insight.metadata?['urgency'] as String?;
    if (u != null) return u;
    switch (insight.severity.toLowerCase()) {
      case 'high': return 'hot';
      case 'medium': return 'warm';
      default: return 'cold';
    }
  }

  int get _hotCount => _insights.where((i) => _urgency(i) == 'hot').length;
  int get _warmCount => _insights.where((i) => _urgency(i) == 'warm').length;
  int get _coldCount => _insights.where((i) => _urgency(i) == 'cold').length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetch,
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildSummaryRow(),
                  const SizedBox(height: 20),
                  if (_insights.isEmpty)
                    _buildEmptyState()
                  else
                    ..._insights.map(_buildLeadCard),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const AgentChip(label: 'SALES_AGENT'),
        Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
      ],
    );
  }

  Widget _buildSummaryRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Demand & Lead Signals',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 24)),
        const SizedBox(height: 14),
        Row(
          children: [
            _urgencyChip('Hot', _hotCount, AppColors.danger),
            const SizedBox(width: 8),
            _urgencyChip('Warm', _warmCount, AppColors.warning),
            const SizedBox(width: 8),
            _urgencyChip('Cold', _coldCount, AppColors.textMuted),
          ],
        ),
      ],
    );
  }

  Widget _urgencyChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadCard(Insight insight) {
    final meta = insight.metadata ?? {};
    final company = meta['company_mentioned'] as String? ?? 'Unknown Company';
    final signalType = meta['signal_type'] as String? ?? 'other';
    final sourceType = meta['source_type'] as String? ?? 'unknown';
    final outreach = meta['outreach_angle'] as String? ?? '';
    final urgency = _urgency(insight);

    final urgencyColor = switch (urgency) {
      'hot' => AppColors.danger,
      'warm' => AppColors.warning,
      _ => AppColors.textMuted,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        leftBorderColor: urgencyColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(company,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                ),
                _signalTypeBadge(signalType),
                const SizedBox(width: 6),
                SeverityBadge(severity: insight.severity, compact: true),
              ],
            ),
            const SizedBox(height: 6),
            _sourceChip(sourceType),
            const SizedBox(height: 8),
            Text(insight.summary,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5)),
            if (outreach.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Outreach:  ',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    Expanded(
                      child: Text(outreach,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${((insight.score ?? 0.5) * 100).round()}% intent',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _signalTypeBadge(String type) {
    final label = switch (type) {
      'pain_point' => 'Pain Point',
      'funding' => 'Funding',
      'icp_match' => 'ICP Match',
      'technographic' => 'Tech Signal',
      _ => 'Signal',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.blueDim,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.blue.withOpacity(0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.blue, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }

  Widget _sourceChip(String source) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(source,
          style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontFamily: 'monospace')),
    );
  }

  Widget _buildEmptyState() {
    return SectionCard(
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.bolt_outlined, color: AppColors.textMuted, size: 40),
          const SizedBox(height: 12),
          const Text('No lead signals yet.',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 15)),
          const SizedBox(height: 6),
          const Text('Set your ICP keywords in Settings,\nthen run the pipeline.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.bg),
              onPressed: _runPipeline,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Run Pipeline'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
