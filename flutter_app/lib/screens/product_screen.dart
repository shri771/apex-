import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../models/insight.dart';
import '../models/snapshot.dart';
import '../widgets/market_snapshot_card.dart';

class ProductScreen extends StatefulWidget {
  final ApiService api;
  final MarketSnapshot snapshot;
  final bool snapshotLoading;

  const ProductScreen({
    super.key,
    required this.api,
    required this.snapshot,
    this.snapshotLoading = false,
  });

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  List<Insight> _insights = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final since = DateTime.now().subtract(const Duration(days: 14));
    final data = await widget.api.getInsights(
      agent: 'product',
      limit: 50,
      since: since.toIso8601String(),
    );
    if (!mounted) return;
    setState(() {
      _insights = data;
      _loading = false;
    });
  }

  List<FlSpot> _buildChartSpots() {
    final now = DateTime.now();
    final dayScores = <int, List<double>>{};
    for (final insight in _insights) {
      if (insight.score == null) continue;
      final daysAgo = now.difference(insight.createdAt).inDays;
      if (daysAgo >= 0 && daysAgo < 14) {
        dayScores.putIfAbsent(13 - daysAgo, () => []).add(insight.score!);
      }
    }
    return List.generate(14, (i) {
      final scores = dayScores[i];
      if (scores == null || scores.isEmpty) return FlSpot(i.toDouble(), 0);
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      return FlSpot(i.toDouble(), avg.clamp(-1.0, 1.0));
    });
  }

  List<String> get _featureRequests {
    final seen = <String>{};
    final result = <String>[];
    for (final insight in _insights) {
      for (final kp in insight.keyPoints) {
        if (seen.add(kp)) result.add(kp);
      }
      // Also pull feature_requests from metadata if present
      final meta = insight.metadata ?? {};
      final features = meta['feature_requests'];
      if (features is List) {
        for (final f in features) {
          final fs = f.toString();
          if (seen.add(fs)) result.add(fs);
        }
      }
    }
    return result;
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
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Text('Sentiment (Last 14 Days)',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(height: 200, child: _buildChart()),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: Text('Feature Requests',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _featureRequests.isEmpty
                  ? const Text('No feature request data yet.',
                      style: TextStyle(color: Colors.grey))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _featureRequests
                          .take(30)
                          .map((f) => Chip(
                                label: Text(f,
                                    style: const TextStyle(fontSize: 11)),
                                backgroundColor:
                                    Colors.indigo.withOpacity(0.2),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildChart() {
    final spots = _buildChartSpots();
    return LineChart(
      LineChartData(
        minY: -1,
        maxY: 1,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              getTitlesWidget: (value, meta) => Text(
                'D${value.toInt()}',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.indigo,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.indigo.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
