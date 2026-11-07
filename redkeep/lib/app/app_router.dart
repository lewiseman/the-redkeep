import '../features/ai/presentation/ai_settings_page.dart';
import '../features/recall/presentation/recall_library_page.dart';
import '../features/notes/presentation/note_ai_sheet.dart';
import '../features/notes/presentation/note_ai_widgets.dart';
import '../features/diary/presentation/diary_photos_page.dart';
import '../features/flow/presentation/flow_search_page.dart';
import '../features/ai/application/ai_lifecycle.dart';
import '../features/sync/application/sync_providers.dart';
import 'writing_shell.dart';
import 'more_page.dart';
import '../features/flow/presentation/flow_page.dart';
import '../features/flow/presentation/thought_read_page.dart';
import '../features/flow/presentation/thought_edit_page.dart';
import '../features/diary/domain/diary_period.dart';
import '../features/diary/presentation/diary_calendar_page.dart';
import '../features/diary/presentation/diary_day_page.dart';
import '../features/diary/presentation/diary_entry_page.dart';
import '../features/diary/presentation/diary_edit_page.dart';
import '../features/diary/presentation/diary_title_page.dart';
import '../features/diary/presentation/diary_search_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/appearance/presentation/appearance_page.dart';
import '../features/onboarding/application/onboarding_controller.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/notes/presentation/note_page.dart';
import '../features/notes/presentation/website/note_website_page.dart';
import '../features/notes/presentation/notes_list_page.dart';
import 'bootstrap/bootstrap_controller.dart';
import 'bootstrap/startup_handoff.dart';
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
  ref.watch(writingSessionEpochProvider);
  final refresh = ValueNotifier(0);
  ref.listen(bootstrapControllerProvider, (_, _) => refresh.value++);
  ref.listen(onboardingControllerProvider, (_, _) => refresh.value++);
  // Routes on this navigator cover the shell, so they show no bottom bar. Every
  // descendant must name it too, or it would render on the shell's navigator,
  // underneath its own parent.
  final fullPage = GlobalKey<NavigatorState>();
  final router = GoRouter(
    navigatorKey: fullPage,
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
      ShellRoute(
        builder: (context, state, child) => AiLifecycleHost(
          child: WritingShell(location: state.uri.path, child: child),
        ),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => _page(state, const HomePage()),
            routes: [
              GoRoute(
                path: 'diary',
                pageBuilder: (context, state) =>
                    _page(state, const DiaryDayPage()),
                routes: [
                  GoRoute(
                    path: 'search',
                    pageBuilder: (context, state) =>
                        _page(state, const DiarySearchPage()),
                  ),
                  GoRoute(
                    path: 'calendar/:date',
                    pageBuilder: (context, state) => _page(
                      state,
                      DiaryCalendarPage(
                        key: ValueKey(state.uri.path),
                        selected: DiaryPeriod.tryParse(
                          state.pathParameters['date']!,
                        )!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':date/title',
                    pageBuilder: (context, state) => _page(
                      state,
                      DiaryTitlePage(
                        key: ValueKey(state.uri.path),
                        date: DiaryPeriod.tryParse(
                          state.pathParameters['date']!,
                        )!,
                      ),
                    ),
                  ),
                  // Days are reader state at /diary, not routes, so back from
                  // these pages returns to the one reader page.
                  GoRoute(
                    path: ':date/entries/:id/edit',
                    pageBuilder: (context, state) => _page(
                      state,
                      DiaryEditPage(
                        key: ValueKey(state.uri.path),
                        address: (
                          date: DiaryPeriod.tryParse(
                            state.pathParameters['date']!,
                          )!,
                          id: state.pathParameters['id']!,
                        ),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':date/entries/:id',
                    pageBuilder: (context, state) => _page(
                      state,
                      DiaryEntryPage(
                        key: ValueKey(state.uri.path),
                        address: (
                          date: DiaryPeriod.tryParse(
                            state.pathParameters['date']!,
                          )!,
                          id: state.pathParameters['id']!,
                        ),
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'photos',
                        pageBuilder: (context, state) => _page(
                          state,
                          DiaryPhotosPage(
                            address: (
                              date: DiaryPeriod.tryParse(
                                state.pathParameters['date']!,
                              )!,
                              id: state.pathParameters['id']!,
                            ),
                            edit: state.uri.queryParameters['edit'] == '1',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'notes',
                pageBuilder: (context, state) =>
                    _page(state, const NotesListPage()),
                routes: [
                  GoRoute(
                    path: 'ai-search',
                    pageBuilder: (context, state) => _page(
                      state,
                      NoteAiToolPage(
                        tool: NoteAiTool.search,
                        initialQuery: state.extra is String
                            ? state.extra as String
                            : '',
                      ),
                    ),
                  ),
                  // Editing is a state of this page, not a route of its own.
                  // It can be opened straight into editing, e.g. from the
                  // note's website.
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) => _page(
                      state,
                      NotePage(
                        key: ValueKey(state.pathParameters['id']),
                        id: state.pathParameters['id']!,
                        startEditing: state.extra == NoteOpen.edit,
                      ),
                    ),
                  ),
                  // A sibling, not a child: leaving the website returns to
                  // where it was opened from, not to the note.
                  GoRoute(
                    path: ':id/website',
                    pageBuilder: (context, state) => _page(
                      state,
                      NoteWebsitePage(
                        key: ValueKey(state.uri.path),
                        id: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'more',
                pageBuilder: (context, state) => _page(state, const MorePage()),
              ),
              GoRoute(
                path: 'flow',
                pageBuilder: (context, state) => _page(state, const FlowPage()),
                routes: [
                  GoRoute(
                    path: 'search',
                    pageBuilder: (context, state) =>
                        _page(state, const FlowSearchPage()),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: fullPage,
                    pageBuilder: (context, state) => _page(
                      state,
                      ThoughtReadPage(
                        key: ValueKey(state.uri.path),
                        id: state.pathParameters['id']!,
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: fullPage,
                        pageBuilder: (context, state) => _page(
                          state,
                          ThoughtEditPage(
                            key: ValueKey(state.uri.path),
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
                parentNavigatorKey: fullPage,
                pageBuilder: (context, state) =>
                    _page(state, const AppearancePage()),
                routes: [
                  GoRoute(
                    path: 'brain',
                    parentNavigatorKey: fullPage,
                    pageBuilder: (context, state) =>
                        _page(state, const AiSettingsPage()),
                    routes: [
                      GoRoute(
                        path: 'library',
                        parentNavigatorKey: fullPage,
                        pageBuilder: (context, state) =>
                            _page(state, const RecallLibraryPage()),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/startup',
        pageBuilder: (context, state) => const MaterialPage<void>(
          key: StartupHandoff.pageKey,
          child: StartupHandoff(child: StartupPage()),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => const MaterialPage<void>(
          key: StartupHandoff.pageKey,
          child: StartupHandoff(animateIn: true, child: OnboardingPage()),
        ),
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
    MaterialPage<void>(
      key: state.pageKey,
      child: _CoveredPageGuard(child: child),
    );

/// Android's predictive back gesture reaches every navigator's current page.
/// While a full page covers the shell, the shell's own page must refuse it, or
/// one gesture pops both and skips the page the reader came from.
class _CoveredPageGuard extends StatelessWidget {
  const _CoveredPageGuard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context).context;
    final covered = !(ModalRoute.isCurrentOf(navigator) ?? true);
    return PopScope(canPop: !covered, child: child);
  }
}
