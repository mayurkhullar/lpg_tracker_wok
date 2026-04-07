import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EntrySummaryCard extends StatelessWidget {
  const EntrySummaryCard({
    super.key,
    required this.date,
    required this.gasUsedText,
    required this.gasCostText,
    required this.salesText,
    required this.gasUsedColor,
    this.movementText,
    this.trailing,
    this.onTap,
    this.onDelete,
  });

  final DateTime date;
  final String gasUsedText;
  final String gasCostText;
  final String salesText;
  final Color gasUsedColor;
  final String? movementText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMd().format(date),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Gas Used: $gasUsedText',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: gasUsedColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gas Cost: $gasCostText • Sales: $salesText',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (movementText != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          movementText!,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null || onDelete != null) ...[
                const SizedBox(width: 8),
                Column(
                  children: [
                    if (trailing != null) trailing!,
                    if (onDelete != null)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            onDelete!.call();
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete entry'),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
