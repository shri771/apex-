import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../models/insight.dart';
import '../models/alert.dart';
import '../widgets/agent_chip.dart';
import '../widgets/section_card.dart';

class MarketingScreen extends StatefulWidget {
  final ApiService api;
  const MarketingScreen({super.key, required this.api});

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen> {
  List<Insight> _trendsInsights = [];
  List<Insight> _competitorInsights = [];
  List<AlertModel> _alerts = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final results = await Future.wait([
      widget.api.getInsights(agent: 'market_trends', limit: 30),
      widget.api.getInsights(agent: 'competitor_intelligence', limit: 20),
      widget.api.getAlerts(),
    ]);
    if (!mounted) return;
    setState(() {
      _trendsInsights = results[0] as List<Insight>;
      _competitorInsights = results[1] as List<Insight>;
      _alerts = (results[2] as List<AlertModel>).where((a) => !a.dismissed).toList();
      _loading = false;
    });
  }

  Future<void> _dismissAlert(int id) async {
    await widget.api.dismissAlert(id);
    _fetch();
  }

  List<double> _weeklyCompetitorCounts() {
    final now = DateTime.now();
    final counts = List<double>.filled(5, 0);
    for (final insight in _competitorInsights) {
      final weeksAgo = now.difference(insight.createdAt).inDays ~/ 7;
      if (weeksAgo >= 0 && weeksAgo < 5) counts[4 - weeksAgo]++;
    }
    return counts;
  }

  List<MapEntry<String, int>> _trendingKeywords() {
    final freq = <String, int>{};
    for (final insight in _trendsInsights) {
      for (final kp in insight.keyPoints) {
        if (kp.isNotEmpty) freq[kp] = (freq[kp] ?? 0) + 1;
      }
    }
    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(12).toList();
  }

  String _relativeDay(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM d').format(dt);
  }

  double get _avgConfidence {
    if (_competitorInsights.isEmpty) return 0;
    final scores = _competitorInsights.map((i) => i.score ?? 0.5).toList();
    return scores.reduce((a, b) => a + b) / scores.length;
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
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  Text('Marketing Intel',
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 20),
                  if (_alerts.isNotEmpty) ...[
                    _buildAlertCard(_alerts.first),
                    const SizedBox(height: 16),
                  ],
                  _buildBarChartCard(),
                  const SizedBox(height: 16),
                  _buildKeywordsCard(),
                  const SizedBox(height: 24),
                  _buildCompetitorFeed(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const AgentChip(label: 'MKTG_AGENT'),
        Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
      ],
    );
  }

  Widget _buildAlertCard(AlertModel alert) {
    return SectionCard(
      leftBorderColor: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(alert.title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ),
              GestureDetector(
                onTap: () => _dismissAlert(alert.id),
                child: const Icon(Icons.close, color: AppColors.textMuted, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(alert.body,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildBarChartCard() {
    final counts = _weeklyCompetitorCounts();
    final maxCount = counts.reduce((a, b) => a > b ? a : b);
    final maxY = maxCount < 3 ? 5.0 : maxCount + 2;
    final peakIdx = counts.indexOf(maxCount);
    final conf = (_avgConfidence * 100).round();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Competitor Ad Spend',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Conf.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  Text('$conf%',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(width: 10),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) => Text(
                        'W${v.toInt() + 1}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    ),
                  ),
                ),
                barGroups: List.generate(5, (i) {
                  final isPeak = i == peakIdx && counts[i] > 0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: counts[i],
                        color: isPeak
                            ? AppColors.accent
                            : AppColors.surfaceHigh,
                        width: 30,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordsCard() {
    final keywords = _trendingKeywords();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('#',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Text('Trending Keywords',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          keywords.isEmpty
              ? const Text('No keyword data yet.',
                  style: TextStyle(color: AppColors.textMuted))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: keywords.asMap().entries.map((entry) {
                    final isTrending = entry.key < 2;
                    final kw = entry.value.key;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isTrending
                            ? AppColors.accentDim
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isTrending
                              ? AppColors.accent.withOpacity(0.5)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isTrending) ...[
                            const Icon(Icons.trending_up,
                                color: AppColors.accent, size: 12),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            kw,
                            style: TextStyle(
                              color: isTrending
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildCompetitorFeed() {
    if (_competitorInsights.isEmpty) {
      return SectionCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                const Icon(Icons.radar, color: AppColors.textMuted, size: 32),
                const SizedBox(height: 8),
                const Text('No competitor data yet.',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    final sorted = List<Insight>.from(_competitorInsights)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final grouped = <String, List<Insight>>{};
    for (final insight in sorted.take(8)) {
      final day = _relativeDay(insight.createdAt);
      grouped.putIfAbsent(day, () => []).add(insight);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.rss_feed, color: AppColors.textSecondary, size: 18),
            SizedBox(width: 8),
            Text('Recent Competitor Launches',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ],
        ),
        const SizedBox(height: 12),
        ...grouped.entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${DateFormat('h:mm a').format(entry.value.first.createdAt)} ${entry.key}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
                ...entry.value.map(_buildFeedItem),
              ],
            )),
      ],
    );
  }

  Widget _buildFeedItem(Insight insight) {
    final meta = insight.metadata ?? {};
    final compName = meta['competitor_name'] as String? ??
        insight.source.split('/').lastWhere((s) => s.isNotEmpty,
            orElse: () => insight.source);
    final compType = meta['competitor_type'] as String? ?? 'direct';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _tagChip(compName, accent: true),
              const SizedBox(width: 6),
              _tagChip(compType, accent: false),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '"${insight.summary}"',
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.remove_red_eye_outlined,
                  color: AppColors.textMuted, size: 13),
              const SizedBox(width: 4),
              Text(
                '${((insight.score ?? 0.5) * 100).round()}% conf.',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: insight.severity == 'high'
                      ? AppColors.danger.withOpacity(0.15)
                      : AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  insight.severity == 'high' ? 'High Threat' : 'Watch',
                  style: TextStyle(
                    color: insight.severity == 'high'
                        ? AppColors.danger
                        : AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
        ],
      ),
    );
  }

  Widget _tagChip(String label, {bool accent = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent ? AppColors.accentDim : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color:
                accent ? AppColors.accent.withOpacity(0.3) : AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent ? AppColors.accent : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
