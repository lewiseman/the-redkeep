import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/presentation/cushion.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../assets/presentation/local_artwork.dart';
import '../../sync/presentation/sync_material.dart';
import '../domain/catalog_title.dart';
import '../domain/watch_title.dart';
import 'stamp_feel.dart';
import 'watch_host.dart';
import 'watch_title_extras.dart';
import 'watch_wall.dart';
import 'watch_widgets.dart';

/// Each status's ink, as it prints from the rack.
Color stampInk(WatchStatus status) => switch (status) {
  WatchStatus.planned => const Color(0xff5f7d3a),
  WatchStatus.watching => const Color(0xffc77d1a),
  WatchStatus.completed => const Color(0xffbf3a2c),
  WatchStatus.paused => const Color(0xff4f6a8f),
  WatchStatus.dropped => const Color(0xff5d5a55),
};

/// Rubber stamps standing in a wooden rail under the thumb, one a status,
/// with the page fading away behind them. Tap one to stamp
/// the title, or lift it up onto the poster and let go. The inked one is
/// the title's status; tapping it again lifts the status off.
class StampRack extends StatefulWidget {
  const StampRack({super.key, required this.status, required this.onStamp});

  final WatchStatus? status;
  final ValueChanged<WatchStatus> onStamp;

  @override
  State<StampRack> createState() => _StampRackState();
}

