// Renders the promo video's graphics: backgrounds, phone frames, caption
// plates and the animated title, Maester, closing and signature sequences.
//
// Offline and not part of the app's test suite. Run from `redkeep/`:
//   flutter test tool/promo/promo_render_test.dart
// Inputs and outputs live in docs/play-store/promo-video/work (git-ignored).
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _work = 'docs/play-store/promo-video/work';
const _out = '$_work/gfx';
const _fps = 60;

const _ink = Color(0xFF2F2A26);
const _olive = Color(0xFF66753A);
const _plum = Color(0xFF3D3266);
const _muted = Color(0xFF6E665C);

/// One video shape: the canvas and where the phone's screen sits on it.
class Format {
  const Format(this.name, this.size, this.screen, this.bezel);
  final String name;
  final Size size;
  final Rect screen;
  final double bezel;
  bool get wide => size.width > size.height;
}

// The recordings are 1080x2424; both screens keep that shape.
const _wide = Format(
  'wide',
  Size(1920, 1080),
  Rect.fromLTWH(1173, 75, 414, 930),
  13,
);
const _tall = Format(
  'tall',
  Size(1080, 1920),
  Rect.fromLTWH(219, 410, 642, 1440),
  18,
);
const _formats = [_wide, _tall];

/// Caption plates, one per app scene: kicker, headline.
const _captions = <String, (String, String)>{
  's03': ('Welcome', 'Opens like a book'),
  's04': ('Diary', 'Keep the moments'),
  's05': ('Moods', 'Every day has a feeling'),
  's06': ('Write', 'A page for every day'),
  's07': ('Photo stories', 'Every moment, captioned'),
  's08': ('Memories', 'A raven brings them back'),
  's09': ('Calendar', 'A day, a week, a whole year'),
  's10': ('Search', 'A few words bring it back'),
  's11': ('Notes', 'Thoughts worth keeping'),
  's12': ('Checklists', 'Tick it off, right there'),
  's13': ('Backgrounds', 'Colour, art or any photo'),
  's14': ('Dictation', 'Just speak'),
  's17': ('The Maester', 'Ask, and it’s written'),
  's16': ('Suggestions', 'Titles and tags, found for you'),
  's19': ('Your AI', 'Your key stays on your phone'),
  's20': ('Watchlist', 'Every story, on one wall'),
  's21': ('Explore', 'Find something by mood'),
  's22': ('Track', 'Stamp it. Tick it. List it.'),
  's23': ('Can’t choose?', 'Let it pick one for you'),
  's24': ('Appearance', 'Make it yours'),
  's25': ('Widgets', 'Right on your home screen'),
  's26': ('Always yours', 'Safe, even offline'),
};

late ui.Image _paper, _maester;

void main() {
  testWidgets('render promo graphics', (tester) async {
    await tester.runAsync(() async {
      await _loadFonts();
      _paper = await _decode('assets/branding/ink-paper.webp');
      _maester = await _decode('assets/branding/grand_maestar.png');
    });
    final only = Platform.environment['PROMO_ONLY'];
    bool want(String name) => only == null || only.split(',').contains(name);

    for (final f in _formats) {
      if (want('static')) {
        await _shot(tester, f, _Background(f), '$_out/${f.name}/bg.png');
        await _shot(tester, f, _PhoneFrame(f), '$_out/${f.name}/phone.png');
        for (final MapEntry(:key, :value) in _captions.entries) {
          await _shot(
            tester,
            f,
            _Caption(f, value.$1, value.$2),
            '$_out/${f.name}/cap_$key.png',
          );
        }
      }
      final sequences = <String, (double, Widget Function(double))>{
        'intro': (6.6, (t) => _Intro(f, t)),
        'title': (3.6, (t) => _Title(f, t)),
        'maester': (4.4, (t) => _MaesterIntro(f, t)),
        'closing': (7.0, (t) => _Closing(f, t)),
        'signature': (4.6, (t) => _Signature(f, t)),
      };
      for (final MapEntry(:key, :value) in sequences.entries) {
        if (!want(key)) continue;
        await _sequence(
          tester,
          f,
          value.$1,
          value.$2,
          '$_out/${f.name}/$key.mp4',
        );
      }
    }
  }, timeout: Timeout.none);
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(File('$_work/fonts/$file').readAsBytesSync()),
        ),
      );
    }
    await loader.load();
  }

  await load('Lora', ['Lora.ttf']);
  await load('LoraItalic', ['Lora-Italic.ttf']);
  await load('Caveat', ['Caveat-Medium.ttf']);
  await load('Poppins', ['Poppins-Regular.ttf']);
  await load('PoppinsSemi', ['Poppins-SemiBold.ttf']);
  await load('Allura', ['Allura.ttf']);
}

