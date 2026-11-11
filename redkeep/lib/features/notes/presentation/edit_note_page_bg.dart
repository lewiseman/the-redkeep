import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shows [image] as a cover background, untinted, when provided.
/// Otherwise, a still, seeded wash of soft color blooms over warm paper.
class EditNotepageBg extends StatefulWidget {
  const EditNotepageBg({
    super.key,
    required this.builder,
    this.seed = 0,
    this.color,
    this.image,
  });

  /// Builds the foreground with the paper opacity: 78% over the wash and 62%
  /// over an image, which the paper frosts so writing stays readable.
  /// [imageHeaderColor] is the color of the visible top of the image,
  /// falling back to the surface while loading or on failure.
  /// It is null when no image is selected.
  final Widget Function(
    BuildContext context,
    Animation<double> paperOpacity,
    Color? imageHeaderColor,
  )
  builder;
  final int seed;
  final Color? color;
  final ImageProvider? image;

  @override
  State<EditNotepageBg> createState() => _EditNotepageBgState();
}

class _EditNotepageBgState extends State<EditNotepageBg> {
  late _WashField _field = _WashField(widget.seed);
  ImageStream? _imageStream;
  late final _imageListener = ImageStreamListener(
    _onImage,
    onError: (Object error, StackTrace? stack) {
      _headerRequest++;
      _headerImage?.dispose();
      _headerImage = null;
      if (mounted) setState(() => _imageHeaderColor = null);
    },
  );
  ImageInfo? _headerImage;
  Color? _imageHeaderColor;
  int _headerRequest = 0;
  Size _backgroundSize = Size.zero;

  void _resolveHeaderImage() {
    final stream = widget.image?.resolve(
      createLocalImageConfiguration(context),
    );
    if (stream?.key == _imageStream?.key) {
      _sampleImageHeader();
      return;
    }
    _headerRequest++;
    _imageStream?.removeListener(_imageListener);
    _headerImage?.dispose();
    _headerImage = null;
    _imageHeaderColor = null;
    _imageStream = stream;
    stream?.addListener(_imageListener);
  }

  void _onImage(ImageInfo image, bool synchronousCall) {
    _headerImage?.dispose();
    _headerImage = image;
    _sampleImageHeader();
  }