/// When the status changes the rack rattles: the stamps wobble in their
/// slots, each its own way, the rack gives a little shudder, and the phone
/// clicks a few times as they settle, like wood clattering on wood.
class _StampRackState extends State<StampRack>
    with SingleTickerProviderStateMixin {
  late final _rattle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..addListener(_clatter);

  /// The clicks of the stamps settling, as fractions of the rattle.
  static const _clicks = [.2, .38, .56];
  int _clicked = _clicks.length;

  /// Started a little after the change, so it follows the thump's landing.
  static const _delay = .32;

  @override
  void didUpdateWidget(StampRack old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) _start();
  }

  void _start() {
    _clicked = 0;
    if (RenderingPolicyScope.of(context).animate) {
      _rattle.forward(from: 0);
    } else {
      _clicked = _clicks.length;
    }
  }

  void _clatter() {
    while (_clicked < _clicks.length &&
        _rattle.value >= _delay + _clicks[_clicked] * (1 - _delay)) {
      _clicked++;
      StampFeel.click();
    }
  }

  @override
  void dispose() {
    _rattle.dispose();
    super.dispose();
  }

  /// How much the rattle has left in it at this moment, -1 to 1, swinging
  /// [cycles] times and dying away; 0 before it starts and once it is over.
  double _swing(double cycles, {double phase = 0}) {
    final v = _rattle.value;
    if (!_rattle.isAnimating || v < _delay) return 0;
    final t = (v - _delay) / (1 - _delay);
    return math.sin((t * cycles + phase) * math.pi * 2) * math.pow(1 - t, 2);
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final onStamp = widget.onStamp;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
    final ground = MorePalette.of(context).ground;
    return DecoratedBox(
      // The page fades away behind the rack, so whatever scrolls under it
      // never meets an edge.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ground.withValues(alpha: 0),
            ground.withValues(alpha: .82),
            ground,
          ],
          stops: const [0, .38, .62],
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: LayoutBuilder(
                builder: (context, box) {
                  final width = box.maxWidth;
                  final height = width * _Rack.aspect;
                  return AnimatedBuilder(
                    animation: _rattle,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(_swing(5) * 1.6, 0),
                      child: child,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // The wooden rack the stamps stand in.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: height,
                          child: const _RackImage(),
                        ),
                        // One stamp over each slot, its rubber down past the
                        // slot's front lip.
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            width * _Rack.inset,
                            0,
                            width * _Rack.inset,
                            height * (1 - _Rack.seat),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Right to left, so Planned sits at the right.
                              for (final s in WatchStatus.values.reversed)
                                Expanded(
                                  child: AnimatedBuilder(
                                    animation: _rattle,
                                    // Each wobbles its own way, the stamp just
                                    // printed least.
                                    builder: (context, child) =>
                                        Transform.rotate(
                                          alignment: Alignment.bottomCenter,
                                          angle:
                                              _swing(
                                                4 + s.index * .35,
                                                phase: s.index * .21,
                                              ) *
                                              (s == status ? .015 : .05),
                                          child: child,
                                        ),
                                    child: _StampKey(
                                      status: s,
                                      inked: s == status,
                                      scale: scale,
                                      onStamp: () => onStamp(s),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // The rack's front again, over the stamps' feet, so
                        // each sits down in its slot.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: height * (1 - _Rack.lip),
                          child: IgnorePointer(
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.bottomCenter,
                                minHeight: height,
                                maxHeight: height,
                                child: const _RackImage(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How much of the bottom of the screen the stamp rack covers, for pages
/// to scroll their last part clear of it.
double stampRackHeight(BuildContext context) {
  final media = MediaQuery.of(context);
  final width = math.min(media.size.width - 32, 560.0);
  final rack = width * _Rack.aspect;
  // Each stamp is as wide as its slot's share of the rack.
  final cell = width * (1 - _Rack.inset * 2) / WatchStatus.values.length - 4;
  final stamp = cell / _StampArt.aspect;
  // The fade above, the stamps standing over the rack, and the rack's front.
  return 28 +
      stamp +
      rack * (1 - _Rack.seat) +
      math.max(10.0, media.padding.bottom);
}

/// Measurements of the wooden rack.
abstract final class _Rack {
  /// The rack image's height over its width.
  static const aspect = 201 / 1168;

  /// Where the first slot's cell begins, as a fraction of the width; the
  /// five slots then share the width between this and the same at the end.
  static const inset = .0694;

  /// Down the rack's height: the slots' front lip, and where the stamps'
  /// rubber rests, just below it.
  static const lip = .31;
  static const seat = .35;
}

/// The rack, from its bundled picture; the drawn one stands in while
/// the picture decodes.
class _RackImage extends StatelessWidget {
  const _RackImage();

  static const artwork = 'watchlist.rack';

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    final drawn = CustomPaint(
      painter: _RackPainter(
        cushion,
        count: WatchStatus.values.length,
        inset: .0694,
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final pixels = (box.maxWidth * MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(1, 1168);
        return Image(
          image: artworkImage(artwork, width: pixels),
          fit: BoxFit.fill,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          frameBuilder: (_, child, frame, synchronous) =>
              frame == null && !synchronous ? drawn : child,
          errorBuilder: (_, _, _) => drawn,
        );
      },
    );
  }
}

/// Wood colours, light and deep, for the current theme.
(Color, Color) _wood(CushionColors c) => c.dark
    ? (const Color(0xff7c5838), const Color(0xff47301d))
    : (const Color(0xffd2a676), const Color(0xff8c5e37));

/// Fine wavy grain across [rect], steady for a [seed].
void _paintGrain(Canvas canvas, Rect rect, int seed, Color colour) {
  final random = math.Random(seed);
  final grain = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = .7;
  for (var y = rect.top + 1.5; y < rect.bottom - .5; y += 2.2) {
    grain.color = colour.withValues(alpha: .05 + random.nextDouble() * .1);
    final wave = 0.4 + random.nextDouble() * 1.2;
    final phase = random.nextDouble() * math.pi * 2;
    final path = Path()..moveTo(rect.left, y);
    for (var x = rect.left; x <= rect.right; x += 6) {
      path.lineTo(x, y + math.sin(x / 23 + phase) * wave);
    }
    canvas.drawPath(path, grain);
  }
}

/// A rack of oiled wood seen a little from above: a lit top surface with a
/// slot under each stamp and a soft shadow where each stands, a grained
/// front face, and a brass screw at each end.
class _RackPainter extends CustomPainter {
  const _RackPainter(this.colors, {required this.count, required this.inset});
  final CushionColors colors;
  final int count;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final c = colors;
    final (light, deep) = _wood(c);
    final whole = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(7),
    );
    if (!c.simple) {
      canvas.drawRRect(
        whole.shift(const Offset(0, 5)),
        Paint()
          ..color = c.shadow.withValues(alpha: c.dark ? .45 : .2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
    canvas.save();
    canvas.clipRRect(whole);
    // The top surface, lit from above.
    final top = Rect.fromLTWH(0, 0, size.width, size.height * .35);
    canvas.drawRect(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(light, Colors.white, c.dark ? .05 : .22)!, light],
        ).createShader(top),
    );
    // The front face, in shade.
    final front = Rect.fromLTRB(0, size.height * .35, size.width, size.height);
    canvas.drawRect(
      front,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(light, deep, .45)!, deep],
        ).createShader(front),
    );
    if (!c.simple) {
      _paintGrain(canvas, top, 11, Colors.black);
      _paintGrain(canvas, front, 23, Colors.black);
      // The edge where top meets front catches the light.
      canvas.drawLine(
        Offset(0, size.height * .35),
        Offset(size.width, size.height * .35),
        Paint()
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: c.dark ? .12 : .3),
      );
      // A slot and a contact shadow under each stamp.
      final margin = size.width * inset;
      final step = (size.width - margin * 2) / count;
      for (var i = 0; i < count; i++) {
        final centre = margin + step * (i + .5);
        final slot = Rect.fromCenter(
          center: Offset(centre, size.height * .2),
          width: step * .8,
          height: 4.5,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(slot, const Radius.circular(2.5)),
          Paint()..color = Colors.black.withValues(alpha: c.dark ? .4 : .28),
        );
        canvas.drawOval(
          slot.inflate(3).shift(const Offset(0, 1)),
          Paint()
            ..color = Colors.black.withValues(alpha: .14)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
      // Brass screws at either end of the front.
      for (final x in [margin * .55, size.width - margin * .55]) {
        final centre = Offset(x, size.height * .66);
        canvas.drawCircle(
          centre,
          3.4,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-.4, -.5),
              colors: [Color(0xfff5dfa0), Color(0xffb08a3c), Color(0xff6e5420)],
              stops: [0, .55, 1],
            ).createShader(Rect.fromCircle(center: centre, radius: 3.4)),
        );
        canvas.drawLine(
          centre.translate(-2.2, 1),
          centre.translate(2.2, -1),
          Paint()
            ..strokeWidth = .9
            ..color = const Color(0xff4a3812),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RackPainter old) =>
      old.colors != colors || old.count != count || old.inset != inset;
}

class _StampKey extends StatefulWidget {
  const _StampKey({
    required this.status,
    required this.inked,
    required this.scale,
    required this.onStamp,
  });

  final WatchStatus status;
  final bool inked;
  final double scale;
  final VoidCallback onStamp;

  @override
  State<_StampKey> createState() => _StampKeyState();
}

/// Tapped, a stamp acts out a stamping: up off the rail, a hard thump down
/// with a squash, and a little bounce back into its slot.
class _StampKeyState extends State<_StampKey>
    with SingleTickerProviderStateMixin {
  late final _thump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  )..addListener(_landing);
  bool _landed = false;

  static final _travel = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: -16.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 32,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: -16.0,
        end: 4.0,
      ).chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 20,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 4.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 48,
    ),
  ]);

  /// When the stamp meets the rail, as a fraction of the thump.
  static const _impact = .52;

  void _landing() {
    if (!_landed && _thump.value >= _impact) {
      _landed = true;
      StampFeel.thud();
    }
  }

  void _press() {
    if (RenderingPolicyScope.of(context).animate) {
      _landed = false;
      _thump.forward(from: 0);
    } else {
      StampFeel.thud();
    }
    widget.onStamp();
  }

  @override
  void dispose() {
    _thump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final inked = widget.inked;
    final ink = stampInk(status);
    final stamp = _Stamp(status: status, inked: inked, scale: widget.scale);
    return Semantics(
      container: true,
      button: true,
      selected: inked,
      label: inked ? '${status.action}, stamped' : status.action,
      hint: inked ? 'Tap to lift the stamp off' : null,
      excludeSemantics: true,
      onTap: _press,
      child: Draggable<WatchStatus>(
        data: status,
        affinity: Axis.vertical,
        onDragStarted: StampFeel.lift,
        feedback: Material(
          type: MaterialType.transparency,
          child: Transform.rotate(
            angle: -.18,
            child: Transform.scale(
              scale: 1.5,
              child: InkStamp(label: status.label.toUpperCase(), ink: ink),
            ),
          ),
        ),
        feedbackOffset: const Offset(0, -24),
        childWhenDragging: Opacity(opacity: .25, child: stamp),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _press,
          child: AnimatedBuilder(
            animation: _thump,
            child: stamp,
            builder: (context, child) {
              final v = _thump.value;
              // Squashed for a moment as it hits.
              final hit = (1 - (v - _impact).abs() / .14).clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(
                  0,
                  _thump.isAnimating ? _travel.transform(v) : 0,
                ),
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(
                    1 + .05 * hit,
                    1 - .08 * hit,
                    1,
                  ),
                  child: child,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Where things are on the stamp picture, as fractions of its box.
abstract final class _StampArt {
  static const artwork = 'watchlist.stamp';

  /// Width over height of the picture.
  static const aspect = 868 / 1153;

  /// The varnished dome of the knob.
  static const dome = Rect.fromLTRB(.155, 0, .835, .325);

  /// The paper label on the block's face.
  static const label = Rect.fromLTRB(.0841, .7112, .9136, .9055);

  /// The rubber die at the foot.
  static const rubber = Rect.fromLTRB(.0357, .9688, .963, 1);
}

/// A colour filter that turns the picture to [ink] while keeping its light
/// and shade: grain and varnish highlights survive, transparency too.
ColorFilter _lacquer(Color ink) {
  const gain = 1.9;
  final r = ink.r * gain, g = ink.g * gain, b = ink.b * gain;
  return ColorFilter.matrix([
    .3 * r, .59 * r, .11 * r, 0, 0, //
    .3 * g, .59 * g, .11 * g, 0, 0,
    .3 * b, .59 * b, .11 * b, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

/// One rubber stamp picture, dressed per status: its knob lacquered in the
/// status's ink, the status printed on its label, and its rubber dry or,
/// on the title's own stamp, wet with ink and its label filled. Each leans
/// its own small way.
class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.status,
    required this.inked,
    required this.scale,
  });

  final WatchStatus status;
  final bool inked;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    final policy = RenderingPolicyScope.of(context);
    final ink = stampInk(status);
    final lean = cushion.simple ? 0.0 : ((status.index * 7) % 5 - 2) * .006;
    final body = _pictured(context, ink, cushion, policy);
    return AnimatedSlide(
      duration: policy.duration,
      curve: Curves.easeOut,
      offset: Offset(0, inked ? .03 : 0),
      child: Transform.rotate(
        angle: lean,
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AspectRatio(aspectRatio: _StampArt.aspect, child: body),
        ),
      ),
    );
  }

  Widget _drawn() => FittedBox(
    child: SizedBox(
      width: 64,
      child: _DrawnStamp(status: status, inked: inked, scale: scale),
    ),
  );

  Widget _pictured(
    BuildContext context,
    Color ink,
    CushionColors cushion,
    RenderingPolicy policy,
  ) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final pixels = (w * MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(1, 360);
        final picture = Image(
          image: artworkImage(_StampArt.artwork, width: pixels),
          fit: BoxFit.fill,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => _drawn(),
        );
        Rect at(Rect fraction) => Rect.fromLTRB(
          fraction.left * w,
          fraction.top * h,
          fraction.right * w,
          fraction.bottom * h,
        );
        final dome = at(_StampArt.dome);
        final label = at(_StampArt.label);
        final rubber = at(_StampArt.rubber);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: picture),
            // The knob, lacquered in the status's ink: fully on the title's
            // stamp, more softly on the rest.
            Positioned.fill(
              child: ClipOval(
                clipper: _RectClipper(dome),
                child: AnimatedOpacity(
                  duration: policy.duration,
                  opacity: inked ? .95 : .62,
                  child: ColorFiltered(
                    colorFilter: _lacquer(ink),
                    child: picture,
                  ),
                ),
              ),
            ),
            // The status on the label; filled with ink on the title's stamp.
            Positioned.fromRect(
              rect: label,
              child: AnimatedContainer(
                duration: policy.duration,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(
                  horizontal: label.width * .06,
                  vertical: label.height * .12,
                ),
                decoration: BoxDecoration(
                  color: inked ? ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(label.height * .08),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    status.label.toUpperCase(),
                    maxLines: 1,
                    textScaler: TextScaler.linear(scale),
                    style: TextStyle(
                      color: inked ? Colors.white : ink,
                      fontSize: 12,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            // The rubber: wet with fresh ink on the title's stamp.
            if (inked)
              Positioned.fromRect(
                rect: rubber,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.lerp(ink, Colors.black, .12),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(2),
                    ),
                    boxShadow: cushion.simple
                        ? null
                        : [
                            BoxShadow(
                              color: ink.withValues(alpha: .5),
                              blurRadius: 6,
                            ),
                          ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Clips to one rectangle of its box, as an oval.
class _RectClipper extends CustomClipper<Rect> {
  const _RectClipper(this.rect);
  final Rect rect;

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(_RectClipper old) => old.rect != rect;
}

/// A drawn wooden rubber stamp, standing in while the picture is read: a
/// turned and varnished
/// knob with a cap in its ink's colour, a grooved neck, a bevelled block
/// with a paper index label, and a foam-backed rubber die beneath. The
/// title's stamp has its label filled and its rubber wet with fresh ink,
/// and sits a little lower in its slot. Each leans its own small way.
class _DrawnStamp extends StatelessWidget {
  const _DrawnStamp({
    required this.status,
    required this.inked,
    required this.scale,
  });

  final WatchStatus status;
  final bool inked;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    final ink = stampInk(status);
    final policy = RenderingPolicyScope.of(context);
    final lean = cushion.simple ? 0.0 : ((status.index * 7) % 5 - 2) * .006;
    return AnimatedSlide(
      duration: policy.duration,
      curve: Curves.easeOut,
      offset: Offset(0, inked ? .04 : 0),
      child: Transform.rotate(
        angle: lean,
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(30, 21),
                painter: _KnobPainter(cushion, ink, inked),
              ),
              CustomPaint(
                size: const Size(22, 10),
                painter: _NeckPainter(cushion),
              ),
              CustomPaint(
                painter: _BlockPainter(cushion, seed: status.index * 31 + 7),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 6, 5, 6),
                  // The paper index label.
                  child: AnimatedContainer(
                    duration: policy.duration,
                    height: 21 * scale,
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: inked
                          ? ink
                          : Color.lerp(
                              cushion.paper,
                              const Color(0xfffffbf0),
                              cushion.dark ? .2 : .7,
                            ),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: .12),
                        width: .6,
                      ),
                      boxShadow: cushion.simple
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .25),
                                blurRadius: 1.5,
                                offset: const Offset(0, .8),
                              ),
                            ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        status.label.toUpperCase(),
                        maxLines: 1,
                        style: TextStyle(
                          color: inked ? Colors.white : ink,
                          fontSize: 11,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              CustomPaint(
                size: const Size(double.infinity, 7),
                painter: _DiePainter(cushion, ink, inked),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The knob: a turned mushroom of varnished wood, with a glossy cap on top
/// in the stamp's ink, full and bright when it is the title's stamp.
class _KnobPainter extends CustomPainter {
  const _KnobPainter(this.colors, this.ink, this.inked);
  final CushionColors colors;
  final Color ink;
  final bool inked;

  @override
  void paint(Canvas canvas, Size size) {
    final (light, deep) = _wood(colors);
    final w = size.width, h = size.height;
    // The wooden dome.
    final dome = Rect.fromLTWH(0, h * .18, w, h * .82);
    canvas.drawOval(
      dome,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.55),
          radius: .95,
          colors: [Color.lerp(light, Colors.white, .35)!, light, deep],
          stops: const [0, .45, 1],
        ).createShader(dome),
    );
    // The coloured cap, seen from a little above.
    final cap = Rect.fromLTWH(w * .14, 0, w * .72, h * .48);
    final capColour = inked ? ink : Color.lerp(ink, colors.paper, .35)!;
    canvas.drawOval(
      cap.shift(const Offset(0, 1.2)),
      Paint()..color = Color.lerp(capColour, Colors.black, .35)!,
    );
    canvas.drawOval(
      cap,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.3, -.4),
          colors: [
            Color.lerp(capColour, Colors.white, .55)!,
            capColour,
            Color.lerp(capColour, Colors.black, .2)!,
          ],
          stops: const [0, .5, 1],
        ).createShader(cap),
    );
    if (colors.simple) return;
    // Varnish catching the light.
    canvas.drawArc(
      Rect.fromLTWH(w * .12, h * .3, w * .76, h * .62),
      math.pi * 1.1,
      math.pi * .45,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: .45),
    );
  }

  @override
  bool shouldRepaint(_KnobPainter old) =>
      old.colors != colors || old.ink != ink || old.inked != inked;
}

/// The turned neck: shaded round, narrow under the knob and flaring to the
/// block, with two cut grooves.
class _NeckPainter extends CustomPainter {
  const _NeckPainter(this.colors);
  final CushionColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final (light, deep) = _wood(colors);
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * .32, 0)
      ..lineTo(w * .68, 0)
      ..quadraticBezierTo(w * .7, h * .7, w, h)
      ..lineTo(0, h)
      ..quadraticBezierTo(w * .3, h * .7, w * .32, 0)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [deep, Color.lerp(light, Colors.white, .2)!, deep],
          stops: const [0, .42, 1],
        ).createShader(Offset.zero & size),
    );
    if (colors.simple) return;
    final groove = Paint()
      ..strokeWidth = .8
      ..color = Colors.black.withValues(alpha: .3);
    for (final y in [h * .28, h * .5]) {
      canvas.drawLine(Offset(w * .32, y), Offset(w * .68, y), groove);
    }
  }

  @override
  bool shouldRepaint(_NeckPainter old) => old.colors != colors;
}

/// The block: a slab of wood with grain along it, darker end grain at the
/// sides, a lit bevel along the top and a shaded one along the bottom.
class _BlockPainter extends CustomPainter {
  const _BlockPainter(this.colors, {required this.seed});
  final CushionColors colors;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = colors;
    final (light, deep) = _wood(c);
    final block = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.drawRRect(
      block,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, Color.lerp(light, deep, .55)!],
        ).createShader(Offset.zero & size),
    );
    if (c.simple) return;
    canvas.save();
    canvas.clipRRect(block);
    _paintGrain(canvas, Offset.zero & size, seed, Colors.black);
    // End grain at both sides.
    for (final rect in [
      Rect.fromLTWH(0, 0, 4, size.height),
      Rect.fromLTWH(size.width - 4, 0, 4, size.height),
    ]) {
      canvas.drawRect(rect, Paint()..color = deep.withValues(alpha: .45));
    }
    // Bevels: light along the top, shade along the bottom.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 2),
      Paint()..color = Colors.white.withValues(alpha: c.dark ? .12 : .35),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 2.5, size.width, 2.5),
      Paint()..color = Colors.black.withValues(alpha: .22),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlockPainter old) =>
      old.colors != colors || old.seed != seed;
}

