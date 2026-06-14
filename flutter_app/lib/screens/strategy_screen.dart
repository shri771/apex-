import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../models/brief.dart';
import '../models/insight.dart';
import '../widgets/agent_chip.dart';
import '../widgets/section_card.dart';

class StrategyScreen extends StatefulWidget {
  final ApiService api;
  const StrategyScreen({super.key, required this.api});

  @override
  State<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends State<StrategyScreen> {
  List<Brief> _briefs = [];
  List<Insight> _strategyInsights = [];
  bool _loading = true;
  int? _openingBriefId;
  bool _pipelineRunning = false;
  int _pipelineElapsed = 0;
  Timer? _pipelineTimer;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      widget.api.getBriefs(),
      widget.api.getInsights(agent: 'strategy', limit: 3),
    ]);
    if (!mounted) return;
    setState(() {
      _briefs = results[0] as List<Brief>;
      _strategyInsights = results[1] as List<Insight>;
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Download failed: $e')));
    } finally {
      if (mounted) setState(() => _openingBriefId = null);
    }
  }

  @override
  void dispose() {
    _pipelineTimer?.cancel();
    super.dispose();
  }

  Future<void> _runPipeline() async {
    setState(() {
      _pipelineRunning = true;
      _pipelineElapsed = 0;
    });
    _pipelineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _pipelineElapsed++);
    });
    try {
      await widget.api.triggerPipeline();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pipeline started — brief will be ready in a few minutes')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start pipeline')),
      );
    } finally {
      _pipelineTimer?.cancel();
      if (mounted) setState(() => _pipelineRunning = false);
    }
  }

  String get _pipelineElapsedStr {
    final m = _pipelineElapsed ~/ 60;
    final s = _pipelineElapsed % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
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
    return SafeArea(
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetch,
            color: AppColors.accent,
            backgroundColor: AppColors.surface,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      if (_strategyInsights.isNotEmpty) ...[
                        _buildLatestInsightCard(_strategyInsights.first),
                        const SizedBox(height: 20),
                      ],
                      _buildBriefsList(),
                      const SizedBox(height: 20),
                      _buildRunButton(),
                    ],
                  ),
          ),
          if (_openingBriefId != null)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AgentChip(label: 'STRATEGY_AGENT'),
        const SizedBox(height: 12),
        const Text('Weekly Strategy Briefs',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 24)),
      ],
    );
  }

  Widget _buildLatestInsightCard(Insight insight) {
    return SectionCard(
      leftBorderColor: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.accent, size: 16),
              SizedBox(width: 8),
              Text('Latest Intelligence Summary',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 10),
          Text(insight.summary,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14, height: 1.6)),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMM d, y · h:mm a').format(insight.createdAt),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildBriefsList() {
    if (_briefs.isEmpty) {
      return SectionCard(
        child: Column(
          children: const [
            SizedBox(height: 20),
            Icon(Icons.article_outlined, color: AppColors.textMuted, size: 36),
            SizedBox(height: 10),
            Text('No briefs yet.',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 14)),
            SizedBox(height: 4),
            Text('Run the pipeline to generate your first weekly brief.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            SizedBox(height: 20),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _briefs
          .map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildBriefCard(b),
              ))
          .toList(),
    );
  }

  Widget _buildBriefCard(Brief brief) {
    return SectionCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openingBriefId == null ? () => _openBrief(brief) : null,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.description_outlined,
                  color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatWeek(brief.weekStart),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  if (brief.summary != null && brief.summary!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      brief.summary!.length > 90
                          ? '${brief.summary!.substring(0, 90)}…'
                          : brief.summary!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentDim,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_outlined, color: AppColors.accent, size: 14),
                  SizedBox(width: 4),
                  Text('Open',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _pipelineRunning ? null : _runPipeline,
        icon: _pipelineRunning
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent))
            : const Icon(Icons.play_circle_outline, size: 20),
        label: Text(_pipelineRunning
            ? 'Running pipeline… $_pipelineElapsedStr'
            : 'Generate New Brief'),
      ),
    );
  }
}
