import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts_lite.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../application/onboarding_controller.dart';
import 'book_artwork.dart';
import 'onboarding_book.dart';
import 'onboarding_chapter.dart';
import 'onboarding_controls.dart';
import 'onboarding_content.dart';
import 'onboarding_terms.dart';

enum _Stage { touring, closing, naming, opening }

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  late final _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  late final _close = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _tourFocus = FocusNode();
  final _scroll = ScrollController();
  Timer? _autoplay;
  _Stage _stage = _Stage.touring;
  int _page = 0, _direction = 1;
  bool _turning = false, _motion = false;
  bool _dragging = false, _finishingTurn = false;
  bool _autoplayPaused = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_nameChanged);
  }

  void _nameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final policy = RenderingPolicyScope.of(context);
    _motion =
        policy.animate &&
        !policy.simplerEffects &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (!_motion) {
      if (_turn.isAnimating) _turn.value = 1;
      if (_dragging && _turning) {
        Future.microtask(() {
          if (mounted && _dragging) {
            _dragging = false;
            _finishTurn(true);
          }
        });
      }
      if (_close.isAnimating) _close.value = _stage == _Stage.opening ? 0 : 1;
    }
    _scheduleAutoplay();
  }

  void _scheduleAutoplay() {
    _autoplay?.cancel();
    if (!_motion ||
        _autoplayPaused ||
        _stage != _Stage.touring ||
        _turning ||
        _dragging ||
        _page == onboardingFeatures.length - 1) {
      return;
    }
    _autoplay = Timer(const Duration(seconds: 5), () => _flip(1));
  }

  Future<void> _flip(int direction) async {
    if (_turning ||
        _stage != _Stage.touring ||
        ref.read(onboardingControllerProvider).saving ||
        _page + direction < 0 ||
        _page + direction >= onboardingFeatures.length) {
      return;
    }
    _autoplay?.cancel();
    setState(() {
      _turning = true;
      _direction = direction;
    });
    await _finishTurn(true);
  }

  Future<void> _finishTurn(bool commit) async {
    if (!_turning || _finishingTurn) return;
    _finishingTurn = true;
    try {
      if (_motion) {
        await _turn
            .animateTo(commit ? 1 : 0, curve: Curves.easeOutCubic)
            .orCancel;
      } else {
        _turn.value = commit ? 1 : 0;
      }
    } on TickerCanceled {
      /* Live reduction settles the selected target. */
    }
    _finishingTurn = false;
    if (!mounted) return;
    setState(() {
      if (commit) _page += _direction;
      _turning = false;
      _turn.value = 0;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _scheduleAutoplay();
  }

  void _startDrag() {
    _autoplay?.cancel();
    _dragging = true;
  }

  void _updateDrag(double delta, double width) {
    if (!_dragging || _stage != _Stage.touring) return;
    if (!_turning) {
      final direction = delta < 0 ? 1 : -1;
      if (_page + direction < 0 ||
          _page + direction >= onboardingFeatures.length) {
        return;
      }
      setState(() {
        _direction = direction;
        _turning = true;
      });
    }
    _turn.value = (_turn.value - delta * _direction / (width * .65)).clamp(
      0.0,
      1.0,
    );
  }

  void _endDrag(double velocity, {bool canceled = false}) {
    if (!_dragging) return;
    _dragging = false;
    if (_turning) {
      unawaited(
        _finishTurn(
          !canceled && (_turn.value > .25 || velocity * _direction < -350),
        ),
      );
    } else {
      _scheduleAutoplay();
    }
  }

  Future<void> _begin() async {
    if (_turning || _stage != _Stage.touring) return;
    _autoplay?.cancel();
    setState(() => _stage = _Stage.closing);
    // Warm just the chosen cover before it is revealed halfway through the
    // fold. The destination-sized provider stays stable as the keyboard opens.
    unawaited(
      ref
          .read(
            bookImageProvider((
              'onboarding.cover',
              onboardingCoverCacheWidth(context),
            )).future,
          )
          .then<void>(
            (provider) {
              if (mounted) {
                unawaited(precacheImage(provider, context, onError: (_, _) {}));
              }
            },
            onError: (Object _, StackTrace _) {
              // The watched resolver error uses the established repair gate.
            },
          ),
    );
    try {
      if (_motion) {
        await _close.forward().orCancel;
      } else {
        _close.value = 1;
      }
    } on TickerCanceled {
      /* Settle the cover after motion reduction. */
    }
    if (!mounted) return;
    setState(() => _stage = _Stage.naming);
    // Wait for naming to enable or mount the field before requesting focus,
    // including when reduced motion skips the fold.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _stage == _Stage.naming) _nameFocus.requestFocus();
    });
  }

  Future<void> _back() async {
    if (_stage != _Stage.naming ||
        ref.read(onboardingControllerProvider).saving) {
      return;
    }
    _nameFocus.unfocus();
    // Returning to the chapters leaves the reader in control, as in the
    // original tour, rather than restarting the automatic page turns.
    _autoplayPaused = true;
    setState(() => _stage = _Stage.opening);
    try {
      if (_motion) {
        await _close.reverse().orCancel;
      } else {
        _close.value = 0;
      }
    } on TickerCanceled {
      /* Settle back to the selected chapter. */
    }
    if (mounted) {
      setState(() => _stage = _Stage.touring);
      _tourFocus.requestFocus();
    }
  }

  void _save() {
    if (_stage != _Stage.naming || _name.text.trim().isEmpty) return;
    unawaited(
      ref.read(onboardingControllerProvider.notifier).complete(_name.text),
    );
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _turn.dispose();
    _close.dispose();
    _name.dispose();
    _nameFocus.dispose();
    _tourFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final policy = RenderingPolicyScope.of(context);
    if (_stage != _Stage.touring) {
      ref.watch(
        bookImageProvider((
          'onboarding.cover',
          onboardingCoverCacheWidth(context),
        )),
      );
    }
    final naming = _stage == _Stage.naming;
    final touring = _stage == _Stage.touring;
    final enabled = !state.saving && !_turning && (touring || naming);
    final chapter = onboardingFeatures[_page];
    final error = state.saveFailed
        ? 'Your name could not be saved. Check device storage and try again.'
        : state.nameInvalid
        ? 'Enter your name to continue.'
        : null;
    Widget actions() => Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!naming)
            const Text(
              'Your space for notes, diary and passing thoughts, with local AI support.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF514354),
                fontSize: 18,
                height: 1.45,
                letterSpacing: -.2,
              ),
            )
          else if (MediaQuery.viewInsetsOf(context).bottom == 0)
            Text(
              'Your story starts with you.',
              textAlign: TextAlign.center,
              style: GoogleFontsLite.getFont(
                'Allura',
                color: const Color(0xFF433548),
                fontSize: 30,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8C3544)),
                ),
              ),
            ),
          if (!naming ||
              MediaQuery.viewInsetsOf(context).bottom == 0 ||
              error != null)
            const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OnboardingPrimaryButton(
              label: naming
                  ? state.saving
                        ? 'Saving…'
                        : 'Save'
                  : "Let's begin",
              onPressed: enabled
                  ? naming
                        ? _name.text.trim().isEmpty
                              ? null
                              : _save
                        : _begin
                  : null,
              simple: policy.simplerEffects,
            ),
          ),
        ],
      ),
    );

    Widget book(double maxWidth, double maxHeight, {bool embeddedName = true}) {
      final openWidth = math.max(
        60.0,
        math.min(
          math.min(maxWidth - 24, 720),
          ((maxHeight - 12) / 1.12 - 20) * onboardingSpreadAspectRatio + 12,
        ),
      );
      final closedWidth = math.max(
        60.0,
        math.min(
          math.min(maxWidth * .72, 360) * 2 + 12,
          (maxHeight - 32) * onboardingSpreadAspectRatio + 12,
        ),
      );
      // Keep decode dimensions at the settled destination throughout each fold.
      final artworkWidth = _close.value == 0 ? openWidth : closedWidth;
      return AnimatedBuilder(
        animation: Listenable.merge([_turn, _close]),
        builder: (context, _) {
          final settled = Curves.easeInOutCubic.transform(
            ((_close.value - .8) / .2).clamp(0.0, 1.0),
          );
          final maxBookHeight = (maxHeight - 12) / (1 + .12 * (1 - settled));
          final width = math.max(
            60.0,
            math.min(
              openWidth + (closedWidth - openWidth) * settled,
              (maxBookHeight - 20) * onboardingSpreadAspectRatio + 12,
            ),
          );
          final height = (width - 12) / onboardingSpreadAspectRatio + 20;
          return Center(
            child: Padding(
              padding: EdgeInsets.only(
                top: height * .04 * (1 - settled) + 4,
                bottom: height * .08 * (1 - settled) + 8,
              ),
              child: SizedBox(
                width: math.min(width, maxWidth).toDouble(),
                height: height,
                child: OverflowBox(
                  minWidth: width,
                  maxWidth: width,
                  minHeight: height,
                  maxHeight: height,
                  child: GestureDetector(
                    key: const ValueKey('onboarding-book'),
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onHorizontalDragStart: touring && !state.saving && !_turning
                        ? (_) => _startDrag()
                        : null,
                    onHorizontalDragUpdate: touring && !state.saving
                        ? (d) => _updateDrag(d.delta.dx, width.toDouble())
                        : null,
                    onHorizontalDragEnd: touring && !state.saving
                        ? (d) => _endDrag(d.velocity.pixelsPerSecond.dx)
                        : null,
                    onHorizontalDragCancel: touring && !state.saving
                        ? () => _endDrag(0, canceled: true)
                        : null,
                    child: Listener(
                      onPointerCancel: (_) => _endDrag(0, canceled: true),
                      child: Semantics(
                        key: const ValueKey('onboarding-book-semantics'),
                        onIncrease:
                            touring &&
                                enabled &&
                                _page < onboardingFeatures.length - 1
                            ? () => _flip(1)
                            : null,
                        onDecrease: touring && enabled && _page > 0
                            ? () => _flip(-1)
                            : null,
                        child: OnboardingBook(
                          page: _page,
                          direction: _direction,
                          turn: _turning ? _turn.value : 0,
                          closing: _close.value,
                          artworkWidth: artworkWidth.toDouble(),
                          nameController: _name,
                          nameFocus: _nameFocus,
                          editable: naming && !state.saving,
                          showNameField: embeddedName,
                          onSubmit: _save,
                          onPageTap: touring && enabled ? _flip : null,
                          simple: policy.simplerEffects,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    Widget hints() => OnboardingPageHints(page: _page, compact: false);

    Widget gate(Widget child) => PopScope<Object?>(
      canPop: _stage == _Stage.touring || state.saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && naming) {
          if (_nameFocus.hasFocus ||
              MediaQuery.viewInsetsOf(context).bottom > 0) {
            _nameFocus.unfocus();
          } else {
            unawaited(_back());
          }
        }
      },
      child: CallbackShortcuts(
        bindings: {
          if (touring && enabled) ...{
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _flip(-1),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _flip(1),
          },
          if (naming && enabled)
            const SingleActivator(LogicalKeyboardKey.escape): () => _back(),
        },
        child: Focus(focusNode: _tourFocus, autofocus: true, child: child),
      ),
    );
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height - media.padding.vertical - media.viewInsets.bottom;
    final accessible =
        media.textScaler.scale(16) > 22 ||
        availableHeight < 400 ||
        media.size.width - media.padding.horizontal < 280;
    if (!accessible) {
      return gate(
        OnboardingContent(
          page: _page,
          direction: _direction,
          turn: _turn,
          close: _close,
          turning: _turning,
          touring: touring && !state.saving,
          naming: naming,
          saving: state.saving,
          nameController: _name,
          nameFocus: _nameFocus,
          error: error,
          onBegin: _begin,
          onSave: _save,
          onFlip: _flip,
          onDragStart: _startDrag,
          onDragUpdate: _updateDrag,
          onDragEnd: (velocity) => _endDrag(velocity),
          onDragCancel: () => _endDrag(0, canceled: true),
        ),
      );
    }
    return gate(
      AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          systemNavigationBarColor: const Color(0xFFF2E7D2),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF2E7D2),
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: Image.asset(
                      'assets/branding/ink-paper.webp',
                      key: const ValueKey('onboarding-background'),
                      cacheWidth: 1024,
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, viewport) {
                    return SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          SizedBox(
                            height: math.min(viewport.maxWidth * .9, 360),
                            width: viewport.maxWidth,
                            child: book(
                              viewport.maxWidth,
                              math.min(viewport.maxWidth * .9, 360),
                              embeddedName: false,
                            ),
                          ),
                          if (naming)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: TextField(
                                controller: _name,
                                focusNode: _nameFocus,
                                enabled: !state.saving,
                                autofillHints: const [AutofillHints.name],
                                textCapitalization: TextCapitalization.words,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(40),
                                ],
                                onSubmitted: (_) => _save(),
                                style: const TextStyle(
                                  color: Color(0xFF30274E),
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Your name',
                                  labelStyle: TextStyle(
                                    color: Color(0xFF514354),
                                  ),
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      chapter.name,
                                      style: const TextStyle(
                                        color: Color(0xFF30274E),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    chapter.title,
                                    style: const TextStyle(
                                      color: Color(0xFF30274E),
                                      fontSize: 26,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    chapter.detail,
                                    style: const TextStyle(
                                      color: Color(0xFF514354),
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!naming) hints(),
                          actions(),
                          if (MediaQuery.viewInsetsOf(context).bottom == 0)
                            const OnboardingTerms(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
