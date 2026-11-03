import 'package:flutter/material.dart';

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
