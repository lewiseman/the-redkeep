import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/presentation/rendering_policy.dart';
import '../features/appearance/presentation/appearance_page.dart';
import 'home_page.dart';
import 'route_not_found_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});

GoRouter createAppRouter({String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _page(context, state, const HomePage()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            _page(context, state, const AppearancePage()),
      ),
    ],
    errorPageBuilder: (context, state) =>
        _page(context, state, const RouteNotFoundPage()),
  );
}

CustomTransitionPage<void> _page(
  BuildContext context,
  GoRouterState state,
  Widget child,
) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: RenderingPolicyScope.of(context).duration,
  reverseTransitionDuration: RenderingPolicyScope.of(context).duration,
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      RenderingPolicyScope.of(context).animate
      ? FadeTransition(opacity: animation, child: child)
      : child,
);
