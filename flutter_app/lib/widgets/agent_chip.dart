import 'package:flutter/material.dart';
import '../theme.dart';

class AgentChip extends StatelessWidget {
  final String label;
  final String? statusLabel;

  const AgentChip({super.key, required this.label, this.statusLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentDim,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '~: ',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        if (statusLabel != null) ...[
          const SizedBox(width: 8),
          Text(statusLabel!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ],
    );
  }
}
