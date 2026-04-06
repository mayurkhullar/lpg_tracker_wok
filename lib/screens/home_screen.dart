import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../widgets/sync_status_badge.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'entry_screen.dart';
import 'purchases_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  static const _tabs = [
    DashboardScreen(),
    EntryScreen(),
    AnalyticsScreen(),
    PurchasesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final syncStatusAsync = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gas Consumption Tracker'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: syncStatusAsync.when(
              data: (status) => SyncStatusBadge(status: status),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SyncStatusBadge(status: SyncStatus.offline),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Entry'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.shopping_basket_outlined), label: 'Purchases'),
        ],
      ),
    );
  }
}
