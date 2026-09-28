import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_notifier.dart';
import '../features/auth/data/auth_state.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/documents/presentation/documents_screen.dart';
import '../features/graph/presentation/graph_screen.dart';
import '../features/kanban/presentation/board_screen.dart';
import '../features/playground/presentation/playground_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';

export 'app_routes.dart';


const _authRoutes = {AppRoutes.signIn, AppRoutes.signUp};

/// Pure so the redirect decision is unit-testable without a [BuildContext]
/// or a running router — see `test/app/router_redirect_test.dart`.
String? computeRedirect({
  required AuthState authState,
  required String matchedLocation,
}) {
  final onAuthRoute = _authRoutes.contains(matchedLocation);
  if (authState is Authenticated) {
    return onAuthRoute ? AppRoutes.documents : null;
  }
  return onAuthRoute ? null : AppRoutes.signIn;
}

/// Bridges Riverpod's [authNotifierProvider] to go_router's
/// [Listenable]-based `refreshListenable`, so a sign-in/sign-out re-runs
/// the redirect without any manual `context.go` call from the screens.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authNotifierProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _AuthRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: AppRoutes.documents,
    refreshListenable: refreshListenable,
    // Any location no route matches (a stale or repeated
    // `cerebro://confirm-email` link, a mistyped deep link) falls back to
    // the app instead of go_router's default "Page Not Found" screen; the
    // redirect guard then sends a signed-out user on to Sign in.
    onException: (context, state, router) => router.go(AppRoutes.documents),
    redirect: (context, state) => computeRedirect(
      authState: ref.read(authNotifierProvider),
      matchedLocation: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.documents,
                builder: (context, state) => const DocumentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.chat,
                builder: (context, state) => const ChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.graph,
                builder: (context, state) => const GraphScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.board,
                builder: (context, state) => const BoardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.playground,
                builder: (context, state) => const PlaygroundScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