Future<ui.Image> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

Future<void> _shot(
  WidgetTester tester,
  Format f,
  Widget child,
  String path,
) async {
  tester.view.physicalSize = f.size;
  tester.view.devicePixelRatio = 1;
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: f.size),
        child: RepaintBoundary(
          key: key,
          child: SizedBox.fromSize(size: f.size, child: child),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Streams a full-frame animation straight into ffmpeg as raw RGBA.
Future<void> _sequence(
  WidgetTester tester,
  Format f,
  double seconds,
  Widget Function(double) frame,
  String path,
) async {
  tester.view.physicalSize = f.size;
  tester.view.devicePixelRatio = 1;
  Directory(File(path).parent.path).createSync(recursive: true);
  final w = f.size.width.toInt(), h = f.size.height.toInt();
  final ffmpeg = (await tester.runAsync(
    () => Process.start('ffmpeg', [
      '-y',
      '-v',
      'error',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      '-s',
      '${w}x$h',
      '-r',
      '$_fps',
      '-i',
      '-',
      '-c:v',
      'libx264',
      '-preset',
      'medium',
      '-crf',
      '14',
      '-pix_fmt',
      'yuv420p',
      path,
    ]),
  ))!;
  final key = GlobalKey();
  final count = (seconds * _fps).round();
  for (var i = 0; i < count; i++) {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: f.size),
          child: RepaintBoundary(
            key: key,
            child: SizedBox.fromSize(size: f.size, child: frame(i / _fps)),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      ffmpeg.stdin.add(bytes!.buffer.asUint8List());
      await ffmpeg.stdin.flush();
    });
  }
  await tester.runAsync(() async {
    await ffmpeg.stdin.close();
    if (await ffmpeg.exitCode != 0) throw StateError('ffmpeg failed for $path');
  });
}

// ---------------------------------------------------------------- helpers

double _clamp(double v) => v.clamp(0.0, 1.0);

/// 0 before [a], 1 after [b], eased between.
double _ease(
  double t,
  double a,
  double b, [
  Curve curve = Curves.easeOutCubic,
]) => curve.transform(_clamp((t - a) / (b - a)));

TextStyle _lora(double size, {Color color = _ink, double weight = 500}) =>
    TextStyle(
      fontFamily: 'Lora',
      fontSize: size,
      color: color,
      height: 1.08,
      fontVariations: [FontVariation('wght', weight)],
    );

TextStyle _caveat(double size, {Color color = _olive}) =>
    TextStyle(fontFamily: 'Caveat', fontSize: size, color: color, height: 1.1);

TextStyle _poppins(double size, {Color color = _muted}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: size, color: color, height: 1.4);

/// Reveals [child] left to right, as if it were being written.
class _WriteOn extends StatelessWidget {
  const _WriteOn({required this.progress, required this.child});
  final double progress;
  final Widget child;
  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => LinearGradient(
      colors: const [Colors.white, Colors.white, Colors.transparent],
      stops: [0, _clamp(progress), _clamp(progress + 0.06)],
    ).createShader(rect),
    child: child,
  );
}

