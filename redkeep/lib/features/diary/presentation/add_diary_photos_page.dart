import '../data/diary_picker_recovery.dart';

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'photos/photo_ui.dart';
import '../domain/diary_period.dart';
import '../data/diary_photo_stories.dart';

import 'package:redkeep/features/diary/data/diary_photo_store.dart';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'photos/diary_photo_widgets.dart';
import 'photos/diary_ink_action.dart';
import 'photos/diary_memory_material.dart';
import 'photos/diary_photo_contact_sheet.dart';

class _PhotoMoment {
  _PhotoMoment({
    required this.path,
    required this.draft,
    this.reflections = const [],
    this.seen = '',
  });

  /// Picker path for a new photo, saved path for a reopened one.
  final String path;
  final DiaryPhotoDraft draft;
  Uint8List get bytes => draft.bytes;
  final caption = TextEditingController();

  /// Words saved with this photo before, kept as they are on save.
  final List<DiaryPhotoReflection> reflections;
  final String seen;

  void dispose() => caption.dispose();
}

/// Builds or reopens a photo story: photos with optional captions. A saved
/// story opens as a preview unless [startEditing]; Edit turns it into the
/// editor. Only Save writes to the diary; closing leaves the diary and its
/// saved photos untouched.
class AddDiaryPhotosPage extends ConsumerStatefulWidget {
  const AddDiaryPhotosPage({
    super.key,
    required this.date,
    this.story,
    this.newItemUuid,
    this.readOnly = false,
    this.startEditing = false,
    this.imagePicker,
  });

  final DiaryPeriod date;

  /// A saved photo story to reopen.
  final DiaryItem? story;
  final String? newItemUuid;

  /// Secondary devices can view saved stories but not change them.
  final bool readOnly;

  /// Opens a saved story straight in the editor instead of the preview.
  final bool startEditing;
  final Future<List<XFile>> Function()? imagePicker;

  @override
  ConsumerState<AddDiaryPhotosPage> createState() => _AddDiaryPhotosPageState();
}

class _AddDiaryPhotosPageState extends ConsumerState<AddDiaryPhotosPage> {
  final _moments = <_PhotoMoment>[];
  final _pages = PageController(keepPage: false);
  final _rail = ScrollController();
  final _scroll = ScrollController();
  int _selected = 0;
  bool _picking = false;
  bool _saving = false;
  bool _opening = false;
  bool get _reopened => widget.story != null;
  String? _pickerError;

  /// New stories are always edited; saved ones start as a preview.
  late bool _editing = !widget.readOnly && (!_reopened || widget.startEditing);

  /// Whether leaving the editor returns to the preview rather than closing.
  bool _fromPreview = false;

  bool get _reduced => mediaMotionDisabled(context);

