import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/appearance/presentation/appearance_page.dart';
import '../features/onboarding/application/onboarding_controller.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/notes/presentation/notes_list_page.dart';
import '../features/notes/presentation/note_read_page.dart';
import '../features/notes/presentation/note_edit_page.dart';
import 'bootstrap/bootstrap_controller.dart';
import 'bootstrap/startup_page.dart';
import 'home_page.dart';
import 'navigation_destination.dart';
import 'navigation_route_information.dart';
import 'route_not_found_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) => createAppRouter(ref));

final navigationRouteInformationProvider = Provider<NavigationRouteInformation>(
  (ref) {
    final information = NavigationRouteInformation(
      ref.watch(appRouterProvider).routeInformationProvider,
    );
    return information;
  },
);

/// One router per scope. Refreshes change redirects without rebuilding history.
GoRouter createAppRouter(Ref ref, {String? initialLocation}) {
  final refresh = ValueNotifier(0);
  ref.listen(bootstrapControllerProvider, (_, _) => refresh.value++);
  ref.listen(onboardingControllerProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: validatedNavigationLocation(
      initialLocation ??
          WidgetsBinding.instance.platformDispatcher.defaultRouteName,
    ),
    overridePlatformDefaultLocation: true,
    refreshListenable: refresh,
    redirect: (context, state) => navigationRedirect(
      state.uri,
      startupReady:
          ref.read(bootstrapControllerProvider).stage == BootstrapStage.ready &&
          ref.read(onboardingControllerProvider).complete != null,
      onboardingComplete:
          ref.read(onboardingControllerProvider).complete == true,
    ),
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _page(state, const HomePage()),
        routes: [
          GoRoute(
            path: 'notes',
            pageBuilder: (context, state) =>
                _page(state, const NotesListPage()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => _page(
                  state,
                  NoteReadPage(
                    key: ValueKey(state.pathParameters['id']),
                    id: state.pathParameters['id']!,
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    pageBuilder: (context, state) => _page(
                      state,
                      NoteEditPage(
                        key: ValueKey(state.pathParameters['id']),
                        id: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'settings',
            pageBuilder: (context, state) =>
                _page(state, const AppearancePage()),
          ),
        ],
      ),
      GoRoute(
        path: '/startup',
        pageBuilder: (context, state) => _page(state, const StartupPage()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _page(state, const OnboardingPage()),
      ),
      GoRoute(
        path: '/unavailable',
        pageBuilder: (context, state) =>
            _page(state, const RouteNotFoundPage()),
      ),
    ],
    errorPageBuilder: (context, state) =>
        _page(state, const RouteNotFoundPage()),
  );
  ref.onDispose(router.dispose);
  ref.onDispose(refresh.dispose);
  return router;
}

MaterialPage<void> _page(GoRouterState state, Widget child) =>
    MaterialPage<void>(key: state.pageKey, child: child);
