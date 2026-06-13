import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/insight.dart';

class MarketingScreen extends StatefulWidget {
  final ApiService api;
  const MarketingScreen({super.key, required this.api});

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

  Map<String, List<Insight>> get _bySource {
    final map = <String, List<Insight>>{};
    for (final insight in _insights) {
      map.putIfAbsent(insight.source, () => []).add(insight);
    }
    return map;
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
                Text('Trend Keywords', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _allKeywords.isEmpty
                    ? const Text('No keyword data yet.')
                    : Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _allKeywords
                            .map((kw) => Chip(label: Text(kw)))
                            .toList(),
                      ),
                const SizedBox(height: 20),
                Text('Source Feed', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_bySource.isEmpty)
                  const Text('No sources yet.')
                else
                  ..._bySource.entries.map(
                    (e) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.rss_feed),
                        title: Text(
                          e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${e.value.length} item(s) · ${e.value.first.summary}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
