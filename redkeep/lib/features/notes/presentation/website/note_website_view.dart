import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/note_details.dart';
import '../../data/note_media_store.dart';

import 'package:webview_flutter/webview_flutter.dart';

import 'website_assets.dart';
import '../../domain/website/website_contract.dart';

/// Shows a note's generated website: re-sanitized, with JavaScript off and
/// every navigation blocked, so the page can only draw itself.
class NoteWebsiteView extends ConsumerStatefulWidget {
  const NoteWebsiteView({
    super.key,
    required this.html,
    this.photos = const [],
  });
  final String html;

  /// The note's photos, embedded where a themed page asks for them.
  final List<NoteAttachment> photos;

  @override
  ConsumerState<NoteWebsiteView> createState() => _NoteWebsiteViewState();
}

class _NoteWebsiteViewState extends ConsumerState<NoteWebsiteView> {
  WebViewController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
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
    }
  }

  Future<void> _load() async {
    final html = widget.html;
    // Without a platform web view (tests, unsupported desktops) nothing loads.
    if (WebViewPlatform.instance == null) return;
    String safe;
    try {
      // Synced pages are checked again: another device may be older or wrong.
      safe = await sanitizeWebsiteBounded(html);
      // Photos and fonts are added after the check and never stored.
      safe = await withWebsiteAssets(
        safe,
        widget.photos,
        store: ref.read(noteMediaStoreProvider),
      );
    } catch (_) {
      if (mounted && html == widget.html) setState(() => _failed = true);
      return;
    }
    if (!mounted || html != widget.html) return;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              request.url.startsWith('about:blank') ||
                  request.url.startsWith('about:srcdoc')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
    await controller.loadHtmlString(safe);
    if (mounted && html == widget.html) {
      setState(() {
        _controller = controller;
        _failed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Semantics(
      key: const ValueKey('note-website-view'),
      label: 'Note website',
      child: _failed
          ? const Center(child: Text('This website could not be shown safely.'))
          : controller == null
          ? const Center(
              child: Text(
                'Website preview is available on Android and iOS. Your note text is kept.',
              ),
            )
          : WebViewWidget(
              controller: controller,
              // The page scrolls itself, even inside a scrolling parent.
              gestureRecognizers: {
                Factory<VerticalDragGestureRecognizer>(
                  VerticalDragGestureRecognizer.new,
                ),
              },
            ),
    );
  }
}
