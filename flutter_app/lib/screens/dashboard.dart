import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/insight.dart';
import '../models/alert.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService api;
  const DashboardScreen({super.key, required this.api});

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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(insight.category.toUpperCase()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(insight.summary),
              const SizedBox(height: 8),
              Text('Source: ${insight.source}',
                  style: Theme.of(context).textTheme.bodySmall),
              Text('Agent: ${insight.agent}',
                  style: Theme.of(context).textTheme.bodySmall),
              Text('Severity: ${insight.severity}',
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

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'threat':
        return Colors.red;
      case 'opportunity':
        return Colors.green;
      default:
        return Colors.grey;
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
      color: Colors.red.shade800,
      child: InkWell(
        onTap: () {
          if (alert.insightId != null) {
            final insight = _insights.where((i) => i.id == alert.insightId).firstOrNull;
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => _dismissAlert(alert.id),
                child: const Text('Dismiss', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard(Insight insight) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_agentIcon(insight.agent), size: 32, color: Colors.indigo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _categoryColor(insight.category),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          insight.category.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        insight.agent,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(insight.summary, maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(insight.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