/// Under the block: a pale strip of foam, then the rubber die, dull and
/// ink-stained, or glistening with fresh ink on the title's stamp.
class _DiePainter extends CustomPainter {
  const _DiePainter(this.colors, this.ink, this.inked);
  final CushionColors colors;
  final Color ink;
  final bool inked;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final foam = Rect.fromLTWH(3, 0, w - 6, 2.2);
    canvas.drawRect(
      foam,
      Paint()
        ..color = colors.dark
            ? const Color(0xff8d8a80)
            : const Color(0xffe2ddd0),
    );
    final rubber = RRect.fromLTRBAndCorners(
      4,
      2.2,
      w - 4,
      size.height,
      bottomLeft: const Radius.circular(2),
      bottomRight: const Radius.circular(2),
    );
    final base = inked
        ? Color.lerp(ink, Colors.black, .1)!
        : Color.lerp(const Color(0xff4a2c26), ink, .3)!;
    canvas.drawRRect(rubber, Paint()..color = base);
    if (!inked || colors.simple) return;
    // Wet ink: a glint along it and a soft bloom of colour.
    canvas.drawRRect(
      rubber.inflate(1.5),
      Paint()
        ..color = ink.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawLine(
      Offset(8, 3.6),
      Offset(w * .55, 3.6),
      Paint()
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: .5),
    );
  }

  @override
  bool shouldRepaint(_DiePainter old) =>
      old.colors != colors || old.ink != ink || old.inked != inked;
}

