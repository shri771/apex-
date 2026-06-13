import 'package:flutter/material.dart';
import '../theme.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final Color? leftBorderColor;
  final EdgeInsets? padding;

  const SectionCard({
    super.key,
    required this.child,
    this.leftBorderColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: const BorderSide(color: AppColors.border),
          right: const BorderSide(color: AppColors.border),
          bottom: const BorderSide(color: AppColors.border),
          left: BorderSide(
            color: leftBorderColor ?? AppColors.border,
            width: leftBorderColor != null ? 3 : 1,
          ),
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
