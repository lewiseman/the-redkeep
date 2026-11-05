import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'diary_paper_material.dart';

enum _CurlFace { front, back, shadow }

const _shadowPadding = 16.0;

/// A loose sheet, rather than a page attached to a book's spine. Its trailing
/// edge rolls back as the whole sheet travels out of the diary viewport.
/// [child] is a static, non-composited presentation of the card's front.
class DiaryPaperCurl extends SingleChildRenderObjectWidget {
  const DiaryPaperCurl({
    super.key,
    required this.progress,
    required this.direction,
    required this.travel,
    required this.paper,
    required super.child,
    this.shape = const DiaryPaperShape(),
    this.ink,
    this.visible = true,
    this.flat = false,
    this.warm = false,
    this.turning = false,
  });

  final double progress;
  final int direction;
  final double travel;
  final Color paper;
  final DiaryPaperShape shape;
  final Color? ink;
  final bool visible, flat, warm;

  /// Pins ready faces for the whole gesture, including pauses and reversals.
  /// A cold gesture remains a flat slide even if preparation finishes mid-turn.
  final bool turning;

  Color get _ink =>
      ink ??
      (paper.computeLuminance() < .3
          ? const Color(0xffeeeeee)
          : const Color(0xff222222));

  @override
  RenderDiaryCurl createRenderObject(BuildContext context) => RenderDiaryCurl(
    progress,
    direction,
    travel,
    paper,
    math.min(2, MediaQuery.devicePixelRatioOf(context)),
    shape,
    _ink,
    visible,
    flat,
    warm,
    turning,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderDiaryCurl renderObject,
  ) {
    renderObject.update(
      progress,
      direction,
      travel,
      paper,
      math.min(2, MediaQuery.devicePixelRatioOf(context)),
      shape,
      _ink,
      visible,
      flat,
      warm,
      turning,
    );
  }
}

class _RecordingContext extends PaintingContext {
  _RecordingContext(this.recordingCanvas, Rect bounds)
    : super(ContainerLayer(), bounds);

  final Canvas recordingCanvas;

  @override
  Canvas get canvas => recordingCanvas;
}

class RenderDiaryCurl extends RenderProxyBox {
  RenderDiaryCurl(
    this._progress,
    this._direction,
    this._travel,
    this._paper,
    this._pixelRatio,
    this._shape,
    this._ink,
    this._visible,
    this._flat,
    this._warm,
    this._turning,
  );

  double _progress;
  int _direction;
  double _travel;
  Color _paper;
  double _pixelRatio;
  DiaryPaperShape _shape;
  Color _ink;
  bool _visible, _flat, _warm;
  bool _turning;
  bool _curlForTurn = false, _frontDirty = false, _facesDirty = false;
  bool _disposed = false, _warmScheduled = false;
  int _frontGeneration = 0, _backGeneration = 0;
  int? _failedFrontGeneration, _failedBackGeneration, _failedShadowGeneration;
  Future<void>? _preparing;
  ui.Image? _front;
  ui.ImageShader? _texture;
  ui.Image? _backImage;
  ui.ImageShader? _backTexture;
  ui.Image? _flatShadow;
  int _frontCaptures = 0,
      _backCaptures = 0,
      _shadowCaptures = 0,
      _meshDraws = 0;

  @visibleForTesting
  int get debugFrontCaptures => _frontCaptures;
  @visibleForTesting
  int get debugBackCaptures => _backCaptures;
  @visibleForTesting
  int get debugShadowCaptures => _shadowCaptures;
  @visibleForTesting
  int get debugMeshDraws => _meshDraws;
  @visibleForTesting
  bool get debugUsesCurl => _usesCurl;
  @visibleForTesting
  Future<ui.Image> Function(ui.Picture, int, int)? debugRasterize;
  @visibleForTesting
  Size? get debugTextureSize => _front == null
      ? null
      : Size(_front!.width.toDouble(), _front!.height.toDouble());

  @override
  bool get isRepaintBoundary => true;

  @visibleForTesting
  bool get debugReady => _ready;

  bool get _ready =>
      _front != null && _backImage != null && _flatShadow != null;
  bool get _usesCurl => !_flat && _ready && (!_turning || _curlForTurn);

