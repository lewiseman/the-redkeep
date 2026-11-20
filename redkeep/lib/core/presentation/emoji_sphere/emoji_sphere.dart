import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../rendering_policy.dart';
import 'emoji_catalog.dart';
import 'sphere_feel.dart';
import 'sphere_geometry.dart';

export 'emoji_catalog.dart' show EmojiEntry;

/// A globe of emoji to turn freely with a finger. The emoji at the centre
/// is the pick: when a turn ends, the nearest one eases into the centre,
/// leaving the sphere at whatever tilt it was turned to. Tapping it
/// confirms. A curved search field hugs the foot of the globe; matches stay
/// lit and the best one turns to the centre.
class EmojiSphere extends StatefulWidget {
  const EmojiSphere({
    super.key,
    this.selected,
    this.favorites = const [],
    required this.onChanged,
    this.onConfirm,
    this.action,
    this.maxDiameter = 320,
  });

  /// The emoji to start on, and to turn to whenever it changes.
  final String? selected;

  /// Placed nearest the centre, in this order, ahead of the browse order.
  final List<String> favorites;

  /// The centre emoji, each time a turn, tap or search settles the sphere
  /// on a different one. Opening the sphere reports nothing.
  final ValueChanged<EmojiEntry> onChanged;

  /// Tapping the centre emoji.
  final ValueChanged<EmojiEntry>? onConfirm;

  /// A quiet action curved over the top of the sphere, mirroring the search
  /// under its foot.
  final EmojiSphereAction? action;

  final double maxDiameter;

  @override
  State<EmojiSphere> createState() => _EmojiSphereState();
}

/// A small action curved over the top of an [EmojiSphere].
@immutable
class EmojiSphereAction {
  const EmojiSphereAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// Given to the action's tap target.
  final Key? key;
}

