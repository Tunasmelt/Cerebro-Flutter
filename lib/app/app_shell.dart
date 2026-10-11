import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/widgets/app_bottom_nav.dart';
import '../features/chat/data/chat_controller.dart';
import '../features/graph/data/graph_pulse.dart';
import '../features/graph/data/graph_api.dart';
import 'app_routes.dart';

/// Real app shell for Milestone 1.2: wraps the five top-level
/// destinations (Docs/Chat/Graph/Board/Settings) in a
/// [StatefulShellRoute.indexedStack] via go_router, so each branch
/// keeps its own navigation stack and scroll position when switching
/// tabs, matching the mockups' persistent bottom nav.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(int index) {
      if (index != navigationShell.currentIndex) {
        HapticFeedback.selectionClick();
      }
      final enteringGraph = index == 2 && navigationShell.currentIndex != 2;
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
      if (enteringGraph) {
        // The branch is lazy: replay only after its listener is mounted.
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            await ref.read(graphProvider.future);
          } catch (_) {
            return; // The graph presents its own load error.
          }
          if (!context.mounted ||
              GoRouter.of(context).routeInformationProvider.value.uri.path !=
                  AppRoutes.graph) {
            return;
          }
          final chat = ref.read(chatControllerProvider);
          if (!chat.loading && !chat.busy && chat.loadError == null) {
            ref
                .read(graphPulseProvider.notifier)
                .replay(replaySteps(chat.messages));
          }
        });
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        return Scaffold(
          body: wide
              ? Row(
                  children: [
                    AppNavigationRail(
                      currentIndex: navigationShell.currentIndex,
                      onTap: select,
                    ),
                    Expanded(child: navigationShell),
                  ],
                )
              : navigationShell,
          bottomNavigationBar: wide
              ? null
              : AppBottomNav(
                  currentIndex: navigationShell.currentIndex,
                  onTap: select,
                ),
        );
      },
    );
  }
}