/// The height every pill in the title's row of actions shares.
const _actionHeight = 48.0;

/// The title's actions in one row of pills, alike in height and shape but
/// each dressed for its job: the trailer as a little cinema screen, the
/// lists as glass, the official site as quiet paper. The row scrolls
/// sideways and fades out at both ends, and opens with the trailer in the
/// middle, as the thing most worth reaching for.
class TitleActions extends StatefulWidget {
  const TitleActions({
    super.key,
    required this.lists,
    this.trailer,
    this.onSite,
  });

  final ({String label, VoidCallback open})? trailer;
  final Widget lists;
  final VoidCallback? onSite;

  @override
  State<TitleActions> createState() => _TitleActionsState();
}

class _TitleActionsState extends State<TitleActions> {
  final _trailer = GlobalKey();
  final _row = ScrollController();

  @override
  void initState() {
    super.initState();
    // Once laid out, bring the trailer to the middle of the row, moving
    // only the row and never the page around it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _trailer.currentContext?.findRenderObject();
      if (box is! RenderBox || !_row.hasClients || !mounted) return;
      final reveal = RenderAbstractViewport.of(box).getOffsetToReveal(box, .5);
      final position = _row.position;
      _row.jumpTo(
        reveal.offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    _row.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trailer = widget.trailer;
    final onSite = widget.onSite;
    // Each pill keeps its own width, up to a point.
    Widget pill(Widget child) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: child,
    );
    final children = [
      pill(widget.lists),
      if (trailer != null)
        pill(
          _TrailerPill(
            key: _trailer,
            label: trailer.label,
            onTap: trailer.open,
          ),
        ),
      if (onSite != null) pill(_SitePill(onTap: onSite)),
    ];
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0, .08, .92, 1],
      ).createShader(bounds),
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          controller: _row,
          scrollDirection: Axis.horizontal,
          // Nothing shows past the faded ends; the padding keeps the pills'
          // shadows inside.
          // Room to scroll the end pills clear of the fade.
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
          child: ConstrainedBox(
            // Short rows sit centred.
            constraints: BoxConstraints(minWidth: box.maxWidth - 56),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  child,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The trailer, as a vintage film reel: dark metal with a brass rim and
/// round windows through it, and a cream glass hub with the play mark.
/// Tapped, the reel spins up like a projector starting, and the trailer
/// opens. A little larger than its neighbours: the row's focus.
class _TrailerPill extends StatefulWidget {
  const _TrailerPill({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  static const size = 56.0;
  static const metal = Color(0xff1d1a14);
  static const cream = Color(0xfff3ead6);

  @override
  State<_TrailerPill> createState() => _TrailerPillState();
}

class _TrailerPillState extends State<_TrailerPill>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  Future<void> _play() async {
    HapticFeedback.lightImpact();
    if (RenderingPolicyScope.of(context).animate) {
      // Let the reel get going before the trailer takes over.
      _spin.forward(from: 0);
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted) return;
    }
    widget.onTap();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = CushionColors.of(context);
    final ground = MorePalette.of(context).ground;
    return Semantics(
      container: true,
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _play,
          child: Springy(
            depth: .08,
            child: SizedBox.square(
              dimension: _TrailerPill.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The reel turns; the hub and its play mark stay upright.
                  AnimatedBuilder(
                    animation: _spin,
                    builder: (context, _) => CustomPaint(
                      size: const Size.square(_TrailerPill.size),
                      painter: _ReelPainter(
                        colors: colors,
                        ground: ground,
                        turn: Curves.easeOutCubic.transform(_spin.value),
                      ),
                    ),
                  ),
                  CustomPaint(
                    size: const Size.square(24),
                    painter: _HubPainter(colors),
                    child: const SizedBox.square(
                      dimension: 24,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: _TrailerPill.metal,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A film reel seen face on: dark metal lit from above, a brass rim, and
/// six round windows through which the page shows, turned by [turn].
class _ReelPainter extends CustomPainter {
  const _ReelPainter({
    required this.colors,
    required this.ground,
    required this.turn,
  });

  final CushionColors colors;
  final Color ground;

  /// 0 to 1, one full turn.
  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    final c = colors;
    final centre = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final disc = Rect.fromCircle(center: centre, radius: r);
    if (!c.simple) {
      // A short, crisp shadow, as the cushions cast.
      canvas.drawCircle(
        centre.translate(0, 3),
        r,
        Paint()..color = c.shadow.withValues(alpha: c.dark ? .4 : .16),
      );
      canvas.drawCircle(
        centre.translate(0, 1.2),
        r,
        Paint()..color = c.shadow.withValues(alpha: c.dark ? .5 : .22),
      );
    }
    // The metal face.
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.3, -.45),
          radius: 1.05,
          colors: c.simple
              ? const [_TrailerPill.metal, _TrailerPill.metal]
              : const [Color(0xff4a4234), Color(0xff26221a), Color(0xff121009)],
          stops: c.simple ? null : const [0, .55, 1],
        ).createShader(disc),
    );
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(turn * math.pi * 2);
    // Six windows through the reel, with a dark lip where the metal is cut.
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 2;
      final at = Offset(math.cos(angle), math.sin(angle)) * (r * .58);
      final window = r * .14;
      canvas.drawCircle(
        at,
        window + 1.2,
        Paint()..color = const Color(0xff0b0a07),
      );
      canvas.drawCircle(at, window, Paint()..color = ground);
      if (!c.simple) {
        canvas.drawArc(
          Rect.fromCircle(center: at, radius: window),
          math.pi * .15,
          math.pi * .7,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = Colors.black.withValues(alpha: .25),
        );
      }
    }
    canvas.restore();
    // The brass rim, catching the light as the reel turns.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .1;
    rim.shader = c.simple
        ? null
        : SweepGradient(
            transform: GradientRotation(turn * math.pi * 2),
            colors: const [
              Color(0xfff5dfa0),
              Color(0xffb08a3c),
              Color(0xff6e5420),
              Color(0xffb08a3c),
              Color(0xfff5dfa0),
            ],
          ).createShader(disc);
    if (c.simple) rim.color = const Color(0xffb08a3c);
    canvas.drawCircle(centre, r - r * .05, rim);
    if (c.simple) return;
    // A sheen across the metal.
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: r * .82),
      math.pi * 1.08,
      math.pi * .5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: .18),
    );
  }

  @override
  bool shouldRepaint(_ReelPainter old) =>
      old.colors != colors || old.ground != ground || old.turn != turn;
}

