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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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
}
