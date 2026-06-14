import 'dart:async';
import 'package:flutter/material.dart';
import 'theme.dart';
import 'services/api_service.dart';
import 'screens/marketing_screen.dart';
import 'screens/product_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/strategy_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const MarketIntelligenceApp());
}

class MarketIntelligenceApp extends StatelessWidget {
  const MarketIntelligenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Market Intelligence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final ApiService _api = ApiService();
  int _currentIndex = 0;

  // Agent status polling
  Timer? _statusTimer;
  Map<String, String> _prevStatuses = {}; // agentName → last known status
  List<String> _runningAgents = [];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      MarketingScreen(api: _api),
      ProductScreen(api: _api),
      SalesScreen(api: _api),
      StrategyScreen(api: _api),
      SettingsScreen(api: _api),
    ];
    _startStatusPolling();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startStatusPolling() {
    _pollStatus(); // immediate first poll
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollStatus());
  }

  Future<void> _pollStatus() async {
    final status = await _api.getAgentStatus();
    if (!mounted || status.isEmpty) return;

    final running = <String>[];
    final justFinished = <({String name, String status, int findings})>[];

    for (final entry in status.entries) {
      final name = entry.key;
      final info = entry.value as Map<String, dynamic>? ?? {};
      final lastRun = info['last_run'] as Map<String, dynamic>?;
      final currentStatus = lastRun?['status'] as String? ?? 'unknown';
      final findings = lastRun?['findings'] as int? ?? 0;

      if (currentStatus == 'running') running.add(name);

      // Detect transition: was running, now done
      final prev = _prevStatuses[name];
      if (prev == 'running' && (currentStatus == 'success' || currentStatus == 'failed')) {
        justFinished.add((name: name, status: currentStatus, findings: findings));
      }

      _prevStatuses[name] = currentStatus;
    }

    setState(() => _runningAgents = running);

    for (final agent in justFinished) {
      if (mounted) _showCompletionDialog(agent.name, agent.status, agent.findings);
    }
  }

  void _showCompletionDialog(String agentName, String status, int findings) {
    final isSuccess = status == 'success';
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSuccess ? AppColors.accent : AppColors.danger,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                color: isSuccess ? AppColors.accent : AppColors.danger,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                isSuccess ? 'Agent Complete' : 'Agent Failed',
                style: TextStyle(
                  color: isSuccess ? AppColors.accent : AppColors.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                agentName.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (isSuccess) ...[
                const SizedBox(height: 6),
                Text(
                  '$findings finding${findings != 1 ? 's' : ''} stored',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: isSuccess ? AppColors.accent : AppColors.danger,
                    foregroundColor: AppColors.bg,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_runningAgents.isNotEmpty) _buildAgentStatusBar(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1F2937))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.campaign_outlined), activeIcon: Icon(Icons.campaign), label: 'Marketing'),
            BottomNavigationBarItem(icon: Icon(Icons.star_outline), activeIcon: Icon(Icons.star), label: 'Product'),
            BottomNavigationBarItem(icon: Icon(Icons.bolt_outlined), activeIcon: Icon(Icons.bolt), label: 'Sales'),
            BottomNavigationBarItem(icon: Icon(Icons.auto_stories_outlined), activeIcon: Icon(Icons.auto_stories), label: 'Strategy'),
            BottomNavigationBarItem(icon: Icon(Icons.tune_outlined), activeIcon: Icon(Icons.tune), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentStatusBar() {
    final names = _runningAgents
        .map((n) => n.replaceAll('_', ' '))
        .join(' · ');
    return Material(
      color: AppColors.accentDim,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 16,
          right: 16,
          bottom: 8,
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '⚡ Running: $names',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
