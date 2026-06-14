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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11.5),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (leftBorderColor != null)
                Container(width: 3, color: leftBorderColor),
              Expanded(
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(16),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
