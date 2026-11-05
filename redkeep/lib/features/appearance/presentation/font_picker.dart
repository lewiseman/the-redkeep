import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../application/appearance_typography.dart';
import '../data/font_preview_loader.dart';
import '../domain/appearance_fonts.dart';

Future<void> showFontPicker(
  BuildContext context, {
  required String selectedFont,
  required Future<void> Function(String) onSelected,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: FractionallySizedBox(
      heightFactor: .78,
      child: _FontPicker(selectedFont: selectedFont, onSelected: onSelected),
    ),
  ),
);

class _FontPicker extends StatefulWidget {
  const _FontPicker({required this.selectedFont, required this.onSelected});
  final String selectedFont;
  final Future<void> Function(String) onSelected;

  @override
  State<_FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<_FontPicker> {
  String _query = '';
  late String _selected = widget.selectedFont;
  String? _loading, _error;

  Future<void> _select(String font) async {
    setState(() {
      _loading = font;
      _error = null;
    });
    try {
      await widget.onSelected(font);
      if (mounted) setState(() => _selected = font);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'This font couldn’t be loaded or saved. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final matches = AppearanceFonts.families
        .where(
          (font) => font.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList();
    return Material(
      color: colors.surfaceContainer,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search fonts',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (matches.isEmpty)
            const SliverToBoxAdapter(
              child: Center(child: Text('No fonts found')),
            )
          else
            SliverList.separated(
              itemCount: matches.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: colors.primary.withValues(alpha: .16),
              ),
              itemBuilder: (context, index) {
                final font = matches[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: Text(font),
                  subtitle: _FontPreview(key: ValueKey(font), font: font),
                  selected: font == _selected,
                  trailing: _loading == font
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : font == _selected
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  onTap: _loading != null ? null : () => _select(font),
                );
              },
            ),
        ],
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
  var _finished = false;

  @override
  void initState() {
    super.initState();
    _family = _loader.readyFamily(widget.font);
    _finished = _family != null;
    if (!_finished) _settle = Timer(_settleDelay, _load);
  }

  Future<void> _load() async {
    final family = await _loader.load(widget.font);
    if (!mounted) return;
    setState(() {
      _family = family;
      _finished = true;
    });
  }

  @override
  void dispose() {
    _settle?.cancel();
    _loader.cancel(widget.font);
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
            fontSize: 20,
            height: 1.4,
            forceStrutHeight: true,
          ),
          style: family != null
              ? TextStyle(
                  fontFamily: family,
                  fontSize: 20,
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