class _Paper extends CustomPainter {
  const _Paper();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7F2E8), Color(0xFFF1EBE2), Color(0xFFECE6F0)],
        ).createShader(rect),
    );
    // The app's ink paper, laid faintly over the gradient.
    final src =
        Offset.zero & Size(_paper.width.toDouble(), _paper.height.toDouble());
    final fit = applyBoxFit(BoxFit.cover, src.size, size);
    final from = Alignment.center.inscribe(fit.source, src);
    canvas.drawImageRect(
      _paper,
      from,
      rect,
      Paint()
        ..filterQuality = FilterQuality.high
        ..color = const Color.fromRGBO(255, 255, 255, 0.35),
    );
  }

  @override
  bool shouldRepaint(_Paper old) => false;
}

class _Background extends StatelessWidget {
  const _Background(this.f);
  final Format f;
  @override
  Widget build(BuildContext context) => const CustomPaint(painter: _Paper());
}

/// The handset drawn around the screen: transparent where the recording
/// shows through, and everywhere outside the phone except its shadow.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame(this.f);
  final Format f;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PhonePainter(f));
}

class _PhonePainter extends CustomPainter {
  const _PhonePainter(this.f);
  final Format f;
  @override
  void paint(Canvas canvas, Size size) {
    final s = f.screen;
    final b = f.bezel;
    final screenRadius = s.width * 0.085;
    final outer = RRect.fromRectAndRadius(
      s.inflate(b),
      Radius.circular(screenRadius + b),
    );
    final hole = RRect.fromRectAndRadius(s, Radius.circular(screenRadius));
    // Shadow, kept outside the phone so it never darkens the screen.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRRect(
      outer.shift(Offset(0, b * 2.2)),
      Paint()
        ..color = const Color(0x55302418)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, b * 3.2),
    );
    canvas.drawRRect(
      outer.shift(Offset(0, b * 0.6)),
      Paint()
        ..color = const Color(0x33302418)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, b * 0.8),
    );
    canvas.drawRRect(outer, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
    // Bezel with a soft rim.
    final body = Path()
      ..addRRect(outer)
      ..addRRect(hole)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A3632), Color(0xFF161412), Color(0xFF2A2724)],
        ).createShader(outer.outerRect),
    );
    canvas.drawRRect(
      outer.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x40FFFFFF),
    );
    // Camera punch hole over the status bar.
    canvas.drawCircle(
      Offset(s.center.dx, s.top + s.width * 0.042),
      s.width * 0.018,
      Paint()..color = const Color(0xFF0B0B0B),
    );
  }

  @override
  bool shouldRepaint(_PhonePainter old) => false;
}

/// A short olive pen stroke under a kicker.
class _Squiggle extends CustomPainter {
  const _Squiggle(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height * 0.6);
    const waves = 3;
    for (var i = 0; i < waves; i++) {
      final x0 = size.width * i / waves;
      final x1 = size.width * (i + 1) / waves;
      path.cubicTo(
        x0 + (x1 - x0) * 0.3,
        0,
        x0 + (x1 - x0) * 0.7,
        size.height,
        x1,
        size.height * (i.isEven ? 0.4 : 0.6),
      );
    }
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * _clamp(progress)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = size.height * 0.28
        ..color = _olive.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(_Squiggle old) => old.progress != progress;
}

class _Caption extends StatelessWidget {
  const _Caption(this.f, this.kicker, this.headline);
  final Format f;
  final String kicker, headline;
  @override
  Widget build(BuildContext context) {
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: f.wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(kicker, style: _caveat(f.wide ? 66 : 64)),
        SizedBox(
          width: f.wide ? 150 : 140,
          height: 16,
          child: const CustomPaint(painter: _Squiggle(1)),
        ),
        SizedBox(height: f.wide ? 26 : 22),
        Text(
          headline,
          textAlign: f.wide ? TextAlign.start : TextAlign.center,
          style: _lora(f.wide ? 96 : 80),
        ),
      ],
    );
    return f.wide
        ? Padding(
            padding: const EdgeInsets.only(left: 150),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 840, child: text),
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(60, 70, 60, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(height: 300, child: Center(child: text)),
            ),
          );
  }
}