/// The reel's hub: a cream glass bead holding the play mark.
class _HubPainter extends CustomPainter {
  const _HubPainter(this.colors);
  final CushionColors colors;

  @override
  void paint(Canvas canvas, Size size) => paintGlass(
    canvas,
    RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.shortestSide / 2),
    ),
    colors: colors,
    tint: _TrailerPill.cream,
    fill: .95,
    lift: .5,
  );

  @override
  bool shouldRepaint(_HubPainter old) => old.colors != colors;
}

/// The official site, as a quiet round of paper with a hairline and a
/// globe.
class _SitePill extends StatelessWidget {
  const _SitePill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return Semantics(
      container: true,
      button: true,
      label: 'Official site',
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: 'Official site',
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Springy(
            depth: .08,
            child: Container(
              width: _actionHeight,
              height: _actionHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.paper,
                shape: BoxShape.circle,
                border: Border.all(color: palette.rule),
              ),
              child: Icon(
                Icons.language_rounded,
                size: 20,
                color: palette.ink.withValues(alpha: .75),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The title's lists as a round glass bead with a bookmark, and how many
/// hold it: tap to add it to one, or to change which.
class ListsChip extends StatelessWidget {
  const ListsChip({super.key, required this.lists, required this.onTap});

  final List<String> lists;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    final label = lists.isEmpty ? 'Add to a list' : 'In ${lists.join(', ')}';
    return Semantics(
      container: true,
      button: true,
      label: lists.isEmpty ? 'Lists, add to a list' : 'Lists, $label',
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Springy(
            depth: .1,
            child: CustomPaint(
              painter: _ChipPainter(cushion),
              child: SizedBox.square(
                dimension: _actionHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      lists.isEmpty
                          ? Icons.bookmark_add_outlined
                          : Icons.bookmark_rounded,
                      size: 22,
                      color: cushion.tint,
                    ),
                    // How many lists hold it, as a small bead on the rim.
                    if (lists.isNotEmpty)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          height: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cushion.tint,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: cushion.paper,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '${lists.length}',
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipPainter extends CustomPainter {
  const _ChipPainter(this.colors);
  final CushionColors colors;

  @override
  void paint(Canvas canvas, Size size) => paintGlass(
    canvas,
    RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    ),
    colors: colors,
    tint: colors.tint,
    fill: .14,
    lift: .7,
  );

  @override
  bool shouldRepaint(_ChipPainter old) => old.colors != colors;
}

/// A title's stills and posters as a loose pile of taped photos. Fling the
/// top one away and it goes to the bottom, the next rising to take its
/// place; tap it to see it full screen.
class PhotoPile extends StatefulWidget {
  const PhotoPile({super.key, required this.title});
  final CatalogTitle title;

  @override
  State<PhotoPile> createState() => _PhotoPileState();
}

class _PhotoPileState extends State<PhotoPile>
    with SingleTickerProviderStateMixin {
  late final _fly = AnimationController(vsync: this)..addListener(_flying);
  int _top = 0;
  Offset _drag = Offset.zero;
  Offset _from = Offset.zero, _to = Offset.zero;
  Curve _curve = Curves.easeOut;

  late List<TitlePicture> _pictures = titlePictures(widget.title);

  @override
  void didUpdateWidget(PhotoPile old) {
    super.didUpdateWidget(old);
    if (old.title != widget.title) {
      _pictures = titlePictures(widget.title);
      if (_top >= _pictures.length) _top = 0;
    }
  }

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  void _flying() => setState(
    () => _drag = Offset.lerp(_from, _to, _curve.transform(_fly.value))!,
  );

  Future<void> _animate(Offset to, Duration duration, Curve curve) async {
    _from = _drag;
    _to = to;
    _curve = curve;
    _fly.duration = duration;
    await _fly.forward(from: 0);
  }

  /// Flings the top photo off toward [direction] and sends it to the back.
  Future<void> _next({double direction = 1, double width = 400}) async {
    if (_pictures.length < 2 || _fly.isAnimating) return;
    HapticFeedback.selectionClick();
    if (RenderingPolicyScope.of(context).animate) {
      await _animate(
        Offset(direction * width * 1.25, _drag.dy - 30),
        const Duration(milliseconds: 240),
        Curves.easeIn,
      );
    }
    if (!mounted) return;
    setState(() {
      _top = (_top + 1) % _pictures.length;
      _drag = Offset.zero;
    });
    _announce();
  }

  void _previous() {
    if (_pictures.length < 2) return;
    setState(() {
      _top = (_top - 1) % _pictures.length;
      _drag = Offset.zero;
    });
    _announce();
  }

  void _announce() => SemanticsService.sendAnnouncement(
    View.of(context),
    '${_label(_top)} of ${_pictures.length}',
    Directionality.of(context),
  );

  String _label(int i) =>
      '${_pictures[i].poster ? 'Poster' : 'Still'} '
      '${i + 1}';

  void _open(int index) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => TitleGalleryPage(
        title: widget.title.title,
        pictures: _pictures,
        initial: index,
      ),
    ),
  );

  /// A tilt of the picture's own, the same at every depth of the pile.
  static double _tilt(String path) {
    final seed = path.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0xffff);
    return ((seed % 100) / 100 - .5) * .2;
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final pictures = _pictures;
    final n = pictures.length;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final stillW = math.min(width * .84, 340.0);
        final stillH = stillW * 9 / 16;
        final posterH = stillH * 1.25;
        final height = posterH + 70;
        final threshold = width * .3;
        final pull = (_drag.dx.abs() / threshold).clamp(0.0, 1.0);
        final shown = math.min(4, n);
        return Column(
          children: [
            SizedBox(
              height: height,
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  for (var d = shown - 1; d >= 0; d--)
                    () {
                      final index = (_top + d) % n;
                      final picture = pictures[index];
                      // Lower photos rise as the top one is pulled away.
                      final depth = d == 0 ? 0.0 : d - pull;
                      final card = _PilePhoto(
                        picture: picture,
                        width: picture.poster ? posterH * 2 / 3 : stillW,
                        height: picture.poster ? posterH : stillH,
                        media: widget.title.media,
                        top: d == 0,
                      );
                      final placed = Transform.translate(
                        // Lower photos peek out, each nudged its own way.
                        offset: d == 0
                            ? _drag
                            : Offset(
                                _tilt(picture.path) * 90 * depth.clamp(0, 1),
                                depth * 12,
                              ),
                        child: Transform.rotate(
                          angle:
                              _tilt(picture.path) +
                              (d == 0 ? _drag.dx / width * .4 : depth * .02),
                          child: Transform.scale(
                            scale: 1 - depth * .04,
                            child: card,
                          ),
                        ),
                      );
                      if (d != 0) {
                        return IgnorePointer(
                          key: ValueKey('pile-$index'),
                          child: placed,
                        );
                      }
                      return Semantics(
                        key: ValueKey('pile-$index'),
                        container: true,
                        button: true,
                        label: '${_label(index)} of $n',
                        hint: n > 1 ? 'Swipe for the next' : null,
                        excludeSemantics: true,
                        onTap: () => _open(index),
                        customSemanticsActions: {
                          if (n > 1)
                            const CustomSemanticsAction(
                              label: 'Next picture',
                            ): () =>
                                _next(width: width),
                          if (n > 1)
                            const CustomSemanticsAction(
                              label: 'Previous picture',
                            ): _previous,
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _open(index),
                          onPanStart: (_) => _fly.stop(),
                          onPanUpdate: (details) =>
                              setState(() => _drag += details.delta),
                          onPanEnd: (details) {
                            final v = details.velocity.pixelsPerSecond;
                            if (n > 1 &&
                                (_drag.dx.abs() > threshold ||
                                    v.dx.abs() > 700)) {
                              _next(
                                direction: (_drag.dx + v.dx * .1).sign == 0
                                    ? 1
                                    : (_drag.dx + v.dx * .1).sign,
                                width: width,
                              );
                            } else if (RenderingPolicyScope.of(context)
                                .animate) {
                              _animate(
                                Offset.zero,
                                const Duration(milliseconds: 520),
                                Curves.elasticOut,
                              );
                            } else {
                              setState(() => _drag = Offset.zero);
                            }
                          },
                          child: placed,
                        ),
                      );
                    }(),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.swipe_outlined, size: 18, color: palette.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    n > 1
                        ? 'Fling one aside for the next'
                        : 'Tap to look closer',
                    style: TextStyle(color: palette.muted, fontSize: 12.5),
                  ),
                ),
                ExcludeSemantics(
                  child: Text(
                    '${_top + 1} / $n',
                    style: wallHand(context, size: 22, color: palette.muted),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// One photo in the pile: a white border, a strip of tape, the picture.
class _PilePhoto extends StatelessWidget {
  const _PilePhoto({
    required this.picture,
    required this.width,
    required this.height,
    required this.media,
    required this.top,
  });

  final TitlePicture picture;
  final double width, height;
  final WatchMedia media;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    final palette = MorePalette.of(context);
    final seed = picture.path.codeUnits.fold(
      3,
      (h, c) => (h * 17 + c) & 0xffff,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 16),
          decoration: BoxDecoration(
            color: Color.lerp(
              palette.paper,
              Colors.white,
              cushion.dark ? 0 : .6,
            ),
            borderRadius: BorderRadius.circular(3),
            border: cushion.simple ? Border.all(color: palette.rule) : null,
            boxShadow: cushion.simple
                ? null
                : [
                    BoxShadow(
                      color: cushion.shadow.withValues(
                        alpha: (cushion.dark ? .45 : .14) * (top ? 1.4 : 1),
                      ),
                      blurRadius: top ? 16 : 8,
                      offset: Offset(0, top ? 8 : 3),
                    ),
                  ],
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: WatchPoster(
              path: picture.path,
              size: picture.poster ? 'w342' : 'w780',
              radius: 2,
              media: media,
              icon: Icons.image_outlined,
            ),
          ),
        ),
        Positioned(
          top: -9,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.rotate(
              angle: ((seed >> 2) % 21 - 10) / 110,
              child: Container(
                width: 52,
                height: 17,
                color: HSLColor.fromAHSL(
                  .8,
                  (seed % 360).toDouble(),
                  cushion.dark ? .3 : .42,
                  cushion.dark ? .52 : .74,
                ).toColor(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// While a title's details are on their way: an empty polaroid catching
/// the light, and Tyrion saying what he is up to.
class ReelLoading extends StatelessWidget {
  const ReelLoading({super.key, required this.seed});

  /// Picks his line, so a title always gets the same one.
  final int seed;

  static const _lines = [
    'Dusting off the reel…',
    'Finding us good seats…',
    'Rewinding the tape…',
    'Asking around the city…',
    'Threading the projector…',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final cushion = CushionColors.of(context);
    final line = _lines[seed.abs() % _lines.length];
    final width = math.min(MediaQuery.sizeOf(context).width * .52, 220.0);
    return Semantics(
      label: 'Loading. $line',
      liveRegion: true,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Transform.rotate(
                    angle: -.035,
                    child: Container(
                      width: width,
                      padding: const EdgeInsets.fromLTRB(9, 9, 9, 14),
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          palette.paper,
                          Colors.white,
                          cushion.dark ? 0 : .5,
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: cushion.simple
                            ? null
                            : [
                                BoxShadow(
                                  color: cushion.shadow.withValues(alpha: .16),
                                  blurRadius: 14,
                                  offset: const Offset(2, 8),
                                ),
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: const AspectRatio(
                              aspectRatio: 2 / 3,
                              child: WatchShimmer(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FractionallySizedBox(
                            widthFactor: .7,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: palette.cloth,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          FractionallySizedBox(
                            widthFactor: .4,
                            child: Container(
                              height: 9,
                              decoration: BoxDecoration(
                                color: palette.cloth,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                ExcludeSemantics(
                  child: Row(
                    children: [
                      const LocalArtwork(
                        assetKey: watchlistArtworkKey,
                        dimension: 84,
                        highResolution: true,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 84 * .26),
                          child: Transform.translate(
                            offset: const Offset(-22, 0),
                            child: SpeechBubble(
                              speaker: SpeakerSide.left,
                              text: line,
                            ),
                          ),
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
  }
}
