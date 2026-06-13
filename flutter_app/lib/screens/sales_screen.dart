import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/insight.dart';

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
    final data = await widget.api.getInsights(agent: 'sales', limit: 30);
    if (!mounted) return;
    final sorted = List<Insight>.from(data)
      ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
    setState(() {
      _insights = sorted;
      _loading = false;
    });
  }

  Color _intentColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _intentLabel(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      default:
        return 'Low';
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetch,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _insights.isEmpty
              ? const Center(child: Text('No sales signals yet. Pull to refresh.'))
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      columns: const [
                        DataColumn(label: Text('Company')),
                        DataColumn(label: Text('Signal')),
                        DataColumn(label: Text('Intent')),
                      ],
                      rows: _insights.map((insight) {
                        final company = Uri.tryParse(insight.source)?.host.isNotEmpty == true
                            ? Uri.parse(insight.source).host
                            : insight.source;
                        return DataRow(cells: [
                          DataCell(
                            SizedBox(
                              width: 100,
                              child: Text(
                                company,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: Text(
                                insight.summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _intentColor(insight.severity),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _intentLabel(insight.severity),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
    );
  }
}
