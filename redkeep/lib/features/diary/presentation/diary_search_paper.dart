import '../../../core/presentation/rendering_policy.dart';
import 'diary_style.dart';
import 'diary_paper_stamp.dart';

/// Search chrome shares the diary's cached, theme-aware paper material.
class DiarySearchPaper extends StatelessWidget {
  const DiarySearchPaper({
    super.key,
    required this.child,
    this.color,
    this.variant = 0,
    this.onTap,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final Color? color;
  final int variant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return CustomPaint(
      painter: DiaryPaperStamp(
        paper: color ?? context.colors.surfaceContainerLowest,
        ink: context.colors.onSurface,
        shadowColor: context.colors.shadow,
        edgeScale: RenderingPolicyScope.of(context).simplerEffects ? 0 : .34,
        shadow: !RenderingPolicyScope.of(context).simplerEffects,
        variant: variant,
      ),
      child: onTap == null
          ? content
          : Semantics(
              button: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onTap,
                  child: content,
                ),
              ),
            ),
    );
  }
}
