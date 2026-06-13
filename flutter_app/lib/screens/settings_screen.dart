import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  final ApiService api;
  const SettingsScreen({super.key, required this.api});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keywordsCtrl = TextEditingController();
  final _competitorsCtrl = TextEditingController();
  final _appIdsCtrl = TextEditingController();
  String _selectedModel = 'phi3:mini';

  static const _models = ['phi3:mini', 'llama3.2:3b', 'gemma2:2b'];
  static const _agents = ['marketing', 'product', 'sales', 'strategy'];

  @override
  void dispose() {
    _keywordsCtrl.dispose();
    _competitorsCtrl.dispose();
    _appIdsCtrl.dispose();
    super.dispose();
  }

  Future<void> _triggerAgent(String name) async {
    try {
      await widget.api.triggerAgentRun(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name agent triggered successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to trigger $name agent: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tracking Configuration',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _keywordsCtrl,
            decoration: const InputDecoration(
              labelText: 'Tracked Keywords',
              hintText: 'e.g. flutter, dart, mobile',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _competitorsCtrl,
            decoration: const InputDecoration(
              labelText: 'Competitor Names',
              hintText: 'e.g. CompanyA, CompanyB',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _appIdsCtrl,
            decoration: const InputDecoration(
              labelText: 'App IDs (Google Play)',
              hintText: 'e.g. com.example.app',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Ollama Model',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedModel,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: _models
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _selectedModel = v!),
          ),
          const SizedBox(height: 24),
          Text('Manual Agent Runs',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ..._agents.map(
            (name) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text('Run ${name[0].toUpperCase()}${name.substring(1)} Agent'),
                onPressed: () => _triggerAgent(name),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
