import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/presentation/rendering_policy.dart';
import '../../data/note_media_store.dart';
import '../../application/note_website_bridge.dart';
import '../../domain/note_checklist.dart';
import '../../domain/note_details.dart';
import '../../domain/website/website_contract.dart';
import 'website_assets.dart';
import 'website_check_dialog.dart';

/// The app's look as a website should see it: light or dark, motion,
/// effects and the main colours.
WebsiteAppearance websiteAppearanceOf(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final policy = RenderingPolicyScope.of(context);
  String hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  return WebsiteAppearance(
    dark: Theme.of(context).brightness == Brightness.dark,
    reduceMotion: policy.reducedMotion,
    simpleEffects: policy.simplerEffects,
    tokens: {
      'bg': hex(scheme.surface),
      'fg': hex(scheme.onSurface),
      'muted': hex(scheme.onSurfaceVariant),
      'accent': hex(scheme.primary),
      'surface': hex(scheme.surfaceContainerHigh),
    },
  );
}

/// Shows a note's generated website. Its own scripts run, but it cannot
/// reach the network or navigate anywhere, and it has no bridge into the
/// app beyond `window.redkeep`. It follows the app's light or dark look
/// while it stays open.
class NoteWebsiteView extends ConsumerStatefulWidget {
  const NoteWebsiteView({
    super.key,
    required this.html,
    this.photos = const [],
    this.noteId,
    this.state = '',
    this.checklist = const [],
  });
  final String html;

  /// The note's attachments; its photos fill the page's placeholders.
  final List<NoteAttachment> photos;

  /// The kept website's note. A preview has none: it can neither save nor
  /// change the note.
  final String? noteId;

  /// What the page saved for itself, handed back when it opens.
  final String state;

  /// The note's checklist now; the page hears about changes while open.
  final List<NoteChecklistItem> checklist;

  @override
  ConsumerState<NoteWebsiteView> createState() => _NoteWebsiteViewState();
}

class _NoteWebsiteViewState extends ConsumerState<NoteWebsiteView> {
  WebViewController? _controller;
  String? _failure;
  WebsiteAppearance? _appearance;

  /// Bumped for every load, so a slower earlier load never lands.
  int _loading = 0;
  NoteWebsiteBridge? _bridge;

  @override
  void initState() {
    super.initState();
    final id = widget.noteId;
    if (id != null) {
      _bridge = NoteWebsiteBridge(
        ProviderScope.containerOf(context, listen: false),
        id,
        confirm: (item, done) => confirmWebsiteCheck(context, item, done),
      );
    }
  }

  @override
  void dispose() {
    _bridge?.close();
    super.dispose();
  }

  Future<void> _onMessage(JavaScriptMessage message) async {
    final reply = await _bridge?.handle(message.message);
    if (reply == null || !mounted) return;
    await _controller
        ?.runJavaScript(
          'window.redkeep&&window.redkeep._reply('
          '${jsonEncode(reply.id)},${reply.ok});',
        )
        .catchError((_) {});
  }

  static String _checklistJson(List<NoteChecklistItem> items) =>
      jsonEncode([for (final item in items) item.toJson()]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appearance = websiteAppearanceOf(context);
    if (appearance == _appearance) return;
    final first = _appearance == null;
    _appearance = appearance;
    if (first) {
      _load();
    } else {
      // Re-theme in place: the page keeps its scroll and state.
      _controller?.runJavaScript(appearance.script).catchError((_) {});
    }
  }

  @override
  void didUpdateWidget(NoteWebsiteView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html ||
        !listEquals(
          [for (final p in oldWidget.photos) p.path],
          [for (final p in widget.photos) p.path],
        )) {
      _load();
    } else if (_checklistJson(oldWidget.checklist) !=
        _checklistJson(widget.checklist)) {
      // The note changed under an open page: tell it, without reloading.
      _controller
          ?.runJavaScript(
            'window.redkeep&&window.redkeep._checklist('
            '${_checklistJson(widget.checklist)});',
          )
          .catchError((_) {});
    }
  }

  Future<void> _load() async {
    final load = ++_loading;
    // Without a platform web view (tests, unsupported desktops) nothing loads.
    if (WebViewPlatform.instance == null) return;
    String page;
    try {
      // Checked again on every load, never trusted because it was stored.
      page = await sanitizeWebsiteBounded(
        widget.html,
        appearance: _appearance,
        data: WebsitePageData(state: widget.state, checklist: widget.checklist),
      );
      // Photos are added after the check and never stored.
      page = await withWebsiteAssets(
        page,
        websitePhotos(widget.photos),
        store: ref.read(noteMediaStoreProvider),
      );
    } on FormatException catch (error) {
      if (mounted && load == _loading) {
        setState(() => _failure = error.message);
      }
      return;
    } catch (_) {
      if (mounted && load == _loading) {
        setState(() => _failure = 'This website could not be shown safely.');
      }
      return;
    }
    if (!mounted || load != _loading) return;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent);
    // The page's one way to the app; a preview gets none.
    if (_bridge != null) {
      await controller.addJavaScriptChannel(
        'RedkeepBridge',
        onMessageReceived: _onMessage,
      );
    }
    await controller.setNavigationDelegate(
      NavigationDelegate(
        // In-page anchors still scroll; nothing may load another address.
        onNavigationRequest: (request) =>
            request.url.startsWith('about:blank') ||
                request.url.startsWith('about:srcdoc')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ),
    );
    await controller.loadHtmlString(page);
    if (!mounted || load != _loading) return;
    final shown = _appearance;
    setState(() {
      _controller = controller;
      _failure = null;
    });
    // The look may have changed while the page was being prepared.
    final now = websiteAppearanceOf(context);
    if (shown != now) {
      _appearance = now;
      await controller.runJavaScript(now.script).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final failure = _failure;
    return Semantics(
      key: const ValueKey('note-website-view'),
      label: 'Note website',
      child: failure != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(failure, textAlign: TextAlign.center),
              ),
            )
          : controller == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  WebViewPlatform.instance == null
                      ? 'Websites are shown on Android and iOS. Your note text is kept.'
                      : 'Opening the website…',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : WebViewWidget(
              controller: controller,
              // The page scrolls itself, even inside a scrolling parent.
              gestureRecognizers: {
                Factory<VerticalDragGestureRecognizer>(
                  VerticalDragGestureRecognizer.new,
                ),
                Factory<HorizontalDragGestureRecognizer>(
                  HorizontalDragGestureRecognizer.new,
                ),
              },
            ),
    );
  }
}