class _MaesterFace extends StatelessWidget {
  const _MaesterFace(this.size, {this.glow = 0});
  final double size, glow;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (glow > 0)
          Positioned(
            left: -size * 0.35,
            top: -size * 0.35,
            right: -size * 0.35,
            bottom: -size * 0.35,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFE6A8).withValues(alpha: 0.55 * glow),
                    const Color(0xFFFFE6A8).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        RawImage(
          image: _maester,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ],
    ),
  );
}

class _Heart extends CustomPainter {
  const _Heart();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w / 2, h * 0.92)
      ..cubicTo(w * 0.1, h * 0.62, -w * 0.02, h * 0.3, w * 0.22, h * 0.14)
      ..cubicTo(w * 0.38, h * 0.03, w * 0.5, h * 0.18, w / 2, h * 0.28)
      ..cubicTo(w * 0.5, h * 0.18, w * 0.62, h * 0.03, w * 0.78, h * 0.14)
      ..cubicTo(w * 1.02, h * 0.3, w * 0.9, h * 0.62, w / 2, h * 0.92)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFB3413B));
  }

  @override
  bool shouldRepaint(_Heart old) => false;
}

// -------------------------------------------------------------- sequences

class _Intro extends StatelessWidget {
  const _Intro(this.f, this.t);
  final Format f;
  final double t;
  @override
  Widget build(BuildContext context) {
    final out = 1 - _ease(t, 6.1, 6.6, Curves.easeIn);
    final size = f.wide ? 124.0 : 104.0;
    Widget line(String text, double start, double end) => Opacity(
      opacity: _ease(t, start, start + 0.25),
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - _ease(t, start, end))),
        child: _WriteOn(
          progress: _ease(t, start, end, Curves.easeInOut),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: _caveat(size, color: _ink),
          ),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _Paper()),
        Opacity(
          opacity: out,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  line(
                    f.wide
                        ? 'Some days deserve to be remembered.'
                        : 'Some days deserve\nto be remembered.',
                    0.5,
                    2.4,
                  ),
                  SizedBox(height: f.wide ? 40 : 70),
                  line(
                    f.wide
                        ? 'Some thoughts deserve a place to land.'
                        : 'Some thoughts deserve\na place to land.',
                    3.0,
                    5.1,
                  ),
                  SizedBox(height: f.wide ? 46 : 60),
                  SizedBox(
                    width: 220,
                    height: 22,
                    child: CustomPaint(painter: _Squiggle(_ease(t, 5.0, 5.9))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.f, this.t);
  final Format f;
  final double t;
  @override
  Widget build(BuildContext context) {
    final face = _ease(t, 0.0, 0.9, Curves.easeOutBack);
    final words = _ease(t, 0.35, 1.2);
    final kicker = _ease(t, 0.15, 0.8);
    final out = 1 - _ease(t, 3.1, 3.6, Curves.easeIn);
    final faceSize = f.wide ? 380.0 : 440.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _Paper()),
        Opacity(
          opacity: out,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 0.6 + 0.4 * face,
                  child: Opacity(
                    opacity: _clamp(face),
                    child: _MaesterFace(faceSize, glow: _ease(t, 0.6, 1.6)),
                  ),
                ),
                SizedBox(height: f.wide ? 30 : 60),
                Opacity(
                  opacity: kicker,
                  child: Text(
                    'Welcome to',
                    style: _caveat(
                      f.wide ? 76 : 80,
                      color: const Color(0xFF7B62AE),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Opacity(
                  opacity: words,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - words)),
                    child: Text(
                      'The Redkeep',
                      style: _lora(
                        f.wide ? 170 : 150,
                        color: _plum,
                        weight: 600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MaesterIntro extends StatelessWidget {
  const _MaesterIntro(this.f, this.t);
  final Format f;
  final double t;
  @override
  Widget build(BuildContext context) {
    final rise = _ease(t, 0.0, 1.1, Curves.easeOutBack);
    final glow = _ease(t, 0.5, 1.8) * (0.85 + 0.15 * math.sin(t * 3));
    final out = 1 - _ease(t, 3.9, 4.4, Curves.easeIn);
    final faceSize = f.wide ? 420.0 : 520.0;
    final face = Opacity(
      opacity: _clamp(rise),
      child: Transform.translate(
        offset: Offset(0, 120 * (1 - rise)),
        child: _MaesterFace(faceSize, glow: glow),
      ),
    );
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: f.wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Opacity(
          opacity: _ease(t, 0.6, 1.1),
          child: _WriteOn(
            progress: _ease(t, 0.6, 1.8, Curves.easeInOut),
            child: Text('Meet the Maester', style: _caveat(f.wide ? 92 : 96)),
          ),
        ),
        const SizedBox(height: 18),
        Opacity(
          opacity: _ease(t, 1.4, 2.0),
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _ease(t, 1.4, 2.0))),
            child: Text(
              f.wide
                  ? 'Your writing helper,\nalways at hand'
                  : 'Your writing helper,\nalways at hand',
              textAlign: f.wide ? TextAlign.start : TextAlign.center,
              style: _lora(f.wide ? 84 : 78),
            ),
          ),
        ),
      ],
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _Paper()),
        Opacity(
          opacity: out,
          child: f.wide
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [face, const SizedBox(width: 90), text],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [face, const SizedBox(height: 70), text],
                ),
        ),
      ],
    );
  }
}