  void update(
    double progress,
    int direction,
    double travel,
    Color paper,
    double pixelRatio,
    DiaryPaperShape shape,
    Color ink,
    bool visible,
    bool flat,
    bool warm,
    bool turning,
  ) {
    final changed =
        progress != _progress ||
        direction != _direction ||
        travel != _travel ||
        paper != _paper ||
        pixelRatio != _pixelRatio ||
        shape != _shape ||
        ink != _ink ||
        visible != _visible ||
        flat != _flat ||
        turning != _turning;
    final wasTurning = _turning;
    _turning = turning;
    if (turning && !wasTurning) _curlForTurn = _ready;
    if (!turning && wasTurning) {
      if (_facesDirty) {
        _discardFaces();
      } else if (_frontDirty) {
        _discardFront();
      }
    }
    if (paper != _paper ||
        pixelRatio != _pixelRatio ||
        shape != _shape ||
        ink != _ink) {
      if (turning && pixelRatio == _pixelRatio) {
        _frontGeneration++;
        _backGeneration++;
        _facesDirty = true;
      } else {
        _discardFaces();
        _curlForTurn = false;
      }
    }
    _progress = progress;
    _direction = direction;
    _travel = travel;
    _paper = paper;
    _pixelRatio = pixelRatio;
    _shape = shape;
    _ink = ink;
    _visible = visible;
    _flat = flat;
    _warm = warm;
    _scheduleWarm();
    // Movement only changes the projection; the front texture is shared
    // by all strips and all frames of this turn.
    if (changed) super.markNeedsPaint();
  }

  void _discardFaces() {
    _facesDirty = false;
    _discardFront();
    _backGeneration++;
    _backTexture?.dispose();
    _backTexture = null;
    _backImage?.dispose();
    _backImage = null;
    _flatShadow?.dispose();
    _flatShadow = null;
  }

  void _discardFront() {
    _frontDirty = false;
    _frontGeneration++;
    _texture?.dispose();
    _texture = null;
    _front?.dispose();
    _front = null;
  }

  void _invalidateFront() {
    if (_turning) {
      _frontGeneration++;
      _frontDirty = true;
    } else {
      _discardFront();
    }
  }

  ui.Picture _recordBack() {
    // This material never records the child. A filtered front texture can
    // retain its widget alpha (and depends on backend filter support), whereas
    // the reverse of the sheet must be opaque even when its front has holes.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_pixelRatio);
    DiaryPaperPainter(
      shape: _shape,
      paper: _paper,
      ink: _ink,
      reverse: true,
    ).paint(canvas, size);
    assert(() {
      _backCaptures++;
      return true;
    }());
    return recorder.endRecording();
  }