  Future<void> _sampleImageHeader() async {
    final info = _headerImage;
    if (info == null) return;
    final size = _backgroundSize;
    if (size.isEmpty) return;
    final request = ++_headerRequest;
    final image = info.image.clone();
    final surface = Theme.of(context).colorScheme.surface;
    final headerHeight =
        (MediaQuery.viewPaddingOf(context).top + kToolbarHeight).clamp(
          1.0,
          size.height,
        );
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.cover, imageSize, size);
    final source = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & imageSize,
    );
    // Match Image's centered cover crop, then inspect only the exposed header.
    final header = Rect.fromLTWH(
      source.left,
      source.top,
      source.width,
      source.height * headerHeight / size.height,
    );
    ui.Image? sample;
    ui.Picture? picture;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const target = Rect.fromLTWH(0, 0, 32, 8);
      canvas.drawColor(surface, BlendMode.src);
      canvas.drawImageRect(
        image,
        header,
        target,
        Paint()..filterQuality = FilterQuality.low,
      );
      picture = recorder.endRecording();
      sample = await picture.toImage(32, 8);
      final pixels = await sample.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (pixels == null || !mounted || request != _headerRequest) return;
      var red = 0;
      var green = 0;
      var blue = 0;
      for (var i = 0; i < pixels.lengthInBytes; i += 4) {
        red += pixels.getUint8(i);
        green += pixels.getUint8(i + 1);
        blue += pixels.getUint8(i + 2);
      }
      final count = pixels.lengthInBytes ~/ 4;
      final color = Color.fromARGB(
        255,
        red ~/ count,
        green ~/ count,
        blue ~/ count,
      );
      if (color != _imageHeaderColor) setState(() => _imageHeaderColor = color);
    } catch (_) {
      // Keep the theme fallback if this renderer cannot read image pixels.
    } finally {
      sample?.dispose();
      picture?.dispose();
      image.dispose();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveHeaderImage();
  }

  @override
  void didUpdateWidget(covariant EditNotepageBg oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolveHeaderImage();
    if (oldWidget.seed != widget.seed) _field = _WashField(widget.seed);
  }

  @override
  void dispose() {
    _headerRequest++;
    _imageStream?.removeListener(_imageListener);
    _headerImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (size != _backgroundSize) {
        _backgroundSize = size;
        _sampleImageHeader();
      }
      return _buildBackground(context);
    },
  );

  Widget _buildBackground(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final child = widget.builder(
      context,
      AlwaysStoppedAnimation<double>(widget.image == null ? .78 : .62),
      widget.image == null ? null : _imageHeaderColor ?? colors.surface,
    );
    if (widget.image != null) {
      return Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                // The artwork is shown as painted: nothing tints or dims it.
                child: RepaintBoundary(
                  child: ColoredBox(
                    color: colors.surface,
                    child: Image(
                      image: widget.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      );
    }
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  isComplex: true,
                  painter: _WashPainter(
                    field: _field,
                    tint: widget.color ?? colors.primary,
                    surface: colors.surface,
                    dark: colors.brightness == Brightness.dark,
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Park–Miller arithmetic stays exact on both the Dart VM and JavaScript.
/// It also keeps compositions stable across changes to Dart's Random class.
class _PrintRandom {
  _PrintRandom(int seed) : _state = seed % 2147483646 + 1;

  int _state;

  double next() {
    _state = (_state * 48271) % 2147483647;
    return _state / 2147483647;
  }
}

/// Four seeded blooms near the corners. Resizing returns to the seed instead of
/// advancing a shared random stream.
class _WashField {
  _WashField(this.seed);

  final int seed;
  Size? _size;
  List<_Bloom> blooms = [];

  void layout(Size size) {
    if (size == _size) return;
    _size = size;
    final random = _PrintRandom(seed);
    final unit = size.shortestSide;
    final mirror = random.next() > .5;
    Offset point(double x, double y) =>
        Offset(size.width * (mirror ? 1 - x : x), size.height * y);

    blooms = [
      _Bloom(
        point(.02, .035 + random.next() * .04),
        unit * (.76 + random.next() * .12),
      ),
      _Bloom(point(.92, -.055), unit * (.58 + random.next() * .12)),
      _Bloom(
        point(1.04, .99 + random.next() * .025),
        unit * (.84 + random.next() * .14),
      ),
      _Bloom(point(.05, 1.075), unit * (.64 + random.next() * .1)),
    ];
  }
}

class _Bloom {
  const _Bloom(this.center, this.radius);

  final Offset center;
  final double radius;
}

class _WashPalette {
  _WashPalette(Color source, Color surface, bool dark) {
    final hsl = HSLColor.fromColor(source);
    final saturation = (hsl.saturation * .7 + .1).clamp(.12, .65);
    Color tone(double shift, double saturation, double lightness) =>
        HSLColor.fromAHSL(
          1,
          (hsl.hue + shift) % 360,
          saturation,
          lightness,
        ).toColor();
    paper = Color.lerp(
      surface,
      dark ? const Color(0xff242320) : const Color(0xfff5efe3),
      .6,
    )!;
    final clay = Color.lerp(
      tone(190, saturation * .7, dark ? .57 : .52),
      const Color(0xffbd8266),
      .38,
    )!;
    colors = [
      tone(0, saturation, dark ? .56 : .42),
      clay,
      tone(-32, saturation * .65, dark ? .51 : .48),
      Color.lerp(tone(30, saturation, .55), const Color(0xffc9a36a), .68)!,
    ];
  }

  late final Color paper;
  late final List<Color> colors;
}

class _WashPainter extends CustomPainter {
  const _WashPainter({
    required this.field,
    required this.tint,
    required this.surface,
    required this.dark,
  });

  final _WashField field;
  final Color tint;
  final Color surface;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    field.layout(size);
    final bounds = Offset.zero & size;
    final palette = _WashPalette(tint, surface, dark);
    canvas.drawColor(palette.paper, BlendMode.srcOver);
    for (var i = 0; i < field.blooms.length; i++) {
      final bloom = field.blooms[i];
      final color = palette.colors[i];
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = ui.Gradient.radial(bloom.center, bloom.radius, [
            color.withValues(alpha: .25),
            color.withValues(alpha: 0),
          ]),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WashPainter oldDelegate) =>
      field != oldDelegate.field ||
      tint != oldDelegate.tint ||
      surface != oldDelegate.surface ||
      dark != oldDelegate.dark;
}
