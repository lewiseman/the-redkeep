import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../ai/application/ai_jobs.dart';
import '../../sync/application/sync_providers.dart';
import '../application/note_ai_controller.dart';
import '../application/note_editor_controller.dart';
import '../application/notes_providers.dart';
import '../domain/note_colors.dart';
import '../domain/note_document.dart';
import 'note_ai_folio.dart';
import 'note_ai_sheet.dart';
import 'note_ai_widgets.dart';

/// A kept AI result, told back on the note it changed.
@immutable
class NoteAiLanding {
  const NoteAiLanding({
    required this.tool,
    required this.message,
    this.appended = false,
  });
  final NoteAiTool tool;
  final String message;

  /// New words were added at the end; the note shows its end.
  final bool appended;
}

/// Opens the Maester's desk over the note. Keeping a result closes the desk
/// and returns a [NoteAiLanding] so the note can show what changed.
///
/// [initialTool] opens that tool straight away, e.g. Regenerate on a
/// website page.
Future<NoteAiLanding?> showNoteAiTools(
  BuildContext context,
  String id, {
  bool editor = false,
  NoteAiTool? initialTool,
}) => showModalBottomSheet<NoteAiLanding>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  elevation: 0,
  constraints: BoxConstraints(
    maxWidth: 720,
    maxHeight: MediaQuery.sizeOf(context).height * .94,
  ),
  // The desk shrinks above the keyboard so its fields can scroll into view.
  builder: (sheetContext) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
    ),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: NoteAiDesk(
        id: id,
        editor: editor,
        initialTool: initialTool,
        onLanded: (landing) => Navigator.of(sheetContext).pop(landing),
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    ),
  ),
);

class NoteAiDesk extends ConsumerStatefulWidget {
  const NoteAiDesk({
    super.key,
    required this.id,
    required this.editor,
    required this.onLanded,
    required this.onClose,
    this.initialTool,
  });
  final String id;
  final bool editor;
  final NoteAiTool? initialTool;
  final ValueChanged<NoteAiLanding> onLanded;
  final VoidCallback onClose;

  @override
  ConsumerState<NoteAiDesk> createState() => _NoteAiDeskState();
}

class _NoteAiDeskState extends ConsumerState<NoteAiDesk> {
  late NoteAiTool? _tool = widget.initialTool;

