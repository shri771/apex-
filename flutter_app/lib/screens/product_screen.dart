import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../models/insight.dart';
import '../widgets/agent_chip.dart';
import '../widgets/section_card.dart';
import '../widgets/severity_badge.dart';

class ProductScreen extends StatefulWidget {
  final ApiService api;
  const ProductScreen({super.key, required this.api});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  List<Insight> _insights = [];
  bool _loading = true;
  int _dayRange = 7;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final since = DateTime.now().subtract(Duration(days: _dayRange));
    // Fetch from legacy product agent AND demand_lead_signals as fallback
    final results = await Future.wait([
      widget.api.getInsights(agent: 'product', limit: 50, since: since.toIso8601String()),
      widget.api.getInsights(agent: 'demand_lead_signals', limit: 20, since: since.toIso8601String()),
    ]);
    if (!mounted) return;
    final combined = [
      ...results[0] as List<Insight>,
      ...results[1] as List<Insight>,
    ];
    setState(() {
      _insights = combined;
      _loading = false;
    });
  }

  Future<void> _runProductAgent() async {
    try {
      await widget.api.triggerAgentRun('product');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product agent started — pull to refresh in ~1 min')),
      );
    } catch (_) {}
  }

  Insight? get _anomaly =>
      _insights.where((i) => i.severity == 'high').firstOrNull;

  double get _avgSentiment {
    final scored = _insights.where((i) => i.score != null).toList();
    if (scored.isEmpty) return 0;
    return scored.map((i) => i.score!).reduce((a, b) => a + b) / scored.length;
  }

  (int pos, int neu, int neg) get _sentimentBreakdown {
    int pos = 0, neu = 0, neg = 0;
    for (final i in _insights) {
      final s = i.score ?? 0;
      if (s > 0.1) pos++;
      else if (s < -0.1) neg++;
      else neu++;
    }
    return (pos, neu, neg);
  }

  Map<String, int> get _volumeBySource {
    final map = <String, int>{};
    for (final insight in _insights) {
      final st = insight.metadata?['source_type'] as String? ?? 'other';
      map[st] = (map[st] ?? 0) + 1;
    }
    return map;
  }

  List<Insight> get _frictionPoints {
    final sorted = List<Insight>.from(_insights)
      ..sort((a, b) => (a.score ?? 0).compareTo(b.score ?? 0));
    return sorted.take(3).toList();
  }

  void _cycleDateRange() {
    setState(() => _dayRange = _dayRange == 7 ? 14 : (_dayRange == 14 ? 30 : 7));
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetch,
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : _insights.isEmpty
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      if (_anomaly != null) ...[
                        _buildAnomalyCard(_anomaly!),
                        const SizedBox(height: 16),
                      ],
                      _buildSentimentScoreCard(),
                      const SizedBox(height: 16),
                      _buildVolumeChart(),
                      const SizedBox(height: 16),
                      _buildFrictionPoints(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_outline, color: AppColors.textMuted, size: 48),
              const SizedBox(height: 16),
              const Text('No product data yet',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              const Text(
                'Run the Product agent to start tracking customer sentiment, reviews, and feature requests.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _runProductAgent,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Run Product Agent'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Also set Play Store App IDs and Reddit keywords in Settings for richer data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AgentChip(label: 'PRODUCT_AGENT_V2', statusLabel: 'Active Monitoring'),
            const Spacer(),
            const Icon(Icons.notifications_outlined,
                color: AppColors.textSecondary, size: 22),
          ],
        ),
        const SizedBox(height: 14),
        const Text('Customer Sentiment\n& Gap Analysis',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 24,
                height: 1.25)),
        const SizedBox(height: 12),
        Row(
          children: [
            _filterChip('Last $_dayRange Days', Icons.calendar_today_outlined,
                onTap: _cycleDateRange),
            const SizedBox(width: 10),
            _actionButton('Export Data', Icons.download_outlined,
                onTap: () => widget.api.triggerAgentRun('product')),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomalyCard(Insight insight) {
    return SectionCard(
      leftBorderColor: AppColors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.blue, size: 18),
              SizedBox(width: 8),
              Text('Anomaly Detected',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(insight.summary,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildSentimentScoreCard() {
    final avg = _avgSentiment;
    final score = ((avg + 1) * 50).round().clamp(0, 100);
    final (pos, neu, neg) = _sentimentBreakdown;
    final total = pos + neu + neg;
    final posP = total > 0 ? (pos / total * 100).round() : 0;
    final neuP = total > 0 ? (neu / total * 100).round() : 0;
    final negP = total > 0 ? (neg / total * 100).round() : 0;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Global Sentiment Score',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.blue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$score',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      height: 1)),
              const Text(' / 100',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (posP > 0)
                    Expanded(flex: posP, child: const ColoredBox(color: AppColors.accent)),
                  if (neuP > 0)
                    Expanded(flex: neuP, child: const ColoredBox(color: AppColors.warning)),
                  Expanded(
                      flex: negP > 0 ? negP : (posP + neuP == 0 ? 100 : 1),
                      child: const ColoredBox(color: AppColors.danger)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('+ $posP%',
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              Text('= $neuP%',
                  style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              Text('- $negP%',
                  style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeChart() {
    final volume = _volumeBySource;
    final sources = volume.keys.toList();
    final maxVal =
        volume.values.fold(0, (a, b) => a > b ? a : b).toDouble();
    final totalMentions = volume.values.fold(0, (a, b) => a + b);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Volume by Source',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const Icon(Icons.bar_chart,
                  color: AppColors.textMuted, size: 18),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: sources.isEmpty
                ? const Center(
                    child: Text('No source data yet.',
                        style: TextStyle(color: AppColors.textMuted)))
                : BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxVal < 1 ? 5 : maxVal + 1,
                    barTouchData: BarTouchData(enabled: false),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx >= sources.length) return const Text('');
                            final label = sources[idx];
                            return Text(
                              label.length > 6
                                  ? label.substring(0, 6)
                                  : label,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 10),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: sources.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: (volume[e.value] ?? 0).toDouble(),
                            color: AppColors.blue,
                            width: 24,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  )),
          ),
          const SizedBox(height: 10),
          Text(
            'Total mentions: ${NumberFormat('#,###').format(totalMentions)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFrictionPoints() {
    final points = _frictionPoints;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Top 3 Friction Points',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text('Extracted via NLP',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (points.isEmpty)
          const SectionCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No friction data yet.',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            ),
          )
        else
          ...points.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildFrictionCard(e.key + 1, e.value),
              )),
      ],
    );
  }

  Widget _buildFrictionCard(int rank, Insight insight) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$rank. ${_capitalize(insight.category)} Friction',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ),
              SeverityBadge(severity: insight.severity),
            ],
          ),
          const SizedBox(height: 8),
          Text(insight.summary,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline,
                  color: AppColors.textMuted, size: 13),
              const SizedBox(width: 4),
              Text(
                '${(insight.score != null ? (insight.score!.abs() * 100).round() : 0)} pain score',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: insight.source));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Source URL copied')),
                  );
                },
                child: const Text('View Source',
                    style: TextStyle(
                        color: AppColors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
