import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/widgets/app_bottom_nav.dart';

/// Real app shell for Milestone 1.2: wraps the six top-level
/// destinations (Docs/Chat/Graph/Board/Play/Settings) in a
/// [StatefulShellRoute.indexedStack] via go_router, so each branch
/// keeps its own navigation stack and scroll position when switching
/// tabs, matching the mockups' persistent bottom nav.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
