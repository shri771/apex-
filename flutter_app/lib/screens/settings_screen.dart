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
  bool _saving = false;

  static const _models = ['phi3:mini', 'llama3.2:3b', 'gemma2:2b'];
  static const _agents = ['marketing', 'product', 'sales', 'strategy'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await widget.api.getSettings();
    if (!mounted) return;
    setState(() {
      _keywordsCtrl.text = settings['product_keywords'] ?? '';
      _competitorsCtrl.text = settings['sales_companies'] ?? '';
      _appIdsCtrl.text = settings['product_app_ids'] ?? '';
      final model = settings['ollama_model'];
      if (model != null && _models.contains(model)) {
        _selectedModel = model;
      }
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      await Future.wait([
        widget.api.saveSetting('product_keywords', _keywordsCtrl.text.trim()),
        widget.api.saveSetting('sales_companies', _competitorsCtrl.text.trim()),
        widget.api.saveSetting('product_app_ids', _appIdsCtrl.text.trim()),
        widget.api.saveSetting('ollama_model', _selectedModel),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
            onChanged: (v) => setState(() => _selectedModel = v ?? _selectedModel),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _saveSettings,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save Settings'),
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
