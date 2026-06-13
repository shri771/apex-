import 'package:flutter/material.dart';
import '../theme.dart';

class SeverityBadge extends StatelessWidget {
  final String severity;
  final bool compact;

  const SeverityBadge({super.key, required this.severity, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (severity.toLowerCase()) {
      case 'high':
        color = AppColors.danger;
        label = compact ? 'High' : 'High Impact';
      case 'medium':
        color = AppColors.warning;
        label = compact ? 'Med' : 'Med Impact';
      default:
        color = AppColors.textMuted;
        label = compact ? 'Low' : 'Low Impact';
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
