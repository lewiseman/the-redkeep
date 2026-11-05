import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../application/appearance_typography.dart';
import '../data/font_preview_loader.dart';
import '../domain/appearance_fonts.dart';

/// A short, tasteful starting point for each role, ahead of the full catalog.
const fontSuggestions = <FontRole, List<String>>{
  FontRole.journal: [
    'Poppins',
    'Inter',
    'Nunito',
    'DM Sans',
    'Source Sans 3',
    'Lato',
  ],
  FontRole.diaryTitle: [
    'Caveat',
    'Kalam',
    'Patrick Hand',
    'Shadows Into Light',
    'Playfair Display',
    'Fraunces',
  ],
  FontRole.diaryBody: [
    'Literata',
    'Lora',
    'Newsreader',
    'Source Serif 4',
    'Merriweather',
    'Crimson Pro',
  ],
};

Future<void> showFontPicker(
  BuildContext context, {
  required String title,
  required FontRole role,
  required String selectedFont,
  required Future<void> Function(String) onSelected,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
  sheetAnimationStyle: RenderingPolicyScope.of(context).reducedMotion
      ? AnimationStyle.noAnimation
      : null,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: FractionallySizedBox(
      heightFactor: .88,
      child: _FontPicker(
        title: title,
        role: role,
        selectedFont: selectedFont,
        onSelected: onSelected,
      ),
    ),
  ),
);

class _FontPicker extends StatefulWidget {
  const _FontPicker({
    required this.title,
    required this.role,
    required this.selectedFont,
    required this.onSelected,
  });
  final String title;
  final FontRole role;
  final String selectedFont;
  final Future<void> Function(String) onSelected;

  @override
  State<_FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<_FontPicker> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  late String _selected = widget.selectedFont;
  String? _loading, _failed;

  // Fixed on opening, so rows don't reorder under the reader's finger. The font
  // in use leads, however far down the alphabet it would otherwise sit.
  late final List<String> _suggested = {
    widget.selectedFont,
    ...?fontSuggestions[widget.role],
  }.where(AppearanceFonts.supports).toList(growable: false);

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _select(String font) async {
    if (_loading != null || font == _selected) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _loading = font;
      _failed = null;
    });
    try {
      await widget.onSelected(font);
      if (mounted) setState(() => _selected = font);
    } catch (_) {
      if (mounted) setState(() => _failed = font);
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  void _queryChanged() {
    setState(() {});
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _clearQuery() {
    _search.clear();
    _queryChanged();
  }

  static String _normalized(String text) =>
      text.toLowerCase().replaceAll(' ', '');

  /// Names starting with the query come first: "lora" finds Lora before Flora.
  List<String> _matches(String query) {
    final needle = _normalized(query);
    final starts = <String>[], contains = <String>[];
    for (final font in AppearanceFonts.families) {
      final name = _normalized(font);
      if (name.startsWith(needle)) {
        starts.add(font);
      } else if (name.contains(needle)) {
        contains.add(font);
      }
    }
    return [...starts, ...contains];
  }

  Widget _row(String font) => _FontRow(
    font: font,
    selected: font == _selected,
    loading: font == _loading,
    failed: font == _failed,
    onTap: () => _select(font),
  );

  Widget _rows(List<String> fonts) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    sliver: SliverList.builder(
      itemCount: fonts.length,
      itemBuilder: (context, index) => _row(fonts[index]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final header = _Header(
      title: widget.title,
      current: _selected,
      controller: _search,
      onChanged: (_) => _queryChanged(),
      onClear: _clearQuery,
    );
    // Very large text would leave a pinned header no room for the list.
    final pin = MediaQuery.textScalerOf(context).scale(1) <= 1.5;
    final matches = query.isEmpty ? const <String>[] : _matches(query);
    return CustomScrollView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (pin)
          PinnedHeaderSliver(child: header)
        else
          SliverToBoxAdapter(child: header),
        if (query.isEmpty) ...[
          const _SectionLabel('Suggested'),
          _rows(_suggested),
          const _SectionLabel('All fonts'),
          _rows(AppearanceFonts.families),
        ] else if (matches.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _NoMatches(query: query, onClear: _clearQuery),
          )
        else ...[
          _SectionLabel(
            matches.length == 1 ? '1 font' : '${matches.length} fonts',
          ),
          _rows(matches),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.current,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final String title, current;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ColoredBox(
      color: colors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: theme.textTheme.titleLarge),
                      ),
                      Text(
                        'Using $current',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, _) => TextField(
                  controller: controller,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search fonts',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: onClear,
                          ),
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
        child: Semantics(
          header: true,
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query, required this.onClear});
  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Text('No fonts found', textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          'Nothing matches “$query”.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton(onPressed: onClear, child: const Text('Clear search')),
      ],
    ),
  );
}

class _FontRow extends StatelessWidget {
  const _FontRow({
    required this.font,
    required this.selected,
    required this.loading,
    required this.failed,
    required this.onTap,
  });
  final String font;
  final bool selected, loading, failed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: selected,
        selectedTileColor: colors.primaryContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(
          font,
          style: theme.textTheme.bodySmall?.copyWith(
            color: selected ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
        subtitle: failed
            ? Semantics(
                liveRegion: true,
                child: Text(
                  'This font couldn’t be loaded or saved. Try again.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error,
                  ),
                ),
              )
            : _FontPreview(key: ValueKey(font), font: font),
        trailing: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : selected
            ? Icon(Icons.check_rounded, color: colors.primary)
            : null,
        onTap: onTap,
      ),
    );
  }
}

/// Fetches its preview only once the row has stayed built for a moment, so a
/// fling through the list requests nothing for the rows it passes.
class _FontPreview extends ConsumerStatefulWidget {
  const _FontPreview({super.key, required this.font});
  final String font;

  @override
  ConsumerState<_FontPreview> createState() => _FontPreviewState();
}

class _FontPreviewState extends ConsumerState<_FontPreview> {
  static const _settleDelay = Duration(milliseconds: 150);

  late final FontPreviewLoader _loader = ref.read(fontPreviewLoaderProvider);
  Timer? _settle;
  String? _family;
  var _waiting = false;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    _family = _loader.readyFamily(widget.font);
    _finished = _family != null;
    if (!_finished) _settle = Timer(_settleDelay, _load);
  }

  Future<void> _load() async {
    _waiting = true;
    final family = await _loader.load(widget.font);
    _waiting = false;
    if (!mounted) return;
    setState(() {
      _family = family;
      _finished = true;
    });
  }

  @override
  void dispose() {
    _settle?.cancel();
    if (_waiting) _loader.cancel(widget.font);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final family = _family;
    // Without a loaded preview the text stays hidden or says so; showing the
    // sample in the app font would misrepresent the font on this row.
    return ExcludeSemantics(
      child: AnimatedOpacity(
        opacity: _finished ? 1 : 0,
        duration: RenderingPolicyScope.of(context).duration,
        child: Text(
          family != null || !_finished
              ? fontPreviewSample
              : 'Preview unavailable',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // Every font gets the same line box, so rows never shift on load.
          strutStyle: const StrutStyle(
            fontSize: 22,
            height: 1.4,
            forceStrutHeight: true,
          ),
          style: family != null
              ? TextStyle(
                  fontFamily: family,
                  fontSize: 22,
                  color: theme.colorScheme.onSurface,
                )
              : theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
      ),
    );
  }
}