  @override
  void initState() {
    super.initState();
    if (_reopened) {
      _opening = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickPhotos();
      });
    }
  }

  DiaryPhotoStories get _stories => ref.read(diaryPhotoStoriesProvider);

  Future<void> _open() async {
    if (!mounted) return;
    final story = widget.story!;
    final drafts = await _stories.open(story);
    if (!mounted) return;
    setState(() {
      for (final (index, photo) in story.photos.indexed) {
        _moments.add(
          _PhotoMoment(
            path: photo.path,
            draft: drafts[index],
            reflections: photo.reflections,
            seen: photo.seen,
          )..caption.text = photo.caption,
        );
      }
      _opening = false;
    });
  }

  void _startEditing() {
    if (widget.readOnly || _opening) return;
    setState(() {
      _editing = true;
      _fromPreview = true;
    });
  }

  /// Leaves the editor for the preview, dropping unsaved changes.
  void _cancelEditing() {
    FocusScope.of(context).unfocus();
    final discarded = List.of(_moments);
    setState(() {
      _moments.clear();
      _editing = false;
      _fromPreview = false;
      _opening = true;
      _selected = 0;
      _pickerError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final moment in discarded) {
        moment.dispose();
      }
    });
    unawaited(_open());
  }

  Future<void> _save() async {
    if (_saving || _moments.isEmpty || !_editing) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _stories.save(
        dateString: widget.date.key,
        existingItemUuid: widget.story?.itemUuid,
        newItemUuid: _newItemUuid,
        expectedRevision: widget.story?.revision ?? 0,
        photos: [
          for (final moment in _moments)
            (
              draft: moment.draft,
              caption: moment.caption.text,
              reflections: moment.reflections,
              seen: moment.seen,
            ),
        ],
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message
                : 'Your photo story couldn’t be saved. It’s still here.',
          ),
        ),
      );
    }
  }

  // One identity per new story, so a retried save can't add it twice.
  late final _newItemUuid =
      widget.newItemUuid ?? const Uuid().v4().replaceAll('-', '');

  @override
  void dispose() {
    _pages.dispose();
    _rail.dispose();
    _scroll.dispose();
    for (final moment in _moments) {
      moment.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_picking || !_editing || _moments.length >= 100) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _picking = true;
      _pickerError = null;
    });
    try {
      final recovery = DiaryPickerRecovery();
      final date = widget.date.key;
      final id = widget.story?.id ?? _newItemUuid;
      final recovered = widget.imagePicker == null
          ? await recovery.take(date, id)
          : null;
      if (widget.imagePicker == null && recovered == null) {
        await recovery.begin(date, id);
      }
      final files =
          recovered ??
          await (widget.imagePicker?.call() ??
              ImagePicker().pickMultiImage(
                maxWidth: 1800,
                maxHeight: 1800,
                imageQuality: 85,
                requestFullMetadata: false,
              ));
      if (widget.imagePicker == null) await recovery.clear();
      if (!mounted) return;
      final paths = _moments.map((moment) => moment.path).toSet();
      final hashes = {
        for (final moment in _moments)
          if (moment.draft.sha256.isNotEmpty) moment.draft.sha256,
      };
      final added = <_PhotoMoment>[];
      var unreadable = 0;
      for (final file in files.take(100 - _moments.length)) {
        if (!paths.add(file.path)) continue;
        try {
          if (await file.length() > 40 * 1024 * 1024) {
            throw const FormatException('Photo too large');
          }
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) throw const FormatException('Empty photo');
          final sha256 = await DiaryPhotoStore.digest(bytes);
          if (!hashes.add(sha256)) continue;
          added.add(
            _PhotoMoment(
              path: file.path,
              draft: DiaryPhotoDraft(
                bytes: bytes,
                sha256: sha256,
                sourceExtension: p.extension(file.path),
              ),
            ),
          );
        } catch (_) {
          unreadable++;
        }
      }
      if (!mounted) {
        for (final moment in added) {
          moment.dispose();
        }
        return;
      }
      setState(() {
        _moments.addAll(added);
        if (unreadable > 0) {
          _pickerError =
              'Some photos couldn’t be opened. Try choosing them again.';
        }
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _pickerError =
            error.code.contains('denied') || error.code.contains('restricted')
            ? 'Photo access is off. You can allow it in your device settings, then try again.'
            : 'Your photos couldn’t be opened. Please try again.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _pickerError =
              'Your photos couldn’t be opened. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _selectPhoto(int index) {
    FocusScope.of(context).unfocus();
    setState(() => _selected = index);
    if (_pages.hasClients) {
      if (_reduced) {
        _pages.jumpToPage(index);
      } else {
        _pages.animateToPage(
          index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    }
    _scrollRail();
  }

  void _scrollRail() {
    if (!_rail.hasClients) return;
    final target =
        (_selected *
                    (74.0 +
                        (MediaQuery.textScalerOf(context).scale(9) - 9) * 3) -
                80)
            .clamp(0.0, _rail.position.maxScrollExtent);
    if (_reduced) {
      _rail.jumpTo(target);
    } else {
      _rail.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _removePhoto(int index) {
    FocusScope.of(context).unfocus();
    final removed = _moments[index];
    setState(() {
      _moments.removeAt(index);
      _selected = _moments.isEmpty
          ? 0
          : _selected.clamp(0, _moments.length - 1);
    });
    // Let the old caption field detach before disposing its controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      removed.dispose();
      if (!mounted) return;
      if (_moments.isNotEmpty && _pages.hasClients) {
        _pages.jumpToPage(_selected);
      }
      _scrollRail();
    });
  }

  void _reorderPhoto(int oldIndex, int newIndex) {
    if (!_editing || oldIndex == newIndex) return;
    FocusScope.of(context).unfocus();
    final selected = _moments[_selected];
    setState(() {
      final moved = _moments.removeAt(oldIndex);
      _moments.insert(newIndex, moved);
      _selected = _moments.indexOf(selected);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pages.hasClients) _pages.jumpToPage(_selected);
      _scrollRail();
    });
  }

  void _showPhoto(_PhotoMoment moment, int index) {
    FocusScope.of(context).unfocus();
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: context.colors.surface,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  tooltip: 'Close photo',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Expanded(
                child: Semantics(
                  label: 'Photo ${index + 1}',
                  image: true,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: DiaryPhotoImage(
                        bytes: moment.bytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Pinch to zoom',
                  style: TextStyle(color: context.colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read above the Scaffold, which removes the keyboard inset from its body.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final typing = keyboard > 0;
    final palette = DiaryMemoryPalette.of(context);
    final background = palette.desk;
    return PopScope(
      canPop: !_saving && !_fromPreview,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving && _fromPreview) _cancelEditing();
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: _fromPreview
              ? DiaryInkAction(
                  key: const ValueKey('diary-photo-cancel-edit'),
                  label: 'Back to preview',
                  tooltip: 'Back to preview without saving',
                  onPressed: _saving ? null : _cancelEditing,
                  child: Center(
                    child: Transform.flip(
                      flipX: Directionality.of(context) == TextDirection.ltr,
                      child: DiaryInkGlyph(
                        symbol: DiaryInkSymbol.arrow,
                        color: palette.ink,
                      ),
                    ),
                  ),
                )
              : DiaryInkAction(
                  label: _closeLabel,
                  tooltip: _closeLabel,
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Center(
                    child: DiaryInkGlyph(
                      symbol: DiaryInkSymbol.close,
                      color: palette.ink,
                    ),
                  ),
                ),
          title: Text(
            'Photos',
            style: TextStyle(
              fontSize: 13,
              height: 1.2,
              fontStyle: FontStyle.italic,
              color: palette.ink,
            ),
          ),
          titleSpacing: 8,
          centerTitle: false,
          actions: [
            if (!_editing && !widget.readOnly)
              DiaryInkAction(
                key: const ValueKey('diary-photo-edit'),
                label: 'Edit photo story',
                tooltip: 'Edit photo story',
                onPressed: _opening ? null : _startEditing,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: DiaryInkGlyph(
                    symbol: DiaryInkSymbol.pencil,
                    color: palette.ink,
                  ),
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: LayoutBuilder(
                builder: (context, viewport) {
                  // Measured without the keyboard: switching layouts while
                  // typing would rebuild the caption field and drop focus.
                  final compact =
                      viewport.maxHeight + keyboard < 550 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.4;
                  final contents = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _dateLabel(),
                      const SizedBox(height: 16),
                      _opening ? _openingNotice() : _photos(),
                    ],
                  );
                  if (compact) {
                    return SingleChildScrollView(
                      controller: _scroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                            child: contents,
                          ),
                          if (!typing) _footer(),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                          child: contents,
                        ),
                      ),
                      if (!typing) _footer(),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _closeLabel =>
      _editing ? 'Close without saving' : 'Close photo story';

  Widget _dateLabel() => Text(
    widget.date.label(Localizations.localeOf(context).toString()),
    style: TextStyle(
      fontSize: 10,
      letterSpacing: 1,
      color: context.colors.onSurfaceVariant,
    ),
  );

  Widget _openingNotice() => Padding(
    padding: const EdgeInsets.only(top: 40),
    child: Center(
      child: Text(
        'Opening your photo story…',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: DiaryMemoryPalette.of(context).muted,
        ),
      ),
    ),
  );

  Widget _photos() {
    final palette = DiaryMemoryPalette.of(context);
    if (_moments.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 20),
          const DiaryPhotoInvitation(),
          const SizedBox(height: 25),
          Text(
            'Select one or more photos.',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: palette.muted,
            ),
          ),
          if (_pickerError != null) ...[
            const SizedBox(height: 22),
            _errorNotice(),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final imageHeight = (constraints.maxWidth * .55).clamp(
              150.0,
              300.0,
            );
            final scale = MediaQuery.textScalerOf(context);
            final captionHeight = scale.scale(14) * 1.6 * 2 + 8;
            final labelPainter =
                TextPainter(
                  text: TextSpan(
                    text:
                        'MOMENT ${_moments.length.toString().padLeft(2, '0')}',
                    style: DefaultTextStyle.of(context).style.copyWith(
                      fontSize: 12,
                      letterSpacing: .7,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: scale,
                )..layout(
                  maxWidth: (constraints.maxWidth - 92).clamp(
                    1.0,
                    double.infinity,
                  ),
                );
            final labelHeight = (labelPainter.height + 30).clamp(
              48.0,
              double.infinity,
            );
            labelPainter.dispose();
            return SizedBox(
              height: imageHeight + captionHeight + labelHeight + 45,
              child: PageView.builder(
                key: const ValueKey('diary-photo-pages'),
                controller: _pages,
                itemCount: _moments.length,
                onPageChanged: (index) {
                  setState(() => _selected = index);
                  _scrollRail();
                },
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: DiaryPhotoFrame(
                    bytes: _moments[index].bytes,
                    label: 'MOMENT ${(index + 1).toString().padLeft(2, '0')}',
                    height: imageHeight,
                    onTap: () => _showPhoto(_moments[index], index),
                    trailing: !_editing
                        ? null
                        : DiaryInkAction(
                            label: 'Remove photo ${index + 1}',
                            tooltip: 'Remove photo ${index + 1}',
                            onPressed: _saving
                                ? null
                                : () => _removePhoto(index),
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: DiaryInkGlyph(
                                symbol: DiaryInkSymbol.close,
                                color: palette.muted,
                                size: 18,
                              ),
                            ),
                          ),
                    caption: index == _selected
                        ? _caption(index, palette, captionHeight)
                        : SizedBox(height: captionHeight),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        DiaryPhotoContactSheet(
          photos: [
            for (final moment in _moments)
              (
                path: moment.path,
                bytes: moment.bytes,
                hasWords: moment.reflections.isNotEmpty,
              ),
          ],
          selected: _selected,
          controller: _rail,
          onSelect: _selectPhoto,
          onReorder: _reorderPhoto,
          onAdd: _picking || _saving || !_editing ? null : _pickPhotos,
          showAdd: _editing,
        ),
        const SizedBox(height: 12),
        Text(
          '${_selected + 1} of ${_moments.length} ${_moments.length == 1 ? 'photo' : 'photos'}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontStyle: FontStyle.italic,
            color: palette.muted,
          ),
        ),
        if (_pickerError != null) ...[
          const SizedBox(height: 16),
          _errorNotice(),
        ],
      ],
    );
  }

  Widget _caption(int index, DiaryMemoryPalette palette, double height) {
    if (!_editing) {
      final caption = _moments[index].caption.text.trim();
      return SizedBox(
        key: ValueKey('diary-photo-caption-preview-$index'),
        height: height,
        width: double.infinity,
        child: caption.isEmpty
            ? null
            : Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: palette.ink,
                  fontStyle: FontStyle.italic,
                ),
              ),
      );
    }
    return _captionField(index, palette);
  }

  Widget _captionField(int index, DiaryMemoryPalette palette) => CustomPaint(
    foregroundPainter: DiaryInkUnderline(ink: palette.muted),
    child: TextField(
      key: ValueKey('diary-photo-caption-$index'),
      controller: _moments[index].caption,
      readOnly: _saving,
      minLines: 2,
      maxLines: 2,
      maxLength: 240,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      style: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: palette.ink,
        fontStyle: FontStyle.italic,
      ),
      cursorColor: palette.ink,
      decoration: InputDecoration(
        hintText: 'Caption (optional)',
        hintStyle: TextStyle(color: palette.muted.withValues(alpha: .45)),
        counterText: '',
        contentPadding: const EdgeInsets.only(bottom: 8),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    ),
  );

  Widget _errorNotice() => Semantics(
    liveRegion: true,
    child: Text(
      _pickerError!,
      style: TextStyle(color: context.colors.error, fontSize: 13, height: 1.5),
    ),
  );

  Widget _footer() {
    final palette = DiaryMemoryPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_moments.isEmpty && !_opening && _editing)
            DiaryPaperTicket(
              label: _picking ? 'Opening your photos…' : 'Choose photos',
              onPressed: _picking ? null : _pickPhotos,
              symbol: DiaryInkSymbol.album,
            )
          else ...[
            Text(
              _moments.any((moment) => moment.draft.missing)
                  ? 'Some photos are kept only on the device that added them. Sync shares captions and words, not photos.'
                  : 'Photos stay on this device. Sync shares captions and words, not photos.',
              key: const ValueKey('diary-photo-local-note'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, height: 1.5, color: palette.muted),
            ),
            if (widget.readOnly) ...[
              const SizedBox(height: 4),
              Text(
                'Saved stories can be changed on your primary device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.5,
                  color: palette.muted,
                ),
              ),
            ],
            if (_editing) ...[
              const SizedBox(height: 12),
              DiaryPaperTicket(
                key: const ValueKey('diary-photo-save'),
                label: _saving
                    ? 'Saving…'
                    : _reopened
                    ? 'Save changes'
                    : 'Save to diary',
                onPressed: _saving || _opening || _picking || _moments.isEmpty
                    ? null
                    : _save,
                symbol: DiaryInkSymbol.check,
                tone: 2,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
