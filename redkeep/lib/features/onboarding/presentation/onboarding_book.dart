// The selected legacy book geometry is retained for visual parity.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'book_paper.dart';
import 'book_fold.dart';
import 'book_materials.dart';
import 'book_artwork.dart';
import 'onboarding_chapter.dart';

const _ink = Color(0xFF30274E);
const onboardingSpreadAspectRatio = 4 / 3;
// Destination-sized file providers share decoded pixels across both leaves.
int onboardingImageCacheWidth(double bookWidth, double pixelRatio) =>
    ((bookWidth - 12) * pixelRatio).ceil().clamp(1, 1448);

int onboardingCoverCacheWidth(BuildContext context) =>
    (math.min(MediaQuery.sizeOf(context).width * .72, 360.0) *
            MediaQuery.devicePixelRatioOf(context))
        .ceil()
        .clamp(64, 1122);

class OnboardingBook extends StatelessWidget {
  const OnboardingBook({
    super.key,
    required this.page,
    required this.direction,
    required this.turn,
    required this.closing,
    required this.nameController,
    required this.nameFocus,
    required this.editable,
    required this.onSubmit,
    this.onPageTap,
    this.artworkWidth,
    this.simple = false,
    this.showNameField = true,
  });
  final bool simple, showNameField;
  final int page, direction;
  final double turn, closing;
  final double? artworkWidth;
  final TextEditingController nameController;
  final FocusNode nameFocus;
  final bool editable;
  final VoidCallback onSubmit;
  final ValueChanged<int>? onPageTap;

