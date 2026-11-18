import '../features/ai/presentation/ai_settings_page.dart';
import '../features/diary/presentation/diary_photos_page.dart';
import '../features/ai/application/ai_lifecycle.dart';
import '../features/sync/application/sync_providers.dart';
import 'writing_shell.dart';
import '../features/home_widgets/application/home_widget_sync.dart';
import '../features/home_widgets/presentation/home_widget_launch_page.dart';
import '../features/watchlist/domain/explore.dart';
import '../features/watchlist/domain/watch_title.dart';
import '../features/watchlist/presentation/explore_view.dart';
import '../features/watchlist/presentation/watch_search_page.dart';
import '../features/watchlist/presentation/watch_title_page.dart';
import '../features/watchlist/presentation/watchlist_page.dart';
import '../features/diary/domain/diary_period.dart';
import '../features/diary/presentation/diary_calendar_page.dart';
import '../features/diary/presentation/diary_entry_page.dart';
import '../features/diary/presentation/diary_edit_page.dart';
import '../features/diary/presentation/diary_title_page.dart';
import '../features/diary/presentation/diary_search_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/appearance/presentation/appearance_page.dart';
import '../features/onboarding/application/onboarding_controller.dart';
import '../features/onboarding/application/onboarding_restore.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/notes/presentation/note_chat_page.dart';
import '../features/notes/presentation/note_page.dart';
import '../features/notes/presentation/note_scan_page.dart';
import '../features/stock_photos/domain/stock_photo.dart';
import '../features/stock_photos/presentation/stock_photo_preview_page.dart';
import '../features/stock_photos/presentation/stock_photo_search_page.dart';
import 'bootstrap/bootstrap_controller.dart';
import 'bootstrap/startup_handoff.dart';
import 'bootstrap/startup_page.dart';
import 'main_tabs.dart';
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
GoRouter createAppRouter(Ref ref) {
  ref.watch(writingSessionEpochProvider);
  final refresh = ValueNotifier(0);
  ref.listen(bootstrapControllerProvider, (_, _) => refresh.value++);
  ref.listen(onboardingControllerProvider, (_, _) => refresh.value++);
  ref.listen(onboardingRestoreProvider, (_, _) => refresh.value++);
  // Routes on this navigator cover the shell, so they show no bottom bar. Every
  // descendant must name it too, or it would render on the shell's navigator,
  // underneath its own parent.
  final fullPage = GlobalKey<NavigatorState>();
  final router = GoRouter(
    navigatorKey: fullPage,
    initialLocation: validatedNavigationLocation(
      ref.read(initialNavigationLocationProvider),
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
      holdOnboarding: ref.read(onboardingRestoreProvider).holdsOnboarding,
    ),
    routes: [
      ShellRoute(
        builder: (context, state, child) => AiLifecycleHost(
          child: HomeWidgetSync(
            child: WritingShell(location: state.uri.path, child: child),
          ),
        ),
        routes: [
          // The tab roots share one page, so moving between them keeps it
          // and the pager slides instead of the navigator pushing.
          GoRoute(
            path: '/diary',
            pageBuilder: (context, state) => _tabs(0),
            routes: [
              GoRoute(
                path: 'search',
                pageBuilder: (context, state) =>
                    _page(state, const DiarySearchPage()),
              ),
              // Home screen widget launches; each replaces itself.
              GoRoute(
                path: 'write',
                pageBuilder: (context, state) => _page(
                  state,
                  const HomeWidgetLaunchPage(launch: WriteTodayLaunch()),
                ),
              ),
              GoRoute(
                path: 'today',
                pageBuilder: (context, state) => _page(
                  state,
                  const HomeWidgetLaunchPage(launch: DiaryDayLaunch()),
                ),
              ),
              GoRoute(
                path: 'day/:date',
                pageBuilder: (context, state) => _page(
                  state,
                  HomeWidgetLaunchPage(
                    key: ValueKey(state.uri.path),
                    launch: DiaryDayLaunch(
                      DiaryPeriod.tryParse(state.pathParameters['date']!),
                    ),
                  ),
                ),
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
                    date: DiaryPeriod.tryParse(state.pathParameters['date']!)!,
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
            path: '/notes',
            pageBuilder: (context, state) => _tabs(1),
            routes: [
              // Before `:id`: a home screen widget's new note. Opens one, then leaves.
              GoRoute(
                path: 'write',
                pageBuilder: (context, state) => _page(
                  state,
                  const HomeWidgetLaunchPage(launch: NewNoteLaunch()),
                ),
              ),
              // Editing is a state of this page, not a route of its own.
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => _page(
                  state,
                  NotePage(
                    key: ValueKey(state.pathParameters['id']),
                    id: state.pathParameters['id']!,
                  ),
                ),
              ),
              // Scanning returns its kept result to the note that opened it.
              GoRoute(
                path: ':id/scan',
                pageBuilder: (context, state) => _page(
                  state,
                  NoteScanPage(
                    key: ValueKey(state.uri.path),
                    id: state.pathParameters['id']!,
                  ),
                ),
              ),
              // The Maester's conversation about this note. A sibling, so
              // leaving returns to the note.
              GoRoute(
                path: ':id/maester',
                pageBuilder: (context, state) => _page(
                  state,
                  NoteChatPage(
                    key: ValueKey(state.uri.path),
                    id: state.pathParameters['id']!,
                  ),
                ),
              ),
              // Stock photos for the note's background. Full page, so they
              // cover the background sheet that opened them; each pops its
              // chosen `note_media/` path back to the caller.
              GoRoute(
                path: ':id/background',
                parentNavigatorKey: fullPage,
                pageBuilder: (context, state) => _page(
                  state,
                  StockPhotoSearchPage(noteId: state.pathParameters['id']!),
                ),
                routes: [
                  GoRoute(
                    path: 'photo',
                    parentNavigatorKey: fullPage,
                    pageBuilder: (context, state) => _page(
                      state,
                      // The photo travels as `extra`; without it (after
                      // the app was restarted) search again instead.
                      state.extra is StockPhoto
                          ? StockPhotoPreviewPage(
                              photo: state.extra! as StockPhoto,
                            )
                          : StockPhotoSearchPage(
                              noteId: state.pathParameters['id']!,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(path: '/more', pageBuilder: (context, state) => _tabs(2)),
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => _tabs(0),
            routes: [
              GoRoute(
                path: 'watchlist',
                parentNavigatorKey: fullPage,
                pageBuilder: (context, state) =>
                    _page(state, const WatchlistPage()),
                routes: [
                  GoRoute(
                    path: 'search',
                    parentNavigatorKey: fullPage,
                    pageBuilder: (context, state) =>
                        _page(state, const WatchSearchPage()),
                  ),
                  GoRoute(
                    path: 'mood/:id',
                    parentNavigatorKey: fullPage,
                    pageBuilder: (context, state) => _page(
                      state,
                      WatchMoodPage(
                        key: ValueKey(state.uri.path),
                        mood: Mood.byId(state.pathParameters['id'])!,
                      ),
                    ),
                  ),
                  // Validated by navigationRedirect before it gets here.
                  GoRoute(
                    path: ':media/:tmdb',
                    parentNavigatorKey: fullPage,
                    pageBuilder: (context, state) => _page(
                      state,
                      WatchTitlePage(
                        key: ValueKey(state.uri.path),
                        watchKey: WatchKey.fromRoute(
                          state.pathParameters['media'],
                          state.pathParameters['tmdb'],
                        )!,
                      ),
                    ),
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

/// Every tab root resolves to this one page; see [MainTabs].
const _mainTabsKey = ValueKey('main-tabs');

MaterialPage<void> _tabs(int index) => MaterialPage<void>(
  key: _mainTabsKey,
  child: _CoveredPageGuard(child: MainTabs(index: index)),
);

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
