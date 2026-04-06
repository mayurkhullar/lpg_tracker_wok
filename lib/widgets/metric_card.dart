import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.color,
    this.valueMaxLines = 2,
    this.minHeight = 118,
    this.fitValue = false,
  });

  final String title;
  final String value;
  final Color? color;
  final int valueMaxLines;
  final double minHeight;
  final bool fitValue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final valueStyle = textTheme.titleLarge?.copyWith(
      color: color ?? Theme.of(context).colorScheme.onSurface,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              valueWidget,
            ],
          ),
        ),
      ),
    );
  }
}