  ui.Picture _recordFront() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_pixelRatio);
    canvas.clipPath(_shape.path(size));
    _RecordingContext(
      canvas,
      Offset.zero & size,
    ).paintChild(child!, Offset.zero);
    assert(() {
      _frontCaptures++;
      return true;
    }());
    return recorder.endRecording();
  }

  ui.ImageShader _shader(ui.Image image) => ui.ImageShader(
    image,
    TileMode.clamp,
    TileMode.clamp,
    Matrix4.identity().storage,
    filterQuality: FilterQuality.high,
  );

  void _paintFlatShadow(Canvas canvas) {
    final path = _shape.path(size);
    canvas.drawShadow(
      path.shift(const Offset(0, 3)),
      const Color(0x38000000),
      6,
      true,
    );
    canvas.drawShadow(path, const Color(0x1f000000), 1.2, true);
  }

  ui.Picture _recordShadow() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(math.min(1, _pixelRatio))
      ..translate(_shadowPadding, _shadowPadding);
    _paintFlatShadow(canvas);
    assert(() {
      _shadowCaptures++;
      return true;
    }());
    return recorder.endRecording();
  }

  /// Prepare fixed-size neighboring faces between gestures, using asynchronous
  /// rasterization instead of allocating their images on the first drag frame.
  Future<void> prepareTextures() async {
    if (!_canPrepare || child == null) return;
    // Serialize faces and the small shadow; repeated requests share preparation.
    await (_preparing ??= _prepareFaces().whenComplete(() {
      _preparing = null;
      _scheduleWarm();
    }));
  }

  bool get _needsFront =>
      _front == null && _failedFrontGeneration != _frontGeneration;
  bool get _needsBack =>
      _backImage == null && _failedBackGeneration != _backGeneration;
  bool get _needsShadow =>
      _flatShadow == null && _failedShadowGeneration != _backGeneration;

  bool get _canPrepare =>
      !_disposed &&
      attached &&
      !_turning &&
      hasSize &&
      !size.isEmpty &&
      size.isFinite;

  Future<void> _prepareFaces() async {
    if (_needsFront) await _prepareFace(_CurlFace.front);
    // Layout or a gesture may have changed while the front was rasterizing.
    if (_canPrepare && _needsBack) await _prepareFace(_CurlFace.back);
    if (_canPrepare && _needsShadow) await _prepareFace(_CurlFace.shadow);
  }

  Future<void> _prepareFace(_CurlFace face) async {
    final front = face == _CurlFace.front;
    final shadow = face == _CurlFace.shadow;
    final generation = front ? _frontGeneration : _backGeneration;
    ui.Picture? picture;
    ui.Image? image;
    ui.ImageShader? shader;
    try {
      // Moving/scaling a vector shadow forces expensive GPU work each frame.
      // Its soft edge needs only a 1x image, shared throughout the date's life.
      final ratio = shadow ? math.min(1, _pixelRatio) : _pixelRatio;
      final padding = shadow ? _shadowPadding * 2 : 0;
      final width = ((size.width + padding) * ratio).ceil();
      final height = ((size.height + padding) * ratio).ceil();
      picture = switch (face) {
        _CurlFace.front => _recordFront(),
        _CurlFace.back => _recordBack(),
        _CurlFace.shadow => _recordShadow(),
      };
      image =
          await (debugRasterize?.call(picture, width, height) ??
              picture.toImage(width, height));
      if (_disposed ||
          !attached ||
          generation != (front ? _frontGeneration : _backGeneration) ||
          switch (face) {
            _CurlFace.front => _front != null,
            _CurlFace.back => _backImage != null,
            _CurlFace.shadow => _flatShadow != null,
          }) {
        return;
      }
      if (shadow) {
        _flatShadow = image;
      } else if (!front) {
        shader = _shader(image);
        _backImage = image;
        _backTexture = shader;
      } else {
        shader = _shader(image);
        _front = image;
        _texture = shader;
      }
      image = null;
      shader = null;
      if (_visible) super.markNeedsPaint();
    } catch (error, stack) {
      if (!_disposed &&
          generation == (front ? _frontGeneration : _backGeneration)) {
        switch (face) {
          case _CurlFace.front:
            _failedFrontGeneration = generation;
          case _CurlFace.back:
            _failedBackGeneration = generation;
          case _CurlFace.shadow:
            _failedShadowGeneration = generation;
        }
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'diary paper',
            context: ErrorDescription('while preparing a diary curl face'),
          ),
        );
      }
    } finally {
      shader?.dispose();
      image?.dispose();
      picture?.dispose();
    }
  }

  void _scheduleWarm() {
    // Descendants can request repaint during their own independent layout.
    // Reading our size then violates RenderBox's layout contract, even when
    // hasSize is true. prepareTextures checks geometry after the frame instead.
    if (_disposed ||
        _turning ||
        !(_warm || _visible) ||
        _warmScheduled ||
        !attached ||
        _preparing != null ||
        (!_needsFront && !_needsBack && !_needsShadow)) {
      return;
    }
    _warmScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _warmScheduled = false;
      if (!_disposed && (_warm || _visible) && attached) prepareTextures();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void markNeedsPaint() {
    // The reverse is independent of front widgets, including their alpha.
    _invalidateFront();
    super.markNeedsPaint();
    _scheduleWarm();
  }

  @override
  void performLayout() {
    final before = hasSize ? size : null;
    super.performLayout();
    if (before != size) {
      _discardFaces();
      _curlForTurn = false;
    } else {
      _invalidateFront();
    }
    _scheduleWarm();
  }

  @override
  void dispose() {
    _disposed = true;
    _discardFaces();
    super.dispose();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      false;

  @override
  Rect get paintBounds {
    if (!_visible) return Rect.zero;
    if (_flat) return (Offset.zero & size).inflate(16);
    return Rect.fromLTRB(
      -_travel - size.width,
      -size.height * .2,
      size.width * 2 + _travel,
      size.height * 1.2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_visible || child == null || size.isEmpty) return;
    assert(!child!.needsCompositing, 'Curl faces must be static card content.');
    assert(() {
      _meshDraws = 0;
      return true;
    }());
    if (!_usesCurl) {
      final canvas = context.canvas;
      canvas.save();
      final slide = _flat ? 0.0 : _direction * _travel * _progress.clamp(0, 1);
      canvas.translate(offset.dx + slide, offset.dy);
      final path = _shape.path(size);
      if (_flatShadow case final shadow?) {
        canvas.drawImageRect(
          shadow,
          Rect.fromLTWH(
            0,
            0,
            shadow.width.toDouble(),
            shadow.height.toDouble(),
          ),
          (Offset.zero & size).inflate(_shadowPadding),
          Paint()..filterQuality = FilterQuality.low,
        );
      } else {
        _paintFlatShadow(canvas);
      }
      if (_front case final front?) {
        canvas.drawImageRect(
          front,
          Rect.fromLTWH(0, 0, front.width.toDouble(), front.height.toDouble()),
          Offset.zero & size,
          Paint()..filterQuality = FilterQuality.low,
        );
      } else {
        // A cold turn stays responsive without allocating a GPU image in paint.
        canvas.clipPath(path);
        context.paintChild(child!, Offset.zero);
      }
      canvas.restore();
      return;
    }

    final t = _progress.clamp(0.0, 1.0);
    final lift = math.sin(math.pi * t);
    // A wider roll and a little more lift make the fold visible early in the
    // drag, while both ends of the turn still settle into a flat sheet.
    double angleAt(double u) => lift * 3.6 * math.pow(1 - u, 1.7);
    final w = size.width;
    final h = size.height;
    const bands = 56;
    final strip = w / bands;
    final points = <({double x, double scale, double depth})>[];
    double x = 0;
    double z = 0;
    for (var i = 0; i <= bands; i++) {
      if (i > 0) {
        final u = (i - .5) / bands;
        final angle = angleAt(u);
        x += math.cos(angle) * strip;
        z += math.sin(angle) * strip;
      }
      points.add((
        x: (_direction > 0 ? x : w - x) + _direction * _travel * t,
        scale: 1,
        depth: z,
      ));
    }
    // The free trailing edge is above the sheet, not tucked underneath it.
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final depth = z - p.depth;
      points[i] = (x: p.x, scale: 1 + depth / (w * 5.5), depth: depth);
    }

    // Project the actual deckled outline, so the cast shadow never falls
    // back to a rectangular silhouette while the visible edge bends.
    final outline = _shape.outline(size).map((source) {
      final position =
          (_direction > 0 ? source.dx / w : 1 - source.dx / w) * bands;
      final index = position.floor().clamp(0, bands - 1);
      final fraction = (position - index).clamp(0.0, 1.0);
      final a = points[index];
      final b = points[index + 1];
      final scale = a.scale + (b.scale - a.scale) * fraction;
      return Offset(
        a.x + (b.x - a.x) * fraction,
        h / 2 + (source.dy - h / 2) * scale,
      );
    }).toList();
    final silhouette = DiaryPaperShape.pathFromOutline(outline);
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.drawShadow(
      silhouette,
      const Color(0xff211b28).withValues(alpha: .32 * lift),
      3 + 11 * lift,
      true,
    );

    // Far strips first: a rolled edge can overlap the face underneath it.
    final order = List.generate(bands, (i) => i)
      ..sort((a, b) => points[a].depth.compareTo(points[b].depth));
    // Submit contiguous faces as meshes rather than issuing 56 separate GPU
    // draws. Keep the original depth order, including overlapping rolled edges.
    final positions = <Offset>[];
    final coordinates = <Offset>[];
    final colors = <Color>[];
    final indices = <int>[];
    bool? batchBack;
    void flush() {
      if (positions.isEmpty) return;
      final mesh = ui.Vertices(
        ui.VertexMode.triangles,
        positions,
        textureCoordinates: coordinates,
        colors: colors,
        indices: indices,
      );
      canvas.drawVertices(
        mesh,
        BlendMode.modulate,
        Paint()..shader = batchBack! ? _backTexture : _texture,
      );
      mesh.dispose();
      assert(() {
        _meshDraws++;
        return true;
      }());
      positions.clear();
      coordinates.clear();
      colors.clear();
      indices.clear();
    }

    for (final i in order) {
      final a = points[_direction > 0 ? i : i + 1];
      final b = points[_direction > 0 ? i + 1 : i];
      final sx = (_direction > 0 ? i : bands - i - 1) * strip;
      final dx = b.x - a.x;
      if (dx.abs() < .001) continue;
      final normal = math.cos(angleAt((i + .5) / bands));
      final back = normal < 0;
      if (batchBack != null && back != batchBack) flush();
      batchBack = back;
      Color shadeAt(int edge) => Color.lerp(
        const Color(0xffffffff),
        const Color(0xff000000),
        (1 - math.cos(angleAt(edge / bands)).abs()) * .17 + lift * .025,
      )!;
      final ca = back
          ? const Color(0xffffffff)
          : shadeAt(_direction > 0 ? i : i + 1);
      final cb = back
          ? const Color(0xffffffff)
          : shadeAt(_direction > 0 ? i + 1 : i);
      final vertex = positions.length;
      positions.addAll([
        Offset(a.x, h * (1 - a.scale) / 2),
        Offset(b.x, h * (1 - b.scale) / 2),
        Offset(a.x, h * (1 + a.scale) / 2),
        Offset(b.x, h * (1 + b.scale) / 2),
      ]);
      coordinates.addAll([
        Offset(sx * _pixelRatio, 0),
        Offset((sx + strip) * _pixelRatio, 0),
        Offset(sx * _pixelRatio, h * _pixelRatio),
        Offset((sx + strip) * _pixelRatio, h * _pixelRatio),
      ]);
      colors.addAll([ca, cb, ca, cb]);
      indices.addAll([
        vertex,
        vertex + 1,
        vertex + 2,
        vertex + 2,
        vertex + 1,
        vertex + 3,
      ]);
    }
    flush();
    canvas.restore();
  }
}
