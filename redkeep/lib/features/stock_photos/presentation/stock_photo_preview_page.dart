import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/stock_photo_providers.dart';
import '../domain/stock_photo.dart';
import '../domain/stock_photo_source.dart';
import 'stock_photo_widgets.dart';

/// One photo, large and upright as it will sit behind a note, with its credit.
/// "Use this background" downloads it and pops with the stored path.
class StockPhotoPreviewPage extends ConsumerStatefulWidget {
  const StockPhotoPreviewPage({super.key, required this.photo});

  final StockPhoto photo;

  @override
  ConsumerState<StockPhotoPreviewPage> createState() =>
      _StockPhotoPreviewPageState();
}

class _StockPhotoPreviewPageState extends ConsumerState<StockPhotoPreviewPage> {
  bool _saving = false;
  String? _error;

  Future<void> _use() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final path = await ref.read(stockBackgroundImporterProvider)(
        widget.photo,
      );
      if (mounted) context.pop(path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (e) {
          FormatException(:final message) => message,
          StockPhotoException(:final message) => message,
          _ => 'The photo could not be saved. Try again.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = ref.watch(stockPhotoSourceProvider);
    final photo = widget.photo;
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 420,
                      // Leaves room for the credit and button below.
                      maxHeight: (constraints.maxHeight * .68).clamp(240, 720),
                    ),
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: Semantics(
                        image: true,
                        label: photo.description ?? 'Photo preview',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: StockPhotoImage(
                            photo: photo,
                            url: photo.previewUrl,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (source != null)
                  StockPhotoCredit(
                    photo: photo,
                    provider: source.name,
                    providerUrl: source.homeUrl.toString(),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: FilledButton.icon(
                      key: const ValueKey('stock-photo-use'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _saving || source == null ? null : _use,
                      icon: _saving && stockPhotoAnimate(context)
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _saving
                                  ? Icons.hourglass_top_rounded
                                  : Icons.check_rounded,
                            ),
                      label: Text(
                        _saving ? 'Saving photo…' : 'Use this background',
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
}
