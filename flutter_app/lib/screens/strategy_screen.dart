import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../services/api_service.dart';
import '../models/brief.dart';

class StrategyScreen extends StatefulWidget {
  final ApiService api;
  const StrategyScreen({super.key, required this.api});

  @override
  State<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends State<StrategyScreen> {
  List<Brief> _briefs = [];
  bool _loading = true;
  int? _openingBriefId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final data = await widget.api.getBriefs();
    if (!mounted) return;
    setState(() {
      _briefs = data;
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _fetch,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _briefs.isEmpty
                  ? const Center(
                      child: Text('No briefs available yet. Pull to refresh.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _briefs.length,
                      itemBuilder: (_, i) => _buildBriefCard(_briefs[i]),
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

  Widget _buildBriefCard(Brief brief) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openingBriefId == null ? () => _openBrief(brief) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.description, size: 40, color: Colors.indigo),
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
              const Icon(Icons.open_in_new, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