class _Closing extends StatelessWidget {
  const _Closing(this.f, this.t);
  final Format f;
  final double t;
  @override
  Widget build(BuildContext context) {
    final title = _ease(t, 0.2, 1.2);
    final line = _ease(t, 1.2, 2.2);
    final out = 1 - _ease(t, 6.5, 7.0, Curves.easeIn);
    final drift = 1 + 0.03 * _clamp(t / 7);
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _Paper()),
        Opacity(
          opacity: out,
          child: Transform.scale(
            scale: drift,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: _ease(t, 0, 0.8),
                    child: _MaesterFace(f.wide ? 200 : 260, glow: 0.6),
                  ),
                  SizedBox(height: f.wide ? 24 : 50),
                  Opacity(
                    opacity: title,
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - title)),
                      child: Text(
                        'The Redkeep',
                        style: _lora(
                          f.wide ? 160 : 140,
                          color: _plum,
                          weight: 600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: f.wide ? 24 : 40),
                  Opacity(
                    opacity: line,
                    child: Text(
                      'A quiet place for your notes, your days\nand the thoughts in between.',
                      textAlign: TextAlign.center,
                      style: _poppins(f.wide ? 44 : 42),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Signature extends StatelessWidget {
  const _Signature(this.f, this.t);
  final Format f;
  final double t;
  @override
  Widget build(BuildContext context) {
    final write = _ease(t, 0.2, 2.0, Curves.easeInOut);
    final heart = _ease(t, 1.7, 2.5, Curves.easeOutBack);
    final out = 1 - _ease(t, 4.0, 4.6, Curves.easeIn);
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _Paper()),
        Opacity(
          opacity: out,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: _ease(t, 0.1, 0.5),
                  child: Text(
                    'made with love by',
                    style: _caveat(f.wide ? 70 : 72, color: _muted),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WriteOn(
                      progress: write,
                      child: Text(
                        'Lewis',
                        style: TextStyle(
                          fontFamily: 'Allura',
                          fontSize: f.wide ? 230 : 220,
                          color: _plum,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Transform.scale(
                      scale: heart,
                      child: SizedBox.square(
                        dimension: f.wide ? 86 : 84,
                        child: const CustomPaint(painter: _Heart()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
