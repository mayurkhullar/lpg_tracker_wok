import 'package:flutter/material.dart';

import '../providers/app_providers.dart';

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key, required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SyncStatus.offline => ('Offline', Colors.grey),
      SyncStatus.syncing => ('Syncing', Colors.orange),
      SyncStatus.synced => ('Synced', Colors.blue),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
