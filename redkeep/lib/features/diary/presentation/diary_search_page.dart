import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../application/diary_providers.dart';
import '../domain/diary_period.dart';
import '../domain/diary_document.dart';
import 'diary_style.dart';
import 'diary_day_page.dart';
import 'diary_sky.dart';
import 'diary_search_opening.dart';
import 'diary_search_loading.dart';
import 'diary_search_paper.dart';

class DiarySearchMatch {
  const DiarySearchMatch({required this.date, required this.excerpt});
  final DiaryPeriod date;
  final String excerpt;
}

class DiarySearchResult {
  const DiarySearchResult({required this.matches});
  final List<DiarySearchMatch> matches;
}

enum _SearchStage { opening, searching, results, empty, error }

/// Full-screen journal search. Selecting a memory returns its civil diary date.
class DiarySearchPage extends ConsumerStatefulWidget {
  const DiarySearchPage({super.key});

  @override
  ConsumerState<DiarySearchPage> createState() => _DiarySearchPageState();
}

class _DiarySearchPageState extends ConsumerState<DiarySearchPage> {
  final _draft = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  _SearchStage _stage = _SearchStage.opening;
  DiarySearchResult? _result;
  String _submitted = '';
  int _request = 0;
  bool _returning = false;
  bool get _reduced =>
      !RenderingPolicyScope.of(context).animate ||
      RenderingPolicyScope.of(context).simplerEffects;

