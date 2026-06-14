import 'dart:async';
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'models/snapshot.dart';
import 'screens/dashboard.dart';
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
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
  MarketSnapshot _snapshot = MarketSnapshot.empty();
  bool _snapshotLoading = true;
  Timer? _snapshotTimer;

  late final List<Widget Function(MarketSnapshot, bool)> _screenBuilders;

  @override
  void initState() {
    super.initState();
    _fetchSnapshot();
    // Refresh snapshot every 60 seconds
    _snapshotTimer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchSnapshot());
  }

  @override
  void dispose() {
    _snapshotTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSnapshot() async {
    final s = await _api.getSnapshot();
    if (!mounted) return;
    setState(() {
      _snapshot = s;
      _snapshotLoading = false;
    });
  }

  List<Widget> get _screens => [
        DashboardScreen(api: _api, snapshot: _snapshot, snapshotLoading: _snapshotLoading),
        MarketingScreen(api: _api, snapshot: _snapshot, snapshotLoading: _snapshotLoading),
        ProductScreen(api: _api, snapshot: _snapshot, snapshotLoading: _snapshotLoading),
        SalesScreen(api: _api, snapshot: _snapshot, snapshotLoading: _snapshotLoading),
        StrategyScreen(api: _api, snapshot: _snapshot, snapshotLoading: _snapshotLoading),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen(api: _api)),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Marketing'),
          BottomNavigationBarItem(icon: Icon(Icons.star_rate), label: 'Product'),
          BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Sales'),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Strategy'),
        ],
      ),
    );
  }
}