class _EmojiSphereState extends State<EmojiSphere>
    with TickerProviderStateMixin {
  final _query = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'emoji sphere search');
  final _scene = _SphereScene();
  late final Ticker _inertia = createTicker(_spin);
  late final _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..addListener(_snapTick);

  EmojiCatalog? _catalog;
  List<EmojiEntry> _browse = const [];
  Set<EmojiEntry> _favorites = const {};

  /// Cells on the unit sphere, fixed once the first size is known.
  List<SphereCell> _cells = const [];
  double _radius = 0;
  double _atlasGlyph = 0;
  double _atlasRatio = 0;

  List<EmojiEntry> _matches = const [];
  String _lastQuery = '';

  EmojiEntry? _reported;
  bool _dragging = false;
  Object? _clearKey;
  Offset? _clearAt;
  Duration? _lastDragStamp;
  Duration _lastSpin = Duration.zero;
  Vec3 _velocity = const Vec3(0, 0, 0);
  SphereRotation _snapFrom = SphereRotation.identity;
  SphereRotation _snapTo = SphereRotation.identity;

  /// Read from the rendering policy on each build.
  bool _animate = true;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    _query.addListener(_applyQuery);
    switch (EmojiCatalog.load()) {
      case final EmojiCatalog catalog:
        _useCatalog(catalog);
      case final Future<EmojiCatalog> loading:
        unawaited(
          loading.then((catalog) {
            if (mounted) setState(() => _useCatalog(catalog));
          }),
        );
    }
  }

  void _useCatalog(EmojiCatalog catalog) {
    _catalog = catalog;
    _browse = catalog.browseOrder(widget.favorites);
    _favorites = widget.favorites.map(catalog.find).nonNulls.toSet();
  }

  @override
  void didUpdateWidget(EmojiSphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selected;
    if (selected == null || selected == oldWidget.selected) return;
    final entry = _entryFor(selected);
    if (entry == null || entry.emoji == _picked?.emoji || _cells.isEmpty) {
      return;
    }
    _reported = entry;
    final index = _scene.pool.indexOf(entry);
    if (index >= 0) {
      _turnTo(index);
    } else {
      _arrange(entry);
      _turnTo(0);
    }
  }

  @override
  void dispose() {
    _inertia.dispose();
    _snap.dispose();
    _query.dispose();
    _searchFocus.dispose();
    _scene.dispose();
    super.dispose();
  }

  /// The catalog's entry for [emoji]; one the catalog lacks (a skin tone,
  /// a newer emoji) still gets a place on the sphere.
  EmojiEntry? _entryFor(String? emoji) {
    if (emoji == null || _catalog == null) return null;
    return _catalog!.find(emoji) ?? EmojiEntry(emoji.trim(), emoji.trim(), -1);
  }

  EmojiEntry? get _picked =>
      _scene.pool.isEmpty ? null : _scene.pool[_scene.picked];

  /// Spacing between neighbouring emoji, as a share of the radius.
  double get _spacing => math.sqrt(4 * math.pi / _cells.length);

  /// Lays the sphere out the first time a size is known.
  void _setUp(double radius) {
    final catalog = _catalog;
    if (catalog == null || _cells.isNotEmpty) return;
    const tile = 32.0;
    final count = (4 * math.pi * radius * radius / (tile * tile))
        .round()
        .clamp(60, math.max(60, math.min(360, catalog.entries.length)))
        .toInt();
    _cells = latitudeRings(count);
    final selected = _entryFor(widget.selected);
    _arrange(selected ?? _browse.first);
    // Start with the anchor dead centre and upright, without motion.
    _scene.rotation = SphereRotation.facing(_scene.positions.first);
    _scene.picked = 0;
    // What it opens on isn't a choice; only turning makes one.
    _reported = selected;
  }

  /// Fills the cells nearest the viewer with [anchor], the current
  /// matches, then the browse order.
  void _arrange(EmojiEntry anchor) {
    final facing = _scene.rotation.inverse.rotate(Vec3.front);
    final cells = [..._cells]
      ..sort((a, b) => b.normal.dot(facing).compareTo(a.normal.dot(facing)));
    final seen = <EmojiEntry>{anchor};
    final pool = <EmojiEntry>[anchor];
    for (final entry in [..._matches, ..._browse]) {
      if (pool.length == cells.length) break;
      if (seen.add(entry)) pool.add(entry);
    }
    _scene
      ..pool = pool
      ..positions = cells.take(pool.length).toList()
      ..matches = _lastQuery.isEmpty ? null : _matches.toSet()
      ..picked = 0;
    _atlasGlyph = 0; // Redrawn for the new pool on the next build.
  }

  void _applyQuery() {
    final query = _query.text.trim();
    if (query == _lastQuery || _catalog == null || _cells.isEmpty) return;
    _lastQuery = query;
    final current = _picked!;
    final found = query.isEmpty
        ? const <EmojiEntry>[]
        : _catalog!.search(query);
    // This place's own favourites lead their matches: "happy" finds 😊.
    _matches = [
      ...found.where(_favorites.contains),
      ...found.where((entry) => !_favorites.contains(entry)),
    ].take(_cells.length).toList();
    _arrange(_matches.isEmpty ? current : _matches.first);
    _turnTo(0);
    setState(() {});
  }

  /// Turns the next match to the centre.
  void _nextMatch() {
    if (_matches.isEmpty) return;
    final at = _matches.indexOf(_picked!);
    final next = _scene.pool.indexOf(_matches[(at + 1) % _matches.length]);
    if (next >= 0) _turnTo(next);
  }

  void _step(int by) {
    final count = _scene.pool.length;
    _turnTo((_scene.picked + by) % count);
  }

  // Motion -------------------------------------------------------------------

  void _rotateBy(Offset delta, {double speed = 0}) {
    final distance = delta.distance;
    if (distance == 0) return;
    // Dragging right turns the front toward the right; down turns it down.
    final turn = SphereRotation.axisAngle(
      Vec3(delta.dy, delta.dx, 0),
      distance / _radius,
    );
    _scene.rotation = (turn * _scene.rotation).normalized();
    _updatePicked(feelSpeed: speed);
  }

  /// Finds the emoji nearest the centre. With [feelSpeed], the turn is the
  /// user's, and each new emoji rolling under the lens ticks like a detent.
  void _updatePicked({double? feelSpeed}) {
    var best = 0;
    var bestZ = -2.0;
    for (final (index, position) in _scene.positions.indexed) {
      final z = _scene.rotation.rotate(position.normal).z;
      if (z > bestZ) {
        bestZ = z;
        best = index;
      }
    }
    final changed = best != _scene.picked;
    _scene.picked = best;
    _scene.changed();
    if (changed) {
      if (feelSpeed != null) SphereFeel.detent(speed: feelSpeed);
      setState(() {});
    }
  }

  void _stopMotion() {
    _inertia.stop();
    _snap.stop();
  }

  void _onPanStart(DragStartDetails details) {
    _stopMotion();
    _dragging = true;
    _lastDragStamp = null;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // How fast the finger turns the sphere, for the weight of each detent.
    final stamp = details.sourceTimeStamp;
    final last = _lastDragStamp;
    _lastDragStamp = stamp;
    final seconds = stamp == null || last == null
        ? 0.0
        : (stamp - last).inMicroseconds / 1e6;
    final speed = seconds <= 0
        ? 0.0
        : details.delta.distance / _radius / seconds;
    _rotateBy(details.delta, speed: speed);
  }

  void _onPanEnd(DragEndDetails details) {
    _dragging = false;
    final velocity = details.velocity.pixelsPerSecond;
    if (!_animate || velocity.distance < 60) {
      _settle();
      return;
    }
    // Angular velocity in radians a second, about the drag's own axis.
    final speed = math.min(velocity.distance / _radius, 18.0);
    _velocity = Vec3(velocity.dy, velocity.dx, 0).normalized() * speed;
    _lastSpin = Duration.zero;
    _inertia.start();
  }

  void _spin(Duration elapsed) {
    final dt = (elapsed - _lastSpin).inMicroseconds / 1e6;
    _lastSpin = elapsed;
    if (dt <= 0) return;
    final speed = _velocity.length;
    _scene.rotation =
        (SphereRotation.axisAngle(_velocity, speed * dt) * _scene.rotation)
            .normalized();
    _updatePicked(feelSpeed: speed);
    _velocity = _velocity * math.exp(-3.4 * dt);
    if (_velocity.length < 1.4) {
      _inertia.stop();
      _settle();
    }
  }

  /// A drag or fling ends by easing the emoji nearest the centre into the
  /// pick slot, keeping however the sphere is rolled.
  void _settle() => _turnTo(_scene.picked);

  /// Turns the emoji at [index] to the centre by the shortest way, keeping
  /// the sphere's roll, then reports it.
  void _turnTo(int index) {
    _stopMotion();
    final position = _scene.rotation.rotate(_scene.positions[index].normal);
    final target =
        (SphereRotation.between(position, Vec3.front) * _scene.rotation)
            .normalized();
    if (!_animate) {
      _scene.rotation = target;
      _updatePicked();
      SphereFeel.seat();
      _report();
      return;
    }
    _snapFrom = _scene.rotation;
    _snapTo = target;
    _snap.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted || _snap.status != AnimationStatus.completed) return;
      // Seated in the lens: felt as a click.
      SphereFeel.seat();
      if (!_dragging) _report();
    });
  }

  void _snapTick() {
    final t = Curves.easeOutCubic.transform(_snap.value);
    _scene.rotation = SphereRotation.slerp(_snapFrom, _snapTo, t);
    _updatePicked();
  }

  void _report() {
    final picked = _picked;
    if (picked == null || picked == _reported) return;
    _reported = picked;
    widget.onChanged(picked);
  }

  // Taps ---------------------------------------------------------------------

  void _onTapUp(TapUpDetails details) {
    final center = Offset(_radius, _radius);
    final reach = _radius * _spacing * .6 * _fisheyeCentre;
    int? hit;
    var hitDistance = double.infinity;
    for (final (index, position) in _scene.positions.indexed) {
      final turned = _scene.rotation.rotate(position.normal);
      if (turned.z < .2) continue;
      final point = center + _fisheye(turned) * _radius;
      final distance = (point - details.localPosition).distance;
      if (distance < reach && distance < hitDistance) {
        hit = index;
        hitDistance = distance;
      }
    }
    if (hit == null) return;
    final settled = !_snap.isAnimating && !_inertia.isActive;
    if (hit == _scene.picked && settled) {
      _report();
      if (widget.onConfirm != null) SphereFeel.choose();
      widget.onConfirm?.call(_picked!);
    } else {
      _turnTo(hit);
    }
  }

  // Drawing ------------------------------------------------------------------

  /// One image holding every emoji in the pool, so a frame is one draw.
  void _ensureAtlas(double glyph, double ratio) {
    if (_atlasGlyph >= glyph * .8 &&
        _atlasGlyph <= glyph * 1.25 &&
        _atlasRatio == ratio &&
        _scene.atlas != null) {
      return;
    }
    _atlasGlyph = glyph;
    _atlasRatio = ratio;
    final pool = _scene.pool;
    // Drawn at the largest it is ever shown, so the centre stays sharp.
    final fontSize = glyph * _fisheyeCentre * _lensZoom * ratio;
    final cell = (fontSize * 1.3).ceilToDouble();
    final columns = math.sqrt(pool.length).ceil();
    final rows = (pool.length / columns).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rects = <Rect>[];
    for (final (index, entry) in pool.indexed) {
      final origin = Offset(
        (index % columns) * cell,
        (index ~/ columns) * cell,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: entry.emoji,
          style: TextStyle(fontSize: fontSize, height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        origin +
            Offset((cell - painter.width) / 2, (cell - painter.height) / 2),
      );
      painter.dispose();
      rects.add(origin & Size.square(cell));
    }
    final picture = recorder.endRecording();
    _scene.atlas?.dispose();
    _scene
      ..atlas = picture.toImageSync(
        (columns * cell).ceil(),
        math.max(1, rows * cell).ceil(),
      )
      ..atlasRects = rects
      ..atlasFont = fontSize;
    picture.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final policy = RenderingPolicyScope.of(context);
    _animate = policy.animate;
    final textScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: 1.4);
    final labelStyle = Theme.of(context).textTheme.labelLarge!;
    // Search curves under the globe's foot, the action (if any) over its
    // crown.
    final pill = textScaler.scale(30);
    final action = widget.action;
    final actionPill = textScaler.scale(26);
    final top = action == null ? 4.0 : actionPill + 10;
    final bottom = pill + 12;
    // Body type, so the placeholder reads light and the query regular.
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    final searchStyle = bodyStyle.copyWith(
      fontSize: textScaler.scale(bodyStyle.fontSize ?? 14),
      letterSpacing: .2,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = math.min(
          widget.maxDiameter,
          constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0,
        );
        _radius = diameter / 2;
        _setUp(_radius);
        if (_cells.isEmpty) {
          return SizedBox(
            width: diameter,
            height: top + diameter + bottom + 32,
          );
        }
        final glyph = _radius * _spacing * .68;
        _ensureAtlas(glyph, MediaQuery.devicePixelRatioOf(context));
        final picked = _picked!;
        final centre = Offset(_radius, top + _radius);
        final searchRadius = _radius + 6 + pill / 2;
        // Where the search's ✕ sits, for its tap target. Measured only when
        // the search changes, not on every turn of the sphere.
        final clearKey = (
          _query.text,
          _searchFocus.hasFocus,
          searchRadius,
          searchStyle.fontSize,
          top,
        );
        if (clearKey != _clearKey) {
          _clearKey = clearKey;
          _clearAt = null;
          if (_query.text.isNotEmpty) {
            final layout = _SearchArcPainter.layout(
              center: centre,
              radius: searchRadius,
              query: _query.text,
              focused: _searchFocus.hasFocus,
              style: searchStyle,
              colors: colors,
            );
            _clearAt = layout.centreOf(layout.pieces.length - 1);
            layout.dispose();
          }
        }
        final clearAt = _clearAt;
        final sphere = Semantics(
          container: true,
          label: 'Emoji sphere',
          value: '${picked.emoji} ${picked.name}',
          increasedValue:
              _scene.pool[(_scene.picked + 1) % _scene.pool.length].name,
          decreasedValue:
              _scene.pool[(_scene.picked - 1) % _scene.pool.length].name,
          hint: 'Drag to turn. The centre emoji is chosen.',
          onIncrease: () => _step(1),
          onDecrease: () => _step(-1),
          onTap: widget.onConfirm == null
              ? null
              : () => widget.onConfirm!(picked),
          child: RawGestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            gestures: {
              _EagerPanGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    _EagerPanGestureRecognizer
                  >(_EagerPanGestureRecognizer.new, (recognizer) {
                    recognizer
                      ..onStart = _onPanStart
                      ..onUpdate = _onPanUpdate
                      ..onEnd = _onPanEnd
                      ..onCancel = () {
                        // A tap cancels the pan too; only a real drag needs settling.
                        if (!_dragging) return;
                        _dragging = false;
                        _settle();
                      };
                  }),
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                    TapGestureRecognizer.new,
                    (recognizer) => recognizer.onTapUp = _onTapUp,
                  ),
            },
            child: CustomPaint(
              key: const ValueKey('emoji-sphere'),
              size: Size.square(diameter),
              isComplex: true,
              willChange: true,
              painter: _SpherePainter(
                scene: _scene,
                glyph: glyph,
                spacing: _spacing,
                lens: _lensRadius(glyph),
              ),
            ),
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: diameter,
              height: top + diameter + bottom,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: top,
                    left: 0,
                    width: diameter,
                    height: diameter,
                    child: sphere,
                  ),
                  // The pick slot: a glass lens over the centre of the
                  // fisheye. Its own layer, so spinning never repaints it.
                  Positioned(
                    top: top,
                    left: 0,
                    width: diameter,
                    height: diameter,
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _GlassLensPainter(
                            diameter: _lensRadius(glyph) * 2,
                            accent: colors.primary,
                            shadow: colors.shadow,
                            dark: colors.brightness == Brightness.dark,
                            simple: policy.simplerEffects,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _SearchArcPainter(
                          center: centre,
                          radius: searchRadius,
                          thickness: pill,
                          query: _query.text,
                          focused: _searchFocus.hasFocus,
                          style: searchStyle,
                          colors: colors,
                          simple: policy.simplerEffects,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: top + diameter - 6,
                    left: _radius - _radius * .62,
                    width: _radius * 1.24,
                    height: bottom + 6,
                    child: _InvisibleSearchField(
                      controller: _query,
                      focusNode: _searchFocus,
                      onNext: _nextMatch,
                    ),
                  ),
                  if (clearAt != null)
                    Positioned(
                      left: clearAt.dx - 20,
                      top: clearAt.dy - 20,
                      width: 40,
                      height: 40,
                      child: Semantics(
                        button: true,
                        label: 'Clear search',
                        excludeSemantics: true,
                        child: GestureDetector(
                          key: const ValueKey('emoji-sphere-search-clear'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _query.clear,
                        ),
                      ),
                    ),
                  if (action != null) ...[
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ActionArcPainter(
                            center: centre,
                            radius: _radius + 6 + actionPill / 2,
                            thickness: actionPill,
                            label: action.label,
                            icon: action.icon,
                            style: labelStyle.copyWith(
                              fontSize: textScaler.scale(
                                (labelStyle.fontSize ?? 14) * .92,
                              ),
                            ),
                            colors: colors,
                            simple: policy.simplerEffects,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: _radius - _radius * .45,
                      width: _radius * .9,
                      height: top + 8,
                      child: Semantics(
                        button: true,
                        label: action.label,
                        excludeSemantics: true,
                        child: GestureDetector(
                          key: action.key,
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            SphereFeel.choose();
                            action.onPressed();
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: diameter,
              child: Text(
                picked.name,
                key: const ValueKey('emoji-sphere-name'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// How much the fisheye magnifies the middle of the sphere.
const _fisheyeCentre = 1.45;

/// Where a point on the unit sphere shows, in radii from the centre (y
/// down). A fisheye lens over the front: the middle is magnified by
/// [_fisheyeCentre] and the magnification eases off to none at the rim,
/// so emoji in view grow toward the centre without overlapping.
Offset _fisheye(Vec3 point) {
  const d = _fisheyeCentre - 1;
  final r = math.sqrt(point.x * point.x + point.y * point.y);
  final scale = (d + 1) / (d * math.min(r, 1) + 1);
  return Offset(point.x, -point.y) * scale;
}

/// How much the pick lens magnifies what sits under its middle.
const _lensZoom = 1.4;

/// The share of the lens's radius that magnifies; the rest is the thick
/// glass edge, where the neighbours under it squeeze into a thin ring.
const _lensClear = .8;

/// The pick lens's radius for emoji of [glyph] size: one emoji, magnified,
/// with a little room.
double _lensRadius(double glyph) => glyph * _fisheyeCentre * 1.25;

/// Where [offset] (pixels from the centre) shows through a lens of radius
/// [lens]: magnified in the middle, compressed at the rim, untouched
/// outside, and continuous across, as light bends through a glass drop.
Offset _refract(Offset offset, double lens) {
  final r = offset.distance;
  if (r == 0 || r >= lens) return offset;
  final inner = lens * _lensClear / _lensZoom;
  final seen = r <= inner
      ? r * _lensZoom
      : lens * _lensClear +
            (r - inner) * lens * (1 - _lensClear) / (lens - inner);
  return offset * (seen / r);
}

/// What the painter draws, changed without rebuilding the widget.
class _SphereScene extends ChangeNotifier {
  SphereRotation rotation = SphereRotation.identity;
  List<EmojiEntry> pool = const [];
  List<SphereCell> positions = const [];
  Set<EmojiEntry>? matches;
  int picked = 0;
  ui.Image? atlas;
  List<Rect> atlasRects = const [];
  double atlasFont = 1;

  void changed() => notifyListeners();

  @override
  void dispose() {
    atlas?.dispose();
    super.dispose();
  }
}

/// Draws each emoji as a small curved patch of the sphere's surface, laid
/// along its latitude, so emoji near the rim fold away as on a globe.
class _SpherePainter extends CustomPainter {
  _SpherePainter({
    required this.scene,
    required this.glyph,
    required this.spacing,
    required this.lens,
  }) : super(repaint: scene);

  final _SphereScene scene;
  final double glyph, spacing;

  /// The pick lens's radius, in pixels.
  final double lens;

  /// Each emoji's patch is a grid of points bent onto the sphere (and,
  /// at the centre, through the lens).
  static const _grid = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    final atlas = scene.atlas;
    if (atlas != null) _paintEmoji(canvas, center, radius, atlas);
  }

  void _paintEmoji(
    Canvas canvas,
    Offset center,
    double radius,
    ui.Image atlas,
  ) {
    final rotation = scene.rotation;
    final dimmed = scene.matches;
    final front = <(double, int)>[];
    for (final (index, cell) in scene.positions.indexed) {
      final z = rotation.rotate(cell.normal).z;
      if (z > -.1) front.add((z, index));
    }
    // Far ones first, so nearer emoji cover them.
    front.sort((a, b) => a.$1.compareTo(b.$1));

    const points = _grid * _grid;
    final positions = Float32List(front.length * points * 2);
    final textures = Float32List(front.length * points * 2);
    final tints = Int32List(front.length * points);
    final indices = Uint16List(front.length * (_grid - 1) * (_grid - 1) * 6);
    var vertex = 0, index = 0;
    for (final (_, item) in front) {
      final cell = scene.positions[item];
      final centre = rotation.rotate(cell.normal);
      // The atlas cell is 1.3 glyphs wide; as an angle on the sphere.
      final half = glyph * 1.3 / 2 / radius;
      final rect = scene.atlasRects[item];
      final lit = dimmed == null || dimmed.contains(scene.pool[item]);
      // Laid on the surface with screen-up as its up, so no turn of the
      // sphere tips it over.
      final (east, north) = uprightFrame(centre);
      final first = vertex;
      for (var row = 0; row < _grid; row++) {
        final up = 1 - 2 * row / (_grid - 1);
        for (var column = 0; column < _grid; column++) {
          final across = 2 * column / (_grid - 1) - 1;
          final point = (centre + east * (across * half) + north * (up * half))
              .normalized();
          final seen = _refract(_fisheye(point) * radius, lens);
          positions[vertex * 2] = center.dx + seen.dx;
          positions[vertex * 2 + 1] = center.dy + seen.dy;
          textures[vertex * 2] = rect.left + rect.width * column / (_grid - 1);
          textures[vertex * 2 + 1] = rect.top + rect.height * row / (_grid - 1);
          // Fade as the surface turns edge-on, point by point.
          final edge = (point.z / .35).clamp(0.0, 1.0);
          final alpha = (255 * edge * edge * (lit ? 1 : .2)).round();
          tints[vertex] = ((alpha << 24) | 0xFFFFFF).toSigned(32);
          vertex++;
        }
      }
      for (var row = 0; row < _grid - 1; row++) {
        for (var column = 0; column < _grid - 1; column++) {
          final a = first + row * _grid + column;
          indices
            ..[index++] = a
            ..[index++] = a + 1
            ..[index++] = a + _grid + 1
            ..[index++] = a
            ..[index++] = a + _grid + 1
            ..[index++] = a + _grid;
        }
      }
    }
    if (vertex == 0) return;
    canvas.drawVertices(
      ui.Vertices.raw(
        ui.VertexMode.triangles,
        positions,
        textureCoordinates: textures,
        colors: tints,
        indices: indices,
      ),
      BlendMode.modulate,
      Paint()
        ..shader = ImageShader(
          atlas,
          TileMode.clamp,
          TileMode.clamp,
          Matrix4.identity().storage,
          filterQuality: FilterQuality.medium,
        ),
    );
  }

  @override
  bool shouldRepaint(_SpherePainter old) =>
      old.scene != scene ||
      old.glyph != glyph ||
      old.spacing != spacing ||
      old.lens != lens;
}

/// The rim of the pick lens. The glass itself is clear: the sphere painter
/// bends what is under it. This adds only what light on a glass drop
/// shows, in the app's liquid glass manner: a bright edge band, specular
/// glints above left and below right, a hairline of accent, and a soft
/// shadow that falls outside the lens only.
class _GlassLensPainter extends CustomPainter {
  const _GlassLensPainter({
    required this.diameter,
    required this.accent,
    required this.shadow,
    required this.dark,
    required this.simple,
  });

  final double diameter;
  final Color accent, shadow;
  final bool dark, simple;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = diameter / 2;
    final lens = Rect.fromCircle(center: center, radius: radius);
    final white = Colors.white;

    Paint ring(double width, Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;

    if (simple) {
      canvas
        ..drawCircle(
          center,
          radius - .7,
          ring(1.2, white.withValues(alpha: .6)),
        )
        ..drawCircle(center, radius, ring(1, accent.withValues(alpha: .45)));
      return;
    }

    // A soft settle under the drop, kept outside it so the emoji stay clear.
    canvas
      ..save()
      ..clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(lens.inflate(16)),
          Path()..addOval(lens),
        ),
      )
      ..drawCircle(
        center.translate(0, 2.5),
        radius,
        Paint()
          ..color = shadow.withValues(alpha: dark ? .45 : .14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      ..restore();

    // The thick edge catches light: a bright band just inside the rim.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            white.withValues(alpha: 0),
            white.withValues(alpha: 0),
            white.withValues(alpha: dark ? .12 : .3),
            white.withValues(alpha: dark ? .04 : .08),
          ],
          stops: const [0, _lensClear - .06, .93, 1],
        ).createShader(lens),
    );

    // Specular glints where the light enters and leaves the drop.
    final glint = Rect.fromCircle(center: center, radius: radius - 2.2);
    canvas
      ..drawArc(
        glint,
        math.pi * 1.08,
        math.pi * .42,
        false,
        ring(2.2, white.withValues(alpha: dark ? .55 : .95))
          ..strokeCap = StrokeCap.round,
      )
      ..drawArc(
        glint,
        math.pi * .12,
        math.pi * .26,
        false,
        ring(1.4, white.withValues(alpha: dark ? .3 : .6))
          ..strokeCap = StrokeCap.round,
      )
      // Edge lines: glass white inside, the app's accent outside.
      ..drawCircle(
        center,
        radius - .6,
        ring(1, white.withValues(alpha: dark ? .25 : .7)),
      )
      ..drawCircle(
        center,
        radius + .3,
        ring(.8, accent.withValues(alpha: dark ? .5 : .35)),
      );
  }

  @override
  bool shouldRepaint(_GlassLensPainter old) =>
      old.diameter != diameter ||
      old.accent != accent ||
      old.shadow != shadow ||
      old.dark != dark ||
      old.simple != simple;
}

/// One piece of a curved label, drawn upright and centred on the origin.
class _ArcPiece {
  _ArcPiece.text(String text, TextStyle style)
    : painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(),
      _width = null,
      _draw = null;

  _ArcPiece.custom(double width, [void Function(Canvas)? draw])
    : painter = null,
      _width = width,
      _draw = draw;

  final TextPainter? painter;
  final double? _width;
  final void Function(Canvas)? _draw;

  double get width => painter?.width ?? _width!;

  void draw(Canvas canvas) {
    final painter = this.painter;
    if (painter != null) {
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    } else {
      _draw?.call(canvas);
    }
  }

  void dispose() => painter?.dispose();
}

/// Pieces laid along a circle around the sphere, centred on its top or its
/// bottom and always reading left to right.
class _ArcLayout {
  _ArcLayout({
    required this.center,
    required this.radius,
    required this.pieces,
    required this.bottom,
  });

  final Offset center;
  final double radius;
  final List<_ArcPiece> pieces;
  final bool bottom;

  late final double length = pieces.fold(0.0, (sum, p) => sum + p.width);

  /// Left to right runs clockwise over the top, anticlockwise under the foot.
  double get _turn => bottom ? -1 : 1;
  double get _start =>
      (bottom ? math.pi / 2 : -math.pi / 2) - _turn * length / radius / 2;

  double angleAt(double along) => _start + _turn * along / radius;

  /// The middle of piece [index], on screen.
  Offset centreOf(int index) {
    var along = pieces[index].width / 2;
    for (var i = 0; i < index; i++) {
      along += pieces[i].width;
    }
    final angle = angleAt(along);
    return center + Offset(math.cos(angle), math.sin(angle)) * radius;
  }

  /// A round-ended band under the pieces, [pad] past each end, along the
  /// circle of [at] (the layout's own by default).
  void band(Canvas canvas, double pad, Paint paint, {double? at}) =>
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: at ?? radius),
        angleAt(-pad),
        _turn * (length + 2 * pad) / radius,
        false,
        paint..style = PaintingStyle.stroke,
      );

  void paintPieces(Canvas canvas) {
    var along = 0.0;
    for (final piece in pieces) {
      final angle = angleAt(along + piece.width / 2);
      canvas
        ..save()
        ..translate(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        )
        ..rotate(angle + _turn * math.pi / 2);
      piece.draw(canvas);
      canvas.restore();
      along += piece.width;
    }
  }

  void dispose() {
    for (final piece in pieces) {
      piece.dispose();
    }
  }
}

_ArcPiece _iconPiece(IconData icon, double size, Color color) => _ArcPiece.text(
  String.fromCharCode(icon.codePoint),
  TextStyle(
    fontFamily: icon.fontFamily,
    package: icon.fontPackage,
    fontSize: size,
    color: color,
  ),
);

/// A curved pill drawn as a strip of glass bent around the sphere: one
/// radial shade across its width, lit along its upper lip and a touch
/// darker along its lower one, a faint hairline edge and a thin glint. No
/// blur and no extra layers, so it costs a few strokes.
void _glassBand(
  Canvas canvas,
  _ArcLayout layout,
  double thickness, {
  required Color base,
  required Color edge,
  required bool dark,
  required bool simple,
}) {
  final pad = thickness * .48;
  Paint round(double width) => Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = width;
  layout.band(canvas, pad, round(thickness + 1.2)..color = edge);
  if (simple) {
    layout.band(canvas, pad, round(thickness)..color = base);
    return;
  }
  final inner = layout.radius - thickness / 2;
  final outer = layout.radius + thickness / 2;
  final from = inner / outer;
  final light = Color.lerp(base, Colors.white, dark ? .1 : .6)!;
  final shade = Color.lerp(base, Colors.black, dark ? .22 : .05)!;
  // Under the foot the upper lip is the inner edge; over the crown, the
  // outer one.
  final across = layout.bottom
      ? [light, base, base, shade]
      : [shade, base, base, light];
  layout.band(
    canvas,
    pad,
    round(thickness)
      ..shader = RadialGradient(
        colors: across,
        stops: [from, from + (1 - from) * .4, from + (1 - from) * .7, 1],
      ).createShader(Rect.fromCircle(center: layout.center, radius: outer)),
  );
  layout.band(
    canvas,
    pad * .3,
    round(1)..color = Colors.white.withValues(alpha: dark ? .12 : .6),
    at: layout.bottom ? inner + 1.6 : outer - 1.6,
  );
}

/// The search field, curved under the foot of the sphere: a glassy pill
/// with the magnifier at its left end while resting, the query (or a quiet
/// "Search emoji") in the middle with a caret while typing, and a small ✕
/// at its right end once there is something to clear.
class _SearchArcPainter extends CustomPainter {
  _SearchArcPainter({
    required this.center,
    required this.radius,
    required this.thickness,
    required this.query,
    required this.focused,
    required this.style,
    required this.colors,
    required this.simple,
  });

  final Offset center;
  final double radius, thickness;
  final String query;
  final bool focused;
  final TextStyle style;
  final ColorScheme colors;
  final bool simple;

  /// The widest the pill may wrap around the sphere, in radians.
  static const _maxSweep = 1.9;

  /// The pieces for [query], so the widget can find the ✕ the painter
  /// draws. The caller disposes the layout.
  static _ArcLayout layout({
    required Offset center,
    required double radius,
    required String query,
    required bool focused,
    required TextStyle style,
    required ColorScheme colors,
  }) {
    final size = style.fontSize ?? 14;
    final gap = size * .45;
    final placeholder = query.isEmpty;
    final quiet = style.copyWith(
      color: colors.onSurfaceVariant.withValues(alpha: .8),
      fontWeight: FontWeight.w400,
    );
    final ink = style.copyWith(
      color: colors.onSurface,
      fontWeight: FontWeight.w500,
    );
    final caret = _ArcPiece.custom(
      3,
      (canvas) => canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 2, height: size * 1.25),
          const Radius.circular(1),
        ),
        Paint()..color = colors.primary,
      ),
    );
    // Each end of the pill holds a slot: the magnifier on the left while
    // resting, the ✕ on the right once there is a query. Typing drops the
    // magnifier; the slots stay, so the text keeps to the middle.
    final slot = size * 1.5;
    final resting = !focused && placeholder;
    final start = _ArcPiece.custom(
      slot,
      resting
          ? (canvas) {
              final glass = _iconPiece(
                Icons.search_rounded,
                size * 1.2,
                colors.onSurfaceVariant,
              );
              glass.draw(canvas);
              glass.dispose();
            }
          : null,
    );
    final end = _ArcPiece.custom(
      slot,
      placeholder
          ? null
          : (canvas) {
              final cross = _iconPiece(
                Icons.close_rounded,
                size,
                colors.onSurfaceVariant.withValues(alpha: .75),
              );
              cross.draw(canvas);
              cross.dispose();
            },
    );
    final letters = [
      for (final letter in (placeholder ? 'Search emoji' : query).characters)
        _ArcPiece.text(letter, placeholder ? quiet : ink),
    ];
    List<_ArcPiece> middle() => [
      if (focused && placeholder) caret,
      ...letters,
      if (focused && !placeholder) caret,
    ];
    double width() =>
        [start, ...middle(), end].fold(0.0, (sum, p) => sum + p.width) +
        gap * 2;
    // Long queries keep their end in view.
    if (width() / radius > _maxSweep) {
      while (letters.length > 1 && width() / radius > _maxSweep - .1) {
        letters.removeAt(0).dispose();
      }
      letters.insert(0, _ArcPiece.text('…', ink));
    }
    // A steady length, so the ends stay put while the text is short.
    final spare = math.max(0.0, radius * 1.05 - width()) / 2;
    return _ArcLayout(
      center: center,
      radius: radius,
      pieces: [
        start,
        _ArcPiece.custom(gap + spare),
        ...middle(),
        _ArcPiece.custom(gap + spare),
        end,
      ],
      bottom: true,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _SearchArcPainter.layout(
      center: center,
      radius: radius,
      query: query,
      focused: focused,
      style: style,
      colors: colors,
    );
    final dark = colors.brightness == Brightness.dark;
    _glassBand(
      canvas,
      layout,
      thickness,
      // Typing tints the glass toward the accent.
      base: Color.alphaBlend(
        colors.primary.withValues(alpha: focused ? .1 : 0),
        Color.lerp(colors.surface, colors.surfaceContainerHighest, .75)!,
      ),
      edge: focused
          ? colors.primary.withValues(alpha: .6)
          : colors.outlineVariant.withValues(alpha: .45),
      dark: dark,
      simple: simple,
    );
    layout
      ..paintPieces(canvas)
      ..dispose();
  }

  @override
  bool shouldRepaint(_SearchArcPainter old) =>
      old.center != center ||
      old.radius != radius ||
      old.thickness != thickness ||
      old.query != query ||
      old.focused != focused ||
      old.style != style ||
      old.colors != colors ||
      old.simple != simple;
}

/// An [EmojiSphereAction] curved over the top of the sphere: an icon and a
/// word in quiet ink inside a hairline pill.
class _ActionArcPainter extends CustomPainter {
  _ActionArcPainter({
    required this.center,
    required this.radius,
    required this.thickness,
    required this.label,
    required this.icon,
    required this.style,
    required this.colors,
    required this.simple,
  });

  final Offset center;
  final double radius, thickness;
  final String label;
  final IconData icon;
  final TextStyle style;
  final ColorScheme colors;
  final bool simple;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = colors.onSurfaceVariant;
    final layout = _ArcLayout(
      center: center,
      radius: radius,
      bottom: false,
      pieces: [
        _iconPiece(icon, (style.fontSize ?? 13) * 1.05, ink),
        _ArcPiece.text(' ', style),
        for (final letter in label.characters)
          _ArcPiece.text(letter, style.copyWith(color: ink)),
      ],
    );
    _glassBand(
      canvas,
      layout,
      thickness,
      base: Color.lerp(colors.surface, colors.surfaceContainerHighest, .6)!,
      edge: colors.outlineVariant.withValues(alpha: .45),
      dark: colors.brightness == Brightness.dark,
      simple: simple,
    );
    layout
      ..paintPieces(canvas)
      ..dispose();
  }

  @override
  bool shouldRepaint(_ActionArcPainter old) =>
      old.center != center ||
      old.radius != radius ||
      old.thickness != thickness ||
      old.label != label ||
      old.icon != icon ||
      old.style != style ||
      old.colors != colors ||
      old.simple != simple;
}

/// Takes typing for the arc; its own text is never shown.
class _InvisibleSearchField extends StatelessWidget {
  const _InvisibleSearchField({
    required this.controller,
    required this.focusNode,
    required this.onNext,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Search emoji',
    textField: true,
    child: TextField(
      key: const ValueKey('emoji-sphere-search'),
      controller: controller,
      focusNode: focusNode,
      autocorrect: false,
      enableSuggestions: false,
      enableInteractiveSelection: false,
      showCursor: false,
      maxLines: 1,
      textAlign: TextAlign.center,
      textInputAction: TextInputAction.search,
      // Search moves to the next match and keeps the keyboard up.
      onEditingComplete: () {},
      onSubmitted: (_) => onNext(),
      style: const TextStyle(color: Colors.transparent, fontSize: 1),
      decoration: const InputDecoration.collapsed(hintText: null),
    ),
  );
}

/// Claims a drag after a few pixels, ahead of any scrolling sheet around it,
/// so the sphere turns in every direction.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  _EagerPanGestureRecognizer();

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) => globalDistanceMoved.abs() > 4;
}