  void _search([String? prompt]) {
    final query = (prompt ?? _draft.text).trim();
    if (query.isEmpty) return;
    _draft.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _focus.unfocus();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_stage == _SearchStage.error) {
      for (final entry
          in ref.read(diarySearchProvider(query)).value ?? <DiaryListing>[]) {
        ref.invalidate(diaryDocumentProvider(entry.id));
      }
    }
    ref.invalidate(diarySearchProvider(query));
    // History is a convenience: a failed write never blocks the search.
    unawaited(
      ref.read(diarySearchHistoryProvider).record(query).catchError((_) {}),
    );
    setState(() {
      _request++;
      _submitted = query;
      _result = null;
      _stage = _SearchStage.searching;
    });
  }

  void _clear() {
    _draft.clear();
    _showOpening();
  }

  /// Leaves a search for the opening page. Already there, nothing rebuilds,
  /// so typing never replays the opening's entrance.
  void _showOpening() {
    if (_submitted.isEmpty) return;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _request++;
      _submitted = '';
      _result = null;
      _stage = _SearchStage.opening;
    });
  }

  void _open(DiarySearchMatch match) {
    if (_returning) return;
    _returning = true;
    _focus.unfocus();
    openDiaryDay(context, match.date, selection: DiaryDaySelection());
  }

  @override
  void dispose() {
    _request++;
    _draft.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kept loaded while the page is open, so returning to the opening shows
    // recent searches at once instead of popping them in a frame later.
    ref.listen(diaryRecentSearchesProvider, (_, _) {});
    if (_submitted.isNotEmpty) {
      final listings = ref.watch(diarySearchProvider(_submitted));
      final today = DiaryPeriod.fromComponents(ref.read(diaryClockProvider)());
      final matches = (listings.value ?? <DiaryListing>[])
          .where((entry) => entry.date.hasStarted(today.calendarDate))
          .toList();
      final documents = [
        for (final entry in matches) ref.watch(diaryDocumentProvider(entry.id)),
      ];
      if (listings.hasError || documents.any((d) => d.hasError)) {
        _stage = _SearchStage.error;
      } else if (listings.isLoading || documents.any((d) => d.isLoading)) {
        _stage = _SearchStage.searching;
      } else {
        _result = DiarySearchResult(
          matches: [
            for (final document in documents)
              if (document.value case final opened?)
                if (opened.available)
                  DiarySearchMatch(
                    date: opened.entry!.date,
                    excerpt: opened.entry!.text.body,
                  ),
          ],
        );
        _stage = _result!.matches.isEmpty
            ? _SearchStage.empty
            : _SearchStage.results;
      }
    }
    return Semantics(
      namesRoute: true,
      label: 'Search journal',
      child: Scaffold(
        backgroundColor: context.colors.surface,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 320,
              // The day page's sky, faintly, fading into the paper.
              child: const ExcludeSemantics(
                child: IgnorePointer(child: DiarySky(strength: .5)),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact =
                          constraints.maxHeight < 420 ||
                          MediaQuery.viewInsetsOf(context).bottom > 0;
                      return Column(
                        children: [
                          _header(),
                          Expanded(
                            child: SingleChildScrollView(
                              key: const ValueKey('diary-search-scroll'),
                              controller: _scroll,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                20,
                                24,
                                20,
                              ),
                              child: AnimatedSwitcher(
                                duration: _reduced
                                    ? Duration.zero
                                    : const Duration(milliseconds: 240),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    for (final child in previous)
                                      ExcludeSemantics(
                                        child: IgnorePointer(child: child),
                                      ),
                                    ?current,
                                  ],
                                ),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: _reduced
                                              ? Offset.zero
                                              : const Offset(0, .025),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                // One transition per search: loading and its
                                // result share a key and swap inside.
                                child: SizedBox(
                                  key: ValueKey(
                                    '${_submitted.isEmpty ? 'opening' : 'search'}-$_request',
                                  ),
                                  width: double.infinity,
                                  child: _body(
                                    compactOpening: constraints.maxHeight < 680,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _composer(compact: compact),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 20, 10),
    child: Row(
      children: [
        BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/diary'),
        ),
      ],
    ),
  );

  Widget _body({required bool compactOpening}) {
    if (_stage == _SearchStage.opening) {
      return DiarySearchOpening(
        onSearch: _search,
        reduced: _reduced,
        compact: compactOpening,
      );
    }
    return AnimatedSwitcher(
      duration: _reduced ? Duration.zero : const Duration(milliseconds: 200),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [
          for (final child in previous)
            ExcludeSemantics(child: IgnorePointer(child: child)),
          ?current,
        ],
      ),
      child: _stage == _SearchStage.searching
          ? DiarySearchLoading(
              key: const ValueKey('diary-search-loading'),
              query: _submitted,
              reduced: _reduced,
              compact: compactOpening,
            )
          : KeyedSubtree(
              key: ValueKey('diary-search-outcome-${_stage.name}'),
              child: _outcome(),
            ),
    );
  }

  Widget _outcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          '“$_submitted”',
          style: TextStyle(
            fontSize: 23,
            height: 1.35,
            letterSpacing: -.6,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 24),
        if (_stage == _SearchStage.error)
          _message(
            title: 'The pages need a moment.',
            message:
                'Something interrupted this search. Try your question again.',
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: FilledButton.tonal(
                  key: const ValueKey('diary-search-retry'),
                  onPressed: () => _search(_submitted),
                  child: const Text('Try again'),
                ),
              ),
            ),
          ),
        if (_stage == _SearchStage.empty) ...[
          _message(
            title: 'No moments found yet.',
            message: 'Every keyword must match the saved text. Try a person, a feeling, or a few different words.',
          ),
        ],
        if (_stage == _SearchStage.results) ...[
          Text(
            '${_result!.matches.length} '
            '${_result!.matches.length == 1 ? 'moment' : 'moments'} to return to',
            key: const ValueKey('diary-search-count'),
            style: TextStyle(
              fontSize: 12,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _result!.matches.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _MemoryCard(
              key: ValueKey('diary-search-match-$i'),
              match: _result!.matches[i],
              variant: i,
              onTap: () => _open(_result!.matches[i]),
            ),
          ],
        ],
      ],
    );
  }

  Widget _message({required String title, String? message, Widget? child}) =>
      DiarySearchPaper(
        child: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 21,
                  height: 1.4,
                  letterSpacing: -.5,
                  color: context.colors.onSurface,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
              ?child,
            ],
          ),
        ),
      );

  Widget _composer({required bool compact}) => Padding(
    padding: EdgeInsets.fromLTRB(20, 10, 20, compact ? 8 : 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DiarySearchPaper(
          padding: const EdgeInsets.all(6),
          // Only the clear and submit buttons follow the draft; the rest of
          // the page doesn't rebuild while typing.
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _draft,
            builder: (context, draft, _) => Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('diary-search-input'),
                    controller: _draft,
                    inputFormatters: [LengthLimitingTextInputFormatter(256)],
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: compact ? 1 : 3,
                    textInputAction: TextInputAction.search,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: context.colors.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'What do you remember?',
                      hintStyle: TextStyle(
                        color: context.colors.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      suffixIcon: draft.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: _clear,
                              icon: const Icon(Icons.close_rounded, size: 19),
                            ),
                    ),
                    // Editing leaves a finished search for the opening page.
                    onChanged: (_) => _showOpening(),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                IconButton.filled(
                  key: const ValueKey('diary-search-submit'),
                  tooltip: 'Search journal',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: draft.text.trim().isEmpty ? null : () => _search(),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 22),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 12),
          Text(
            'A few words can bring a day back.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    super.key,
    required this.match,
    required this.variant,
    required this.onTap,
  });

  final DiarySearchMatch match;
  final int variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paper = [
      DiaryPaperPreset.paper,
      DiaryPaperPreset.sage,
      DiaryPaperPreset.lavender,
    ][variant % 3].resolveColors(context.colors);
    final date = match.date.label(Localizations.localeOf(context).toString());
    return DiarySearchPaper(
      color: paper.background,
      variant: variant,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(date, style: TextStyle(fontSize: 11, color: paper.secondary)),
          const SizedBox(height: 12),
          Text(
            match.excerpt,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, height: 1.6, color: paper.secondary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Open day',
                  style: TextStyle(fontSize: 12, color: paper.foreground),
                ),
              ),
              Icon(Icons.north_east_rounded, size: 17, color: paper.foreground),
            ],
          ),
        ],
      ),
    );
  }
}
