import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.color,
    this.valueMaxLines = 2,
    this.fitValue = false,
    this.isPrimary = false,
    this.elevation = 1,
  });

  final String title;
  final String value;
  final Color? color;
  final int valueMaxLines;
  final bool fitValue;
  final bool isPrimary;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final valueStyle = textTheme.titleLarge?.copyWith(
      fontSize: isPrimary ? 26 : 22,
      color: color ?? colorScheme.onSurface,
      fontWeight: FontWeight.w700,
      height: 1.15,
    );

    Widget valueWidget = Text(
      value,
      maxLines: valueMaxLines,
      overflow: TextOverflow.ellipsis,
      style: valueStyle,
    );

    if (fitValue) {
      valueWidget = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          maxLines: 1,
          style: valueStyle,
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: elevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      surfaceTintColor: colorScheme.surfaceTint,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.topLeft, child: valueWidget),
            ],
          ),
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.color,
    this.valueMaxLines = 2,
    this.fitValue = false,
    this.isPrimary = false,
    this.elevation = 1,
  });

  final String title;
  final String value;
  final Color? color;
  final int valueMaxLines;
  final bool fitValue;
  final bool isPrimary;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return StatCard(
      title: title,
      value: value,
      color: color,
      valueMaxLines: valueMaxLines,
      fitValue: fitValue,
      isPrimary: isPrimary,
      elevation: elevation,
    );
  }
}
