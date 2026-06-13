import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../models/insight.dart';

class ProductScreen extends StatefulWidget {
  final ApiService api;
  const ProductScreen({super.key, required this.api});

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
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetch,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text('Sentiment (Last 14 Days)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SizedBox(height: 220, child: _buildChart()),
                const SizedBox(height: 24),
                Text('Feature Requests',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _featureRequests.isEmpty
                    ? const Text('No feature request data yet.')
                    : Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _featureRequests
                            .map((f) => Chip(
                                  label: Text(f),
                                  backgroundColor:
                                      Colors.indigo.withOpacity(0.2),
                                ))
                            .toList(),
                      ),
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
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