  @override
  Widget build(BuildContext context) {
    final opened = ref.watch(noteDocumentProvider(widget.id));
    final state = widget.editor
        ? ref.watch(noteEditorProvider(widget.id)).value
        : null;
    final saved = opened.value?.note;
    final draft = state?.baseRevision == 0 || saved == null;
    final available =
        opened.hasValue && (draft ? state != null : opened.value!.available);
    final canEdit = ref.watch(syncCanEditProvider);
    final details = state?.details ?? saved?.details ?? const NoteDetails();
    final title = state?.text.title ?? saved?.text.title ?? '';
    final tools = draft
        ? [
            NoteAiTool.template,
            // A new note can start as a website too.
            if (canEdit) NoteAiTool.presentation,
            NoteAiTool.scan,
            NoteAiTool.background,
          ]
        : [
            NoteAiTool.writing,
            NoteAiTool.summary,
            NoteAiTool.metadata,
            if (canEdit) NoteAiTool.scan,
            if (saved.details.attachments.any((a) => a.isImage))
              NoteAiTool.image,
            NoteAiTool.presentation,
            if (canEdit) NoteAiTool.background,
          ];
    final tool = _tool;
    // A request in flight belongs to its tool; switching would abandon it.
    final busy =
        tool != null &&
        ref.watch(aiJobsProvider(noteAiScope(tool.name, widget.id))).busy;
    final noteColor = NoteColors.fromBackground(
      Theme.of(context).colorScheme,
      details.background,
    ).background;
    final policy = RenderingPolicyScope.of(context);
    return NoteAiPaletteScope(
      noteColor: noteColor,
      child: Builder(
        builder: (context) {
          final palette = NoteAiPalette.of(
            context,
            tint: (tool ?? NoteAiTool.writing).tint,
          );
          return AnimatedTheme(
            duration: policy.animate
                ? const Duration(milliseconds: 360)
                : Duration.zero,
            data: palette.theme(Theme.of(context)),
            child: PopScope(
              canPop: tool == null,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && !busy) setState(() => _tool = null);
              },
              child: Material(
                color: palette.paper,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _DeskHeader(
                      title: title,
                      tool: tool,
                      onBack: tool == null || busy
                          ? null
                          : () => setState(() => _tool = null),
                      onClose: widget.onClose,
                    ),
                    Expanded(
                      child: ListView(
                        key: const ValueKey('note-assistant-actions'),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        children: [
                          if (!available && !draft)
                            const Padding(
                              padding: EdgeInsets.all(14),
                              child: Text(
                                'This note is unavailable.',
                                key: ValueKey('note-assistant-save-first'),
                              ),
                            )
                          else if (tool == null)
                            ..._resting(
                              tools: tools,
                              draft: draft,
                              available: available,
                              details: details,
                              title: title,
                              body: state?.text.body ?? saved?.text.body ?? '',
                              tags: state?.details.tags ?? saved?.tags ?? [],
                            )
                          else ...[
                            _ToolRibbon(
                              tools: tools,
                              selected: tool,
                              onSelected: busy
                                  ? null
                                  : (t) => setState(() => _tool = t),
                            ),
                            const SizedBox(height: 18),
                            NoteAiToolPage(
                              key: ValueKey('note-ai-${tool.name}'),
                              tool: tool,
                              id: widget.id,
                              embedded: true,
                              onLanded: widget.onLanded,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The desk at rest: the note itself, then every craft laid out to pick.
  List<Widget> _resting({
    required List<NoteAiTool> tools,
    required bool draft,
    required bool available,
    required NoteDetails details,
    required String title,
    required String body,
    required List<String> tags,
  }) {
    final narrow =
        MediaQuery.sizeOf(context).width < 350 ||
        MediaQuery.textScalerOf(context).scale(14) > 20;
    final single = narrow || draft;
    Widget card(NoteAiTool tool) => NoteAiToolCard(
      key: ValueKey('note-assistant-${tool.name}'),
      tool: tool,
      horizontal: single,
      onTap: available ? () => setState(() => _tool = tool) : null,
    );
    return [
      NoteFolio(
        details: details,
        status: draft ? 'New note' : 'Your note',
        child: NoteFolioPage(
          title: title,
          body: body,
          tags: tags,
          // Large text keeps the crafts within reach below the note.
          bodyLines: narrow ? 2 : 4,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 12),
        child: Text(
          draft ? 'Begin this page' : 'What shall the Maester do?',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      for (var i = 0; i < tools.length; i += single ? 1 : 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: single || i + 1 == tools.length
              ? card(tools[i])
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: card(tools[i])),
                      const SizedBox(width: 10),
                      Expanded(child: card(tools[i + 1])),
                    ],
                  ),
                ),
        ),
    ];
  }
}

class _DeskHeader extends StatelessWidget {
  const _DeskHeader({
    required this.title,
    required this.tool,
    required this.onBack,
    required this.onClose,
  });
  final String title;
  final NoteAiTool? tool;
  final VoidCallback? onBack, onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = title.trim().isEmpty ? 'this note' : '“${title.trim()}”';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              if (tool != null)
                IconButton(
                  tooltip: 'All tools',
                  onPressed: onBack,
                  icon: const Icon(Icons.grid_view_rounded),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/branding/grand_maestar.png',
                    width: 40,
                    height: 40,
                    excludeFromSemantics: true,
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool?.title ?? 'The Maester',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Working on $note',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close AI tools',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Once a craft is chosen the cards fold into a ribbon of ink medallions,
/// so switching stays one tap away while the note takes the stage.
class _ToolRibbon extends StatelessWidget {
  const _ToolRibbon({
    required this.tools,
    required this.selected,
    required this.onSelected,
  });
  final List<NoteAiTool> tools;
  final NoteAiTool selected;
  final ValueChanged<NoteAiTool>? onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final tool in tools)
          NoteAiMedallion(
            key: ValueKey('note-ribbon-${tool.name}'),
            tool: tool,
            selected: tool == selected,
            onTap: onSelected == null || tool == selected
                ? null
                : () => onSelected!(tool),
          ),
      ],
    ),
  );
}

class NoteAiMedallion extends StatelessWidget {
  const NoteAiMedallion({
    super.key,
    required this.tool,
    required this.selected,
    required this.onTap,
  });
  final NoteAiTool tool;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = NoteAiPalette.of(context, tint: tool.tint);
    final duration = RenderingPolicyScope.of(context).duration * 1.6;
    return Semantics(
      button: true,
      selected: selected,
      label: tool.label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 82,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                AnimatedScale(
                  scale: selected ? 1.08 : 1,
                  duration: duration,
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: duration,
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.wash(selected ? .2 : .08),
                      border: Border.all(
                        color: palette.ink.withValues(
                          alpha: selected ? .9 : .2,
                        ),
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: [
                        if (selected)
                          BoxShadow(
                            color: palette.ink.withValues(alpha: .3),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: NoteAiArt(tool: tool, size: 38),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tool.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? palette.ink : palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a kept AI result as a wax seal over the note it changed, then
/// fades away. Tap to dismiss early.
class NoteAiLandingHost extends StatefulWidget {
  const NoteAiLandingHost({
    super.key,
    required this.landing,
    required this.details,
    required this.onDismissed,
    required this.child,
  });
  final NoteAiLanding? landing;
  final NoteDetails details;
  final VoidCallback onDismissed;
  final Widget child;

  @override
  State<NoteAiLandingHost> createState() => _NoteAiLandingHostState();
}

class _NoteAiLandingHostState extends State<NoteAiLandingHost> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(NoteAiLandingHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.landing != widget.landing) _arm();
  }

  void _arm() {
    _timer?.cancel();
    if (widget.landing != null) {
      _timer = Timer(const Duration(seconds: 5), widget.onDismissed);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final landing = widget.landing;
    return Stack(
      children: [
        widget.child,
        if (landing != null)
          PositionedDirectional(
            top: 8,
            start: 16,
            end: 16,
            child: Center(
              child: NoteAiPaletteScope(
                noteColor: NoteColors.fromBackground(
                  Theme.of(context).colorScheme,
                  widget.details.background,
                ).background,
                child: _LandingSeal(
                  key: ObjectKey(landing),
                  landing: landing,
                  onTap: widget.onDismissed,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LandingSeal extends StatelessWidget {
  const _LandingSeal({super.key, required this.landing, required this.onTap});
  final NoteAiLanding landing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = NoteAiPalette.of(context, tint: landing.tool.tint);
    final animate = RenderingPolicyScope.of(context).animate;
    final theme = Theme.of(context);
    final seal = Semantics(
      liveRegion: true,
      button: true,
      label: '${landing.message}. Dismiss',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        key: const ValueKey('note-ai-landing'),
        color: palette.paper,
        elevation: 6,
        shadowColor: palette.ink.withValues(alpha: .4),
        shape: StadiumBorder(
          side: BorderSide(color: palette.ink.withValues(alpha: .35)),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 18, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 44,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: animate ? 0 : 1, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => CustomPaint(
                      painter: _BurstPainter(t, palette.ink),
                      child: child,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.ink,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.check_rounded,
                        color: palette.onInk,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        landing.message,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: palette.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        landing.appended
                            ? 'Showing the end of your note'
                            : 'Sealed by the Maester',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!animate) return seal;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -24 * (1 - t)),
          child: Transform.scale(scale: .9 + .1 * t, child: child),
        ),
      ),
      child: seal,
    );
  }
}

/// Eight sparks fly out from the seal once, then fade.
class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.t, this.ink);
  final double t;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..color = ink.withValues(alpha: (1 - t) * .8)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + math.pi / 8;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (22 + 10 * t), c + d * (26 + 18 * t), paint);
    }
    canvas.drawCircle(
      c,
      22 + 10 * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - t)
        ..color = ink.withValues(alpha: (1 - t) * .5),
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t || old.ink != ink;
}
