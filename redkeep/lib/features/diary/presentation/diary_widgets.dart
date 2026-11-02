import 'package:flutter/material.dart';

import '../../../core/presentation/paper_surface.dart';
import '../../../core/presentation/rendering_policy.dart';

/// Static notebook treatment. Simpler mode removes the decorative binding.
class NotebookSurface extends StatelessWidget {
  const NotebookSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey(
      RenderingPolicyScope.of(context).simplerEffects
          ? 'notebook-simple'
          : 'notebook-bound',
    ),
    decoration: RenderingPolicyScope.of(context).simplerEffects
        ? null
        : BoxDecoration(
            border: Border(
              left: BorderSide(
                width: 4,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
    padding: EdgeInsets.only(
      left: RenderingPolicyScope.of(context).simplerEffects ? 0 : 8,
    ),
    child: PaperSurface(child: child),
  );
}

class DiaryFrame extends StatelessWidget {
  const DiaryFrame({super.key, required this.slivers});
  final List<Widget> slivers;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Redkeep')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            slivers: [
              ...slivers,
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
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
