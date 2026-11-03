import 'package:flutter/material.dart';

import 'diary_paper_stamp.dart';
import '../../../core/presentation/rendering_policy.dart';

/// The same stamped paper used by the original writing screen.
class NotebookSurface extends StatelessWidget {
  const NotebookSurface({super.key, required this.child, this.variant = 0});
  final Widget child;
  final int variant;
  @override
  Widget build(BuildContext context) {
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final colors = Theme.of(context).colorScheme;
    return CustomPaint(
      key: ValueKey(simple ? 'notebook-simple' : 'notebook-bound'),
      painter: DiaryPaperStamp(
        paper: colors.surfaceContainerLowest,
        ink: colors.onSurface,
        shadowColor: colors.shadow,
        variant: variant,
        edgeScale: simple ? 0 : .5,
        shadow: !simple,
      ),
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );
  }
}

class DiaryWritingFrame extends StatelessWidget {
  const DiaryWritingFrame({
    super.key,
    required this.child,
    required this.title,
    this.actions = const [],
  });
  final Widget child;
  final String title;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(
      title: Text(title),
      actions: actions,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: SizedBox(width: double.infinity, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget diaryBlock(Widget child) => SliverPadding(
  padding: const EdgeInsets.all(16),
  sliver: SliverToBoxAdapter(child: child),
);

/// All controls scroll at large text sizes, including dialog actions.
class DiaryDialog extends StatelessWidget {
  const DiaryDialog({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Dialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

void diaryMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
