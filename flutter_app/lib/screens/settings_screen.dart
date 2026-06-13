import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../widgets/agent_chip.dart';
import '../widgets/section_card.dart';

class SettingsScreen extends StatefulWidget {
  final ApiService api;
  const SettingsScreen({super.key, required this.api});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Intelligence Context
  final _businessDescCtrl = TextEditingController();
  final _productDescCtrl = TextEditingController();
  final _icpKeywordsCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  String _geography = 'IN';

  // Agent Sources
  final _competitorsCtrl = TextEditingController();
  final _appIdsCtrl = TextEditingController();
  final _productKeywordsCtrl = TextEditingController();

  // System
  String _selectedModel = 'phi3:mini';
  bool _saving = false;
  bool _pipelineRunning = false;

  static const _models = ['phi3:mini', 'llama3.2:3b', 'gemma2:2b'];
  static const _geos = ['IN', 'US', 'UK', 'SG', 'Global'];
  static const _agents = [
    ('competitor_discovery', 'Competitor Discovery', Icons.search),
    ('market_trends', 'Market Trends', Icons.trending_up),
    ('competitor_intelligence', 'Competitor Intelligence', Icons.radar),
    ('demand_lead_signals', 'Demand & Leads', Icons.bolt),
    ('marketing', 'Marketing (legacy)', Icons.campaign),
    ('product', 'Product (legacy)', Icons.star),
    ('sales', 'Sales (legacy)', Icons.business),
    ('strategy', 'Strategy', Icons.auto_stories),
    ('alerts_agent', 'Alerts Agent', Icons.notifications),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await widget.api.getSettings();
    if (!mounted) return;
    setState(() {
      _businessDescCtrl.text = settings['user_business_description'] ?? '';
      _productDescCtrl.text = settings['user_product_description'] ?? '';
      _icpKeywordsCtrl.text = settings['user_icp_keywords'] ?? '';
      _industryCtrl.text = settings['trends_industry'] ?? '';
      final geo = settings['trends_geography'];
      if (geo != null && _geos.contains(geo)) _geography = geo;
      _competitorsCtrl.text = settings['sales_companies'] ?? '';
      _appIdsCtrl.text = settings['product_app_ids'] ?? '';
      _productKeywordsCtrl.text = settings['product_keywords'] ?? '';
      final model = settings['ollama_model'];
      if (model != null && _models.contains(model)) _selectedModel = model;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      await Future.wait([
        widget.api.saveSetting('user_business_description', _businessDescCtrl.text.trim()),
        widget.api.saveSetting('user_product_description', _productDescCtrl.text.trim()),
        widget.api.saveSetting('user_icp_keywords', _icpKeywordsCtrl.text.trim()),
        widget.api.saveSetting('trends_industry', _industryCtrl.text.trim()),
        widget.api.saveSetting('trends_geography', _geography),
        widget.api.saveSetting('sales_companies', _competitorsCtrl.text.trim()),
        widget.api.saveSetting('product_app_ids', _appIdsCtrl.text.trim()),
        widget.api.saveSetting('product_keywords', _productKeywordsCtrl.text.trim()),
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

  Future<void> _runPipeline() async {
    setState(() => _pipelineRunning = true);
    try {
      await widget.api.triggerPipeline();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pipeline triggered — agents are running')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to trigger pipeline')),
      );
    } finally {
      if (mounted) setState(() => _pipelineRunning = false);
    }
  }

  Future<void> _triggerAgent(String name) async {
    try {
      await widget.api.triggerAgentRun(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name triggered')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to trigger $name')),
      );
    }
  }

  @override
  void dispose() {
    _businessDescCtrl.dispose();
    _productDescCtrl.dispose();
    _icpKeywordsCtrl.dispose();
    _industryCtrl.dispose();
    _competitorsCtrl.dispose();
    _appIdsCtrl.dispose();
    _productKeywordsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          const AgentChip(label: 'SETTINGS'),
          const SizedBox(height: 12),
          const Text('Intelligence Settings',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 24)),
          const SizedBox(height: 24),
          _sectionHeader('Intelligence Context', Icons.psychology_outlined),
          const SizedBox(height: 4),
          const Text(
            'Describe your business to the agents. The more context you provide, the better they perform.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Product / Business Description'),
          const SizedBox(height: 6),
          TextField(
            controller: _businessDescCtrl,
            maxLines: 5,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'e.g. We build a B2B SaaS tool that helps construction project managers track subcontractor delays. Our customers are mid-sized GCs in India spending \$2-5K/month on project management tools.',
            ),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Additional Context'),
          const SizedBox(height: 6),
          TextField(
            controller: _productDescCtrl,
            maxLines: 3,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Known competitors, recent funding, market position, key differentiators, things agents should know…',
            ),
          ),
          const SizedBox(height: 14),
          _fieldLabel('ICP Keywords'),
          const SizedBox(height: 6),
          TextField(
            controller: _icpKeywordsCtrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'e.g. construction delay, subcontractor management, site coordination',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Industry'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _industryCtrl,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                          hintText: 'e.g. construction tech'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Geography'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _geography,
                      dropdownColor: AppColors.surfaceHigh,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(),
                      items: _geos
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _geography = v ?? _geography),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _sectionHeader('Agent Sources', Icons.link_outlined),
          const SizedBox(height: 14),
          _fieldLabel('Competitors to Track (comma-separated)'),
          const SizedBox(height: 6),
          TextField(
            controller: _competitorsCtrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
                hintText: 'e.g. Procore, PlanGrid, Buildertrend'),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Play Store App IDs (comma-separated)'),
          const SizedBox(height: 6),
          TextField(
            controller: _appIdsCtrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
                hintText: 'e.g. com.procore.mobile, com.fieldwire.app'),
          ),
          const SizedBox(height: 14),
          _fieldLabel('HN / Reddit Keywords (comma-separated)'),
          const SizedBox(height: 6),
          TextField(
            controller: _productKeywordsCtrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
                hintText: 'e.g. construction software, project management mobile'),
          ),
          const SizedBox(height: 28),
          _sectionHeader('System', Icons.settings_outlined),
          const SizedBox(height: 14),
          _fieldLabel('Ollama Model'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedModel,
            dropdownColor: AppColors.surfaceHigh,
            style:
                const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(),
            items: _models
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) =>
                setState(() => _selectedModel = v ?? _selectedModel),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _saving ? null : _saveSettings,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.bg))
                  : const Text('Save All Settings',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _pipelineRunning ? null : _runPipeline,
              icon: _pipelineRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent))
                  : const Icon(Icons.play_circle_outline, size: 18),
              label: Text(
                  _pipelineRunning ? 'Running…' : 'Run Full Pipeline'),
            ),
          ),
          const SizedBox(height: 28),
          _sectionHeader('Individual Agent Runs', Icons.smart_toy_outlined),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(
              children: _agents.map((agent) {
                final (name, label, icon) = agent;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(icon, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(label,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                      ),
                      GestureDetector(
                        onTap: () => _triggerAgent(name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.accentDim,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.accent.withOpacity(0.3)),
                          ),
                          child: const Text('Run',
                              style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 16),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: 'monospace',
                letterSpacing: 0.5)),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Text(label,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500));
  }
}