  @override
  Widget build(BuildContext context) => BookMaterials(
    builder: (context, paperTexture, bindingTexture) => LayoutBuilder(
      builder: (context, constraints) {
        final full = constraints.maxWidth - 12;
        final leaf = full / 2;
        final h = constraints.maxHeight - 20;
        final fold = BookFoldGeometry(
          leafSize: Size(leaf, h),
          progress: closing.clamp(0.0, 1.0),
        );
        final lastPage = onboardingFeatures.length - 1;
        final pageProgress = (page + direction * turn) / lastPage;
        final leftDepth = 9 + 7 * pageProgress;
        final cacheWidth = onboardingImageCacheWidth(
          artworkWidth ?? constraints.maxWidth,
          MediaQuery.devicePixelRatioOf(context),
        );
        Widget sheet(int index, bool left) => _Leaf(
          index: index.clamp(0, lastPage),
          left: left,
          cacheWidth: cacheWidth,
          onTap:
              onPageTap != null &&
                  (left ? page > 0 : page < onboardingFeatures.length - 1)
              ? () => onPageTap!(left ? -1 : 1)
              : null,
        );
        Widget positioned(double left, Widget child) => Positioned(
          left: left,
          top: 4,
          width: leaf,
          height: h,
          child: child,
        );
        final next = (page + direction).clamp(0, lastPage);
        final inside = CustomPaint(
          painter: BookLeafStack(
            left: true,
            depth: leftDepth,
            paperTexture: paperTexture,
            bindingTexture: bindingTexture,
            board: true,
          ),
          child: sheet(turn > 0 && direction == -1 ? next : page, true),
        );
        final outside = _Cover(
          controller: nameController,
          focus: nameFocus,
          editable: editable,
          onSubmit: onSubmit,
          cacheWidth: onboardingCoverCacheWidth(context),
          showNameField: showNameField,
          simple: simple,
        );
        final tilt = math.min(
          .10,
          math.max(0.0, MediaQuery.sizeOf(context).width - full - 10) /
              constraints.maxHeight,
        );
        // Leave room for the stronger open tilt, then settle to the original
        // cover size after folding. Framing stays fixed during the fold.
        final scale = .97 + .03 * fold.settleProgress;
        if (simple) {
          if (closing == 1) {
            return Center(
              child: SizedBox(width: leaf, height: h, child: outside),
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFAF99BF),
                border: Border.all(color: const Color(0xFF7C6788), width: 3),
              ),
              child: Row(
                children: [
                  Expanded(child: sheet(page, true)),
                  const SizedBox(width: 4),
                  Expanded(child: sheet(page, false)),
                ],
              ),
            ),
          );
        }
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, fold.perspective)
            ..rotateX(-.14 + .105 * fold.settleProgress)
            ..rotateY(.05 - .08 * fold.settleProgress)
            ..rotateZ(-tilt * (1 - fold.settleProgress))
            ..scaleByDouble(scale, scale, scale, 1),
          child: Transform.translate(
            // Only the fully closed book recenters. Its spine and back cover
            // stay anchored throughout the actual folding motion.
            offset: Offset(fold.recenter, 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      key: const ValueKey('book-stationary-case'),
                      painter: BookBoards(closing: fold.foldProgress),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: BookBinding(
                          progress: pageProgress,
                          closing: fold.foldProgress,
                          showLeft: false,
                          paperTexture: paperTexture,
                          bindingTexture: bindingTexture,
                        ),
                      ),
                    ),
                  ),
                  positioned(
                    leaf,
                    ExcludeSemantics(
                      excluding: fold.outsideVisible,
                      child: sheet(
                        turn > 0 && direction == 1 ? next : page,
                        false,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: BookFoldShadow(fold: fold)),
                    ),
                  ),
                  positioned(
                    0,
                    Transform(
                      key: const ValueKey('book-cover-hinge'),
                      transform: fold.visibleFaceTransform,
                      child: CustomPaint(
                        foregroundPainter: BookFoldEdge(fold: fold),
                        child: fold.outsideVisible ? outside : inside,
                      ),
                    ),
                  ),
                  if (closing == 0 && turn > 0)
                    positioned(
                      direction == 1 ? leaf : 0,
                      ExcludeSemantics(
                        child: BentBookPage(
                          progress: turn,
                          reverse: direction == -1,
                          front: sheet(page, direction == -1),
                          back: sheet(next, direction == 1),
                        ),
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

class _Leaf extends StatelessWidget {
  const _Leaf({
    required this.index,
    required this.left,
    required this.cacheWidth,
    this.onTap,
  });
  final int index;
  final bool left;
  final int cacheWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final feature = onboardingFeatures[index];
    return Semantics(
      image: true,
      onTap: onTap,
      hint: onTap == null ? null : (left ? 'Previous page' : 'Next page'),
      label: left
          ? '${feature.name}. ${feature.title.replaceAll('\n', ' ')} '
                '${feature.detail.replaceAll('\n', ' ')}'
          : feature.scene,
      child: GestureDetector(
        onTap: onTap,
        excludeFromSemantics: true,
        child: ClipPath(
          clipper: PaperEdge(left: left),
          child: CustomPaint(
            foregroundPainter: PaperLighting(left: left),
            child: ColoredBox(
              color: const Color(0xFFF5ECD6),
              child: LayoutBuilder(
                builder: (context, constraints) => OverflowBox(
                  alignment: left
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  minWidth: constraints.maxWidth * 2,
                  maxWidth: constraints.maxWidth * 2,
                  minHeight: constraints.maxHeight,
                  maxHeight: constraints.maxHeight,
                  child: BookFileImage(
                    assetKey: feature.artwork,
                    cacheWidth: cacheWidth,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.controller,
    required this.focus,
    required this.editable,
    required this.onSubmit,
    required this.cacheWidth,
    required this.showNameField,
    required this.simple,
  });
  final bool showNameField, simple;
  final int cacheWidth;
  final TextEditingController controller;
  final FocusNode focus;
  final bool editable;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: simple ? null : const CoverBevel(),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: const Color(0xFFAF99BF),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: BookFileImage(
                  assetKey: 'onboarding.cover',
                  cacheWidth: cacheWidth,
                  fit: BoxFit.fill,
                ),
              ),
              if (showNameField)
                Positioned(
                  left: constraints.maxWidth * .16,
                  right: constraints.maxWidth * .16,
                  top: constraints.maxHeight * .55,
                  height: constraints.maxHeight * .19,
                  child: Center(
                    child: TextField(
                      controller: controller,
                      focusNode: focus,
                      enabled: editable,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      onSubmitted: (_) => onSubmit(),
                      autofillHints: const [AutofillHints.name],
                      style: TextStyle(
                        color: _ink,
                        fontSize: math.min(32, constraints.maxWidth * .13),
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1,
                      ),
                      cursorColor: _ink,
                      decoration: const InputDecoration(
                        hintText: 'you.',
                        hintStyle: TextStyle(color: Color(0xFF705B8D)),
                        semanticCounterText: 'Your name',
                        labelText: 'Your name',
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        labelStyle: TextStyle(color: Color(0xFF705B8D)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
