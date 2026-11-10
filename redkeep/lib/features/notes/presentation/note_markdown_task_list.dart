import 'package:markdown/markdown.dart' as md;

const noteTaskMarkerAttribute = 'redkeep-task-marker';
final _task = RegExp(r'^[-+*][ \t] {0,3}\[[ xX]\][ \t]', multiLine: true);

/// Annotates top-level task items while the normal Markdown parser still has
/// their source lines. The renderer only passes the checked flag to its
/// checkbox builder, so it cannot find the right marker from the label.
class NoteMarkdownTaskList extends md.UnorderedListWithCheckboxSyntax {
  NoteMarkdownTaskList(this.body);

  static bool hasTasks(String body) => _task.hasMatch(body);

  final String body;
  WeakReference<md.BlockParser>? _root;
  int _line = 0;
  int _offset = 0;

  late final extensions = _extensions();

  md.ExtensionSet _extensions() {
    final gfm = md.ExtensionSet.gitHubFlavored;
    return md.ExtensionSet([
      for (final syntax in gfm.blockSyntaxes)
        if (syntax is md.UnorderedListWithCheckboxSyntax) this else syntax,
    ], gfm.inlineSyntaxes);
  }

  @override
  bool canParse(md.BlockParser parser) {
    // This syntax is tried before any GFM syntax that parses nested blocks.
    if (!identical(_root?.target?.document, parser.document)) {
      _root = WeakReference(parser);
      _line = _offset = 0;
    }
    return super.canParse(parser);
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final first = parser.current;
    final list = super.parse(parser) as md.Element;
    if (!identical(_root?.target, parser) ||
        list.attributes['class'] != 'contains-task-list') {
      return list;
    }

    final lines = parser.lines;
    while (!identical(lines[_line], first)) {
      _advance(lines[_line]);
    }
    final next = parser.isDone ? null : parser.current;
    final markers = <int>[];
    while (_line < lines.length && !identical(lines[_line], next)) {
      final line = lines[_line];
      final match = _task.matchAsPrefix(line.content);
      if (match != null) markers.add(_offset + match.end - 3);
      _advance(line);
    }

    final items = list.children!
        .cast<md.Element>()
        .where((item) => item.attributes['class'] == 'task-list-item')
        .toList();
    // Unindented task lines in this block always start a direct list item.
    // If the parser found additional direct tasks, their source form is
    // outside this mapping. Leave the block as rendered in that case.
    if (items.length != markers.length) return list;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final children = item.children!;
      if (children.first case final md.Element paragraph
          when paragraph.tag == 'p') {
        // Loose lists put the checkbox inside the paragraph. The Flutter
        // renderer looks for it at the start of the list item.
        children.insert(0, paragraph.children!.removeAt(0));
      }
      item.attributes[noteTaskMarkerAttribute] = '${markers[i]}';
    }
    return list;
  }

  void _advance(md.Line line) {
    _line++;
    _offset += line.content.length;
    if (_offset < body.length && body.codeUnitAt(_offset) == 13) _offset++;
    if (_offset < body.length && body.codeUnitAt(_offset) == 10) _offset++;
  }
}
