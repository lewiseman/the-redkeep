import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/cushion.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/watchlist_providers.dart';
import 'explore_view.dart';
import 'watch_explore_parts.dart';
import 'watch_widgets.dart';

/// Films and shows from TMDB, searched as the reader pauses typing. Before
/// anything is typed it is for browsing. The search itself sits in a
/// stitched cushion under the thumb, riding up with the keyboard.
class WatchSearchPage extends ConsumerStatefulWidget {
  const WatchSearchPage({super.key});

  static const debounce = Duration(milliseconds: 350);

  @override
  ConsumerState<WatchSearchPage> createState() => _WatchSearchPageState();
}

class _WatchSearchPageState extends ConsumerState<WatchSearchPage> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  String _asked = '';

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {});
    _timer?.cancel();
    _timer = Timer(WatchSearchPage.debounce, () {
      if (mounted) setState(() => _asked = value.trim());
    });
  }

  void _clear() {
    _timer?.cancel();
    _query.clear();
    setState(() => _asked = '');
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final configured = ref.watch(tmdbClientProvider) != null;
    final results = _asked.isEmpty
        ? null
        : ref.watch(watchSearchProvider(_asked));

    Widget page(List<Widget> slivers) => CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        const SliverToBoxAdapter(child: ExploreTop(title: 'Find something')),
        ...slivers,
        const SliverToBoxAdapter(
          child: SizedBox(height: searchDockClearance + 16),
        ),
      ],
    );
    Widget message(Widget child) => page([
      SliverToBoxAdapter(
        child: Padding(padding: const EdgeInsets.only(top: 40), child: child),
      ),
    ]);

    final body = !configured
        ? message(
            WatchMessage(
              title: 'Search needs TMDB',
              body: const WatchlistSetupException().toString(),
            ),
          )
        : switch (results) {
            null => const ExploreView(),
            AsyncData(:final value) when value.isEmpty => message(
              const WatchMessage(
                title: 'Nothing found',
                body: 'Try another title or spelling.',
              ),
            ),
            AsyncData(:final value) => page([
              ExploreHeading(
                '“$_asked”',
                note: value.length == 1
                    ? '1 result'
                    : '${value.length} results',
              ).sliver,
              ExploreMasonry(titles: value, aboveDock: true),
            ]),
            AsyncError(:final error) => message(
              WatchMessage(
                title: 'Search did not finish',
                body: error.toString(),
                action: TextButton(
                  onPressed: () => ref.invalidate(watchSearchProvider(_asked)),
                  child: const Text('Try again'),
                ),
              ),
            ),
            _ => message(const WatchLoading(label: 'Searching…')),
          };

    return Scaffold(
      backgroundColor: palette.ground,
      body: Stack(
        children: [
          Positioned.fill(child: body),
          const Positioned(top: 0, left: 0, right: 0, child: StatusFade()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SearchDock(
              controller: _query,
              focus: _focus,
              enabled: configured,
              onChanged: _changed,
              onSubmitted: (value) {
                _timer?.cancel();
                setState(() => _asked = value.trim());
              },
              onClear: _clear,
            ),
          ),
        ],
      ),
    );
  }
}

extension on Widget {
  Widget get sliver => SliverToBoxAdapter(child: this);
}

/// A stitched cushion holding the search: a glass bead that flew here from
/// the wall, the words, and a bead to clear them.
class _SearchDock extends StatelessWidget {
  const _SearchDock({
    required this.controller,
    required this.focus,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    final palette = MorePalette.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final bead = 48 * scale;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: CustomPaint(
            painter: CushionPainter(colors: cushion, radius: bead / 2 + 9),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Row(
                children: [
                  Hero(
                    tag: searchBeadTag,
                    child: GlassBead(
                      size: bead,
                      icon: Icons.search_rounded,
                      label: 'Search',
                      onTap: enabled ? focus.requestFocus : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focus,
                      enabled: enabled,
                      textInputAction: TextInputAction.search,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      style: TextStyle(color: palette.ink, fontSize: 16),
                      cursorColor: cushion.tint,
                      decoration: InputDecoration(
                        hintText: 'Search films and shows',
                        hintStyle: TextStyle(color: palette.muted),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => controller.text.isEmpty
                        ? const SizedBox(width: 6)
                        : Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: GlassBead(
                              size: bead - 8,
                              iconSize: 20,
                              fill: .12,
                              icon: Icons.close_rounded,
                              label: 'Clear',
                              onTap: onClear,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
