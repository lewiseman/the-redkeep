import 'diary_answer_page.dart';
import '../../recall/application/recall_search.dart';
import '../../ai/application/ai_lifecycle.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../application/diary_providers.dart';
import '../domain/diary_period.dart';
import '../domain/diary_document.dart';
import 'diary_style.dart';
import 'diary_day_page.dart';
import 'diary_artwork.dart';
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
    setState(() {
      _request++;
      _submitted = query;
      _result = null;
      _stage = _SearchStage.searching;
    });
  }

  void _clear() {
    _request++;
    _draft.clear();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _submitted = '';
      _result = null;
      _stage = _SearchStage.opening;
    });
  }

  void _open(DiarySearchMatch match) {
    if (_returning) return;
    _returning = true;
    _focus.unfocus();
    context.go(diaryDayLocation(match.date), extra: DiaryDaySelection());
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
    if (_submitted.isNotEmpty) {
      final listings = ref.watch(diaryHybridSearchProvider(_submitted));
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
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Stack(
                    children: [
                      Positioned(
                        top: -165,
                        left: 0,
                        right: 0,
                        height: 420,
                        child: Opacity(
                          opacity: context.isDark ? .16 : .10,
                          child: DiaryArtwork(
                            assetKey: 'diary.header',
                            color: context.colors.primary,
                            colorBlendMode: BlendMode.color,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Reach opaque paper before the image ends at y=255.
                      // Covering that edge avoids a GPU mask seam on devices.
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0, .45, .72, 1],
                              colors: [
                                context.colors.surface.withValues(alpha: 0),
                                context.colors.surface.withValues(alpha: .65),
                                context.colors.surface,
                                context.colors.surface,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                          if (_submitted.isNotEmpty &&
                              ref.watch(aiEnabledProvider))
                            if (ref
                                    .watch(
                                      recallSearchProvider((
                                        query: _submitted,
                                        kind: 'diary',
                                      )),
                                    )
                                    .value
                                    ?.message
                                case final message?)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 6,
                                ),
                                child: Text(
                                  message,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
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
                                child: SizedBox(
                                  key: ValueKey('${_stage.name}-$_request'),
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
    if (_stage == _SearchStage.searching) {
      return DiarySearchLoading(
        key: const ValueKey('diary-search-loading'),
        query: _submitted,
        reduced: _reduced,
        compact: compactOpening,
      );
    }
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
        if (_stage == _SearchStage.results || _stage == _SearchStage.empty)
          TextButton.icon(
            key: const ValueKey('diary-search-ask'),
            icon: const Icon(Icons.computer_outlined),
            label: const Text('Ask your past'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DiaryAnswerPage(question: _submitted),
              ),
            ),
          ),
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
          const SizedBox(height: 12),
          const SizedBox(height: 16),
          DiarySearchPrompts(onSearch: _search, reduced: _reduced),
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
          child: Row(
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
                    suffixIcon: _draft.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: _clear,
                            icon: const Icon(Icons.close_rounded, size: 19),
                          ),
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      _clear();
                    } else {
                      setState(() {
                        _request++;
                        _submitted = '';
                        _result = null;
                        _stage = _SearchStage.opening;
                      });
                    }
                  },
                  onSubmitted: (_) => _search(),
                ),
              ),
              IconButton.filled(
                key: const ValueKey('diary-search-submit'),
                tooltip: 'Search journal',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: _draft.text.trim().isEmpty ? null : () => _search(),
                icon: const Icon(Icons.arrow_upward_rounded, size: 22),
              ),
              const SizedBox(width: 4),
            ],
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
