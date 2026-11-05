import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../companion/application/companion_controller.dart';
import '../../companion/presentation/ai_studio_material.dart';
import '../application/ai_preferences.dart';
import '../application/ai_providers.dart';
import '../domain/ai_operation.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_route.dart';

/// The route board's one idea: a solid line stays on your own network and a
/// dashed line leaves it. Words and icons always say the same, never color alone.
Color aiStationColor(BuildContext context, String? providerId) {
  final colors = Theme.of(context).colorScheme;
  if (providerId == null) return colors.primary;
  final dark = Theme.of(context).brightness == Brightness.dark;
  const lightPalette = [
    Color(0xFF0F766E),
    Color(0xFFB45309),
    Color(0xFF1D4ED8),
    Color(0xFFBE185D),
    Color(0xFF6D28D9),
    Color(0xFF15803D),
  ];
  const darkPalette = [
    Color(0xFF5EEAD4),
    Color(0xFFFCD34D),
    Color(0xFF93C5FD),
    Color(0xFFF9A8D4),
    Color(0xFFC4B5FD),
    Color(0xFF86EFAC),
  ];
  final palette = dark ? darkPalette : lightPalette;
  return palette[providerId.codeUnits.fold(0, (a, b) => a + b) %
      palette.length];
}

/// A station's mark. Plain initials, so no provider branding is imitated.
class AiStationMark extends StatelessWidget {
  const AiStationMark({
    super.key,
    this.name,
    this.providerId,
    this.size = 40,
    this.icon,
    this.color,
  });

  /// Null [name] and [icon] mean the person's own computer.
  final String? name, providerId;
  final double size;
  final IconData? icon;

  /// Overrides the station color, for marks that aren't a destination.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? aiStationColor(context, providerId ?? name);
    final letter = name?.trim().characters.firstOrNull?.toUpperCase();
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(size * .28),
          border: Border.all(color: color.withValues(alpha: .55)),
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: icon != null || letter == null
                ? Icon(
                    icon ?? Icons.computer_rounded,
                    size: size * .55,
                    color: color,
                  )
                : MediaQuery.withNoTextScaling(
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: color,
                        fontSize: size * .46,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Paints one stretch of a route beside its content. The content sets the
/// height, so large text and narrow screens never clip the line.
class AiRailRow extends StatelessWidget {
  const AiRailRow({
    super.key,
    required this.child,
    required this.color,
    this.dashed = false,
    this.connectTop = true,
    this.connectBottom = true,
    this.nodeY = 26,
    this.quiet = false,
    this.showNode = true,
  });
  final Widget child;
  final Color color;
  final bool dashed, connectTop, connectBottom, quiet, showNode;
  final double nodeY;

  static const railWidth = 26.0;

  @override
  Widget build(BuildContext context) {
    final policy = RenderingPolicyScope.of(context);
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: railWidth,
          child: TweenAnimationBuilder<double>(
            key: ValueKey('$color$dashed$quiet'),
            tween: Tween(begin: policy.animate ? 0 : 1, end: 1),
            duration: policy.duration * 2,
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) => CustomPaint(
              painter: _RailPainter(
                color: color,
                dashed: dashed,
                connectTop: connectTop,
                connectBottom: connectBottom,
                nodeY: nodeY,
                quiet: quiet,
                showNode: showNode,
                progress: progress,
                surface: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: railWidth + 8),
          child: child,
        ),
      ],
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.color,
    required this.dashed,
    required this.connectTop,
    required this.connectBottom,
    required this.nodeY,
    required this.quiet,
    required this.showNode,
    required this.progress,
    required this.surface,
  });
  final Color color, surface;
  final bool dashed, connectTop, connectBottom, quiet, showNode;
  final double nodeY, progress;

  void _segment(Canvas canvas, Offset from, Offset to, Paint paint) {
    if (!dashed) {
      canvas.drawLine(from, to, paint);
      return;
    }
    const on = 5.0, off = 5.0;
    var y = from.dy;
    while (y < to.dy) {
      canvas.drawLine(
        Offset(from.dx, y),
        Offset(from.dx, (y + on).clamp(from.dy, to.dy)),
        paint,
      );
      y += on + off;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final tint = color.withValues(alpha: quiet ? .45 : 1);
    final line = Paint()
      ..color = tint
      ..strokeWidth = quiet ? 1.5 : 2.5
      ..strokeCap = StrokeCap.round;
    if (connectTop) {
      _segment(canvas, Offset(x, 0), Offset(x, nodeY * progress), line);
    }
    if (connectBottom && progress > 0) {
      _segment(
        canvas,
        Offset(x, nodeY),
        Offset(x, nodeY + (size.height - nodeY) * progress),
        line,
      );
    }
    if (!showNode) return;
    final radius = quiet ? 4.0 : 6.0;
    canvas.drawCircle(Offset(x, nodeY), radius, Paint()..color = surface);
    canvas.drawCircle(
      Offset(x, nodeY),
      radius,
      Paint()
        ..color = tint
        ..style = quiet ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.color != color ||
      old.dashed != dashed ||
      old.connectTop != connectTop ||
      old.connectBottom != connectBottom ||
      old.quiet != quiet ||
      old.showNode != showNode ||
      old.nodeY != nodeY ||
      old.progress != progress ||
      old.surface != surface;
}

/// The label that marks where a route leaves the person's network.
class AiInternetBoundary extends StatelessWidget {
  const AiInternetBoundary({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.public_rounded, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Leaves your network, over the internet',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

String aiTaskCount(int count) => count == 1 ? '1 task' : '$count tasks';

/// Who each provider-capable task currently goes to.
Map<String?, List<AiOperation>> aiRoutesByStation(AiOperationRoutes routeFor) {
  final grouped = <String?, List<AiOperation>>{};
  for (final operation in AiOperation.values.where((o) => o.supportsProvider)) {
    grouped
        .putIfAbsent(routeFor(operation).providerId, () => [])
        .add(operation);
  }
  return grouped;
}

typedef AiOperationRoutes = AiRoute Function(AiOperation operation);

/// Grand Maestar's overview: your writing, and every line leaving it.
class AiRouteMap extends ConsumerWidget {
  const AiRouteMap({
    super.key,
    required this.onOpenTasks,
    required this.onOpenProviders,
    required this.onOpenProvider,
  });
  final VoidCallback onOpenTasks, onOpenProviders;
  final ValueChanged<String> onOpenProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(aiPreferencesProvider).value;
    final providers = ref.watch(aiProvidersProvider).value ?? const [];
    final connected =
        ref.watch(companionControllerProvider).phase ==
        CompanionPhase.connected;
    final colors = context.colors;
    final grouped = aiRoutesByStation(
      (operation) => prefs?.routeFor(operation) ?? const AiRoute.companion(),
    );
    final computerTasks = grouped[null]?.length ?? 0;
    final known = providers.map((p) => p.id).toSet();
    final orphaned = grouped.entries
        .where((e) => e.key != null && !known.contains(e.key))
        .fold(0, (sum, e) => sum + e.value.length);
    final computerColor = aiStationColor(context, null);
    final text = Theme.of(context).textTheme;

    Widget station({
      required Widget mark,
      required String title,
      required String detail,
      VoidCallback? onTap,
      Key? key,
    }) => InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              mark,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleSmall),
                    Text(
                      detail,
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );

    return AiStudioCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AiRailRow(
            color: computerColor,
            connectTop: false,
            nodeY: 12,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Your writing', style: text.titleSmall),
            ),
          ),
          AiRailRow(
            color: computerColor,
            nodeY: 34,
            quiet: computerTasks == 0,
            child: station(
              key: const ValueKey('ai-map-computer'),
              mark: const AiStationMark(),
              title: 'Your computer',
              detail: !connected
                  ? computerTasks == 0
                        ? 'Not connected'
                        : '${aiTaskCount(computerTasks)} · not connected'
                  : computerTasks == 0
                  ? 'Connected · no tasks'
                  : '${aiTaskCount(computerTasks)} · connected',
              onTap: onOpenTasks,
            ),
          ),
          AiRailRow(
            color: colors.outline,
            dashed: true,
            showNode: false,
            child: const AiInternetBoundary(),
          ),
          for (final provider in providers)
            AiRailRow(
              color: aiStationColor(context, provider.stationKey),
              dashed: true,
              nodeY: 34,
              quiet: (grouped[provider.id]?.length ?? 0) == 0,
              child: station(
                key: ValueKey('ai-map-provider-${provider.id}'),
                mark: AiStationMark(
                  name: provider.name,
                  providerId: provider.stationKey,
                ),
                title: provider.name,
                detail: (grouped[provider.id]?.length ?? 0) == 0
                    ? 'Connected · no tasks'
                    : aiTaskCount(grouped[provider.id]!.length),
                onTap: () => onOpenProvider(provider.id),
              ),
            ),
          if (orphaned > 0)
            AiRailRow(
              color: colors.error,
              dashed: true,
              nodeY: 34,
              child: station(
                mark: AiStationMark(
                  icon: Icons.link_off_rounded,
                  color: colors.error,
                ),
                title: 'Needs a new destination',
                detail: '${aiTaskCount(orphaned)} lost their provider',
                onTap: onOpenTasks,
              ),
            ),
          AiRailRow(
            color: colors.outline,
            dashed: true,
            connectBottom: false,
            quiet: true,
            nodeY: 34,
            child: station(
              key: const ValueKey('ai-providers-link'),
              mark: AiStationMark(
                icon: Icons.add_rounded,
                color: colors.onSurfaceVariant,
              ),
              title: providers.isEmpty ? 'Connect a provider' : 'Providers',
              detail: providers.isEmpty
                  ? 'Use your own key for OpenAI, Anthropic and more.'
                  : 'Add another or change a key.',
              onTap: onOpenProviders,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const ValueKey('ai-tasks-link'),
            onPressed: onOpenTasks,
            icon: const Icon(Icons.alt_route_rounded),
            label: const Text('Route tasks'),
          ),
        ],
      ),
    );
  }
}

/// What a route currently means, for labels that must agree across pages.
/// [problem] is set only when a task on this route can't run right now.
({String label, String? problem, bool cloud, AiProviderConnection? provider})
describeAiRoute(
  AiRoute route,
  List<AiProviderConnection> providers, {
  required bool computerConnected,
}) {
  if (route.isCompanion) {
    return (
      label: 'Your computer',
      problem: computerConnected ? null : 'Not connected',
      cloud: false,
      provider: null,
    );
  }
  final provider = providers.where((p) => p.id == route.providerId).firstOrNull;
  return provider == null
      ? (
          label: 'Provider removed',
          problem: 'Choose another destination',
          cloud: true,
          provider: null,
        )
      : (
          label: '${provider.name} · ${route.model}',
          problem: null,
          cloud: true,
          provider: provider,
        );
}

/// The two kinds of line, drawn rather than described.
class AiRouteLegend extends StatelessWidget {
  const AiRouteLegend({super.key, required this.local, required this.cloud});
  final int local, cloud;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget item(String label, int count, Color color, bool dashed) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: 28,
            height: 12,
            child: CustomPaint(
              painter: _LegendLinePainter(color: color, dashed: dashed),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '$label · ${aiTaskCount(count)}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        item('On your network', local, colors.primary, false),
        item('Over the internet', cloud, colors.onSurfaceVariant, true),
      ],
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  const _LegendLinePainter({required this.color, required this.dashed});
  final Color color;
  final bool dashed;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), paint);
    }
  }

  @override
  bool shouldRepaint(_LegendLinePainter old) =>
      old.color != color || old.dashed != dashed;
}
