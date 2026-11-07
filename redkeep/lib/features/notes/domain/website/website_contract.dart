import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../note_checklist.dart';

/// An interactive website written whole by the model from a note.
const noteWebsiteOperation = 'build-website';
const websiteBriefChars = 240;
const websiteMaxPhotos = 6;

/// The note, title and brief together; a little under the job's source cap.
const websiteInputBytes = 100000;

/// The largest page kept, before the app's own head is added.
const websiteOutputBytes = 2 * 1024 * 1024;

final _control = RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]');

/// SHA-256 of [content], kept beside a website to notice later edits.
String websiteContentHash(String content) => Sha256()
    .toSync()
    .hashSync(utf8.encode(content))
    .bytes
    .map((b) => b.toRadixString(16).padLeft(2, '0'))
    .join();

/// What is sent to make a website: the note's title and text, the person's
/// optional brief, and how many photos the page may place. The photos
/// themselves stay on this phone.
class WebsiteRequest {
  const WebsiteRequest({
    required this.title,
    required this.body,
    this.brief = '',
    this.photos = 0,
  });
  final String title, body, brief;
  final int photos;

  /// The brief as sent: one line, trimmed.
  String get cleanBrief => brief.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Throws [FormatException] when the note or brief does not fit.
  String request() {
    if (body.trim().isEmpty) {
      throw const FormatException('Write something in this note first.');
    }
    if (cleanBrief.runes.length > websiteBriefChars ||
        _control.hasMatch(body) ||
        _control.hasMatch(title) ||
        photos < 0 ||
        photos > websiteMaxPhotos) {
      throw const FormatException(
        'Describe the website in one line of at most 240 characters.',
      );
    }
    final value = jsonEncode({
      'title': title.trim(),
      'text': body,
      'brief': cleanBrief,
      'photos': photos,
    });
    if (utf8.encode(value).length > websiteInputBytes) {
      throw const FormatException(
        'This note is too long to make a website from. Nothing was sent.',
      );
    }
    return value;
  }
}

/// How the app looks right now, handed to a website so it can match.
class WebsiteAppearance {
  const WebsiteAppearance({
    this.dark = false,
    this.reduceMotion = false,
    this.simpleEffects = false,
    this.tokens = const {},
  });
  final bool dark, reduceMotion, simpleEffects;

  /// `bg`, `fg`, `muted`, `accent` and `surface`, as `#rrggbb` colours.
  final Map<String, String> tokens;

  static final _colour = RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$');
  static const tokenNames = {'bg', 'fg', 'muted', 'accent', 'surface'};

  Map<String, Object> toJson() => {
    'theme': dark ? 'dark' : 'light',
    'motion': reduceMotion ? 'reduce' : 'full',
    'effects': simpleEffects ? 'simple' : 'full',
    'tokens': {
      for (final MapEntry(:key, :value) in tokens.entries)
        if (tokenNames.contains(key) && _colour.hasMatch(value)) key: value,
    },
  };

  /// A statement that re-themes an open page without reloading it.
  String get script =>
      'window.redkeep&&window.redkeep.setAppearance('
      '${jsonEncode(toJson())});';

  @override
  bool operator ==(Object other) =>
      other is WebsiteAppearance &&
      jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// The policy every page carries: inline code only, and nothing may reach
/// the network. The web view also blocks every navigation.
const websitePolicy =
    "default-src 'none'; script-src 'unsafe-inline'; "
    "style-src 'unsafe-inline'; img-src data: blob:; font-src data:; "
    "media-src data: blob:; connect-src 'none'; form-action 'none'; "
    "base-uri 'none'; frame-src 'none'; child-src 'none'; worker-src 'none'; "
    "manifest-src 'none'; object-src 'none'";

/// Defines `window.redkeep`: the app themes the page through it, and the
/// page talks to the app only through it. Pages cannot replace it. Without
/// the app's channel (a preview) saving and ticking quietly do nothing.
const _bootstrap =
    r'''(function(){var r=document.documentElement,data={};try{var el=document.getElementById('redkeep-data');if(el){data=JSON.parse(el.textContent)||{};}}catch(e){}var state=data.state===undefined?null:data.state,checklist=Array.isArray(data.checklist)?data.checklist:[],pending={},next=1,bridge=window.RedkeepBridge;function emit(n,d){try{window.dispatchEvent(new CustomEvent(n,{detail:d}));}catch(e){}}function post(m){try{if(bridge&&typeof bridge.postMessage==='function'){bridge.postMessage(JSON.stringify(m));return true;}}catch(e){}return false;}function request(m){return new Promise(function(done){var id=next++;m.id=id;pending[id]=done;if(!post(m)){delete pending[id];done(false);}});}function set(a){if(!a)return;r.setAttribute('data-theme',a.theme==='dark'?'dark':'light');r.setAttribute('data-motion',a.motion==='reduce'?'reduce':'full');r.setAttribute('data-effects',a.effects==='simple'?'simple':'full');r.style.colorScheme=a.theme==='dark'?'dark':'light';var t=a.tokens||{};for(var k in t){if(Object.prototype.hasOwnProperty.call(t,k)){r.style.setProperty('--rk-'+k,t[k]);}}emit('redkeep:appearance',a);}var api={setAppearance:set,save:function(value){var text;try{text=JSON.stringify(value);}catch(e){return false;}if(text===undefined)return false;state=JSON.parse(text);return post({type:'save',state:state});},setChecklistItem:function(text,done){return request({type:'check',text:String(text),done:done===true});},haptic:function(kind){post({type:'haptic',kind:String(kind||'light')});},_reply:function(id,ok){var f=pending[id];if(f){delete pending[id];f(ok===true);}},_checklist:function(items){checklist=Array.isArray(items)?items:[];emit('redkeep:checklist',checklist);}};Object.defineProperty(api,'state',{get:function(){return state;},enumerable:true});Object.defineProperty(api,'checklist',{get:function(){return checklist.slice();},enumerable:true});try{Object.defineProperty(window,'redkeep',{value:Object.freeze(api),writable:false,configurable:false});}catch(e){}})();''';

/// What a page opens with: what it saved for itself, and the note's
/// checklist as it is now.
class WebsitePageData {
  const WebsitePageData({this.state = '', this.checklist = const []});

  /// JSON the page saved; empty for none.
  final String state;
  final List<NoteChecklistItem> checklist;

  /// Safe inside a `<script type="application/json">`: nothing in it can
  /// close the element.
  String encode() {
    Object? saved;
    try {
      saved = state.isEmpty ? null : jsonDecode(state);
    } on FormatException {
      saved = null;
    }
    return jsonEncode({
      'state': saved,
      'checklist': [for (final item in checklist) item.toJson()],
    }).replaceAll('<', r'\u003c');
  }
}

const _removed = {
  'iframe',
  'frame',
  'frameset',
  'object',
  'embed',
  'applet',
  'link',
  'base',
  'portal',
  'fencedframe',
};
const _urlAttributes = {
  'src',
  'href',
  'srcset',
  'action',
  'formaction',
  'poster',
  'background',
  'xlink:href',
  'ping',
  'data',
  'codebase',
  'manifest',
};
// Any url() that is not inline data, imported sheets, and legacy expressions.
final _remoteCss = RegExp(
  r'url\(\s*(?![\x22\x27]?\s*(?:data:|#))[^)]*\)|@import[^;]*;?|expression\s*\(',
  caseSensitive: false,
);
final _fence = RegExp(
  r'^```(?:html)?\s*\n([\s\S]*?)\n?```$',
  caseSensitive: false,
);

/// The app's own marker on what it adds, so a page checked twice is not
/// given two heads.
const _ownMarker = 'data-redkeep';

/// Rebuilds [raw] as a self-contained page: its own inline scripts and
/// styles stay, while frames, plugins, remote resources and links away are
/// removed and a strict content policy is put first. With [appearance] the
/// page opens already themed. Throws [FormatException] when the page is
/// unusable, including when the model was cut off.
String sanitizeWebsite(
  String raw, {
  WebsiteAppearance? appearance,
  WebsitePageData? data,
}) {
  var text = raw.trim();
  final fence = _fence.firstMatch(text);
  if (fence != null) text = fence.group(1)!.trim();
  if (text.isEmpty || utf8.encode(text).length > websiteOutputBytes) {
    throw const FormatException('The website is too large to keep.');
  }
  if (_control.hasMatch(text)) {
    throw const FormatException('The website could not be read.');
  }
  if (!RegExp(r'</html\s*>\s*$', caseSensitive: false).hasMatch(text)) {
    throw const FormatException(
      'The website was cut off. Try again, or ask for a simpler page.',
    );
  }
  final document = html.parse(text);
  for (final element in document.querySelectorAll('*').toList()) {
    final name = element.localName ?? '';
    final attributes = element.attributes;
    final drop =
        _removed.contains(name) ||
        attributes.containsKey(_ownMarker) ||
        attributes['id'] == 'redkeep-data' ||
        (name == 'script' && attributes.containsKey('src')) ||
        (name == 'meta' &&
            (attributes.containsKey('http-equiv') ||
                attributes.containsKey('charset') ||
                {
                  'viewport',
                  'color-scheme',
                }.contains(attributes['name']?.toLowerCase())));
    if (drop) {
      element.remove();
      continue;
    }
    for (final key in attributes.keys.toList()) {
      final attribute = key.toString().toLowerCase();
      final value = (attributes[key] ?? '').trim().toLowerCase();
      final inline = value.startsWith('data:') || value.startsWith('blob:');
      final local =
          value.startsWith('#') ||
          (inline && attribute != 'href' && attribute != 'xlink:href');
      if ((_urlAttributes.contains(attribute) && !local) ||
          (attribute == 'style' && _remoteCss.hasMatch(attributes[key]!))) {
        attributes.remove(key);
      }
    }
    if (name == 'style' && _remoteCss.hasMatch(element.text)) {
      element.text = element.text.replaceAll(_remoteCss, 'none');
    }
  }
  final body = document.body;
  if (body == null || !_hasReadableText(body)) {
    throw const FormatException('The website has no content.');
  }
  final root = document.documentElement!;
  final head = document.head ?? dom.Element.tag('head');
  if (document.head == null) root.insertBefore(head, root.firstChild);
  dom.Element meta(Map<String, String> values) =>
      dom.Element.tag('meta')..attributes.addAll({...values, _ownMarker: ''});
  head.nodes.insertAll(0, [
    meta({'charset': 'utf-8'}),
    meta({'http-equiv': 'Content-Security-Policy', 'content': websitePolicy}),
    meta({
      'name': 'viewport',
      'content': 'width=device-width, initial-scale=1, viewport-fit=cover',
    }),
    meta({'name': 'color-scheme', 'content': 'light dark'}),
    if (data != null)
      dom.Element.tag('script')
        ..attributes.addAll({
          'type': 'application/json',
          'id': 'redkeep-data',
          _ownMarker: '',
        })
        ..text = data.encode(),
    dom.Element.tag('script')
      ..attributes[_ownMarker] = ''
      ..text = _bootstrap,
  ]);
  root.attributes.removeWhere(
    (key, _) => {
      'data-theme',
      'data-motion',
      'data-effects',
    }.contains(key.toString().toLowerCase()),
  );
  if (appearance != null) {
    final values = appearance.toJson();
    root.attributes.addAll({
      'data-theme': values['theme'] as String,
      'data-motion': values['motion'] as String,
      'data-effects': values['effects'] as String,
    });
    final tokens = values['tokens'] as Map<String, String>;
    final style = [
      'color-scheme: ${values['theme']}',
      for (final MapEntry(:key, :value) in tokens.entries) '--rk-$key: $value',
    ].join('; ');
    final own = root.attributes['style'];
    root.attributes['style'] = own == null || own.trim().isEmpty
        ? style
        : '$style; $own';
  }
  final result = '<!doctype html>\n${root.outerHtml}';
  if (utf8.encode(result).length > websiteOutputBytes + 16384) {
    throw const FormatException('The website is too large to keep.');
  }
  return result;
}

/// Whether [element] shows words of its own, not only code or styles. The
/// note's words must be readable even before any script runs.
bool _hasReadableText(dom.Element element) {
  for (final node in element.nodes) {
    if (node is dom.Text && node.text.trim().isNotEmpty) return true;
    if (node is dom.Element &&
        !const {'script', 'style', 'template'}.contains(node.localName) &&
        _hasReadableText(node)) {
      return true;
    }
  }
  return false;
}

/// [sanitizeWebsite] in a killable worker, which bounds the parser on large
/// or malformed pages.
Future<String> sanitizeWebsiteBounded(
  String raw, {
  WebsiteAppearance? appearance,
  WebsitePageData? data,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final port = ReceivePort();
  Isolate? worker;
  try {
    worker = await Isolate.spawn(
      (SendPort send) {
        try {
          send.send(sanitizeWebsite(raw, appearance: appearance, data: data));
        } on FormatException catch (error) {
          send.send(['error', error.message]);
        } catch (_) {
          send.send(null);
        }
      },
      port.sendPort,
      onError: port.sendPort,
      onExit: port.sendPort,
    );
    final result = await port.first.timeout(timeout);
    if (result is List && result.length == 2 && result.last is String) {
      throw FormatException(result.last as String);
    }
    if (result is! String) {
      throw const FormatException('This website could not be made safe.');
    }
    return result;
  } finally {
    worker?.kill(priority: Isolate.immediate);
    port.close();
  }
}

/// The page as the model wrote it: without what the app adds to its head.
/// A remix is asked of, and applied to, exactly this text.
String websiteSource(String page) {
  final document = html.parse(page);
  for (final own in document.querySelectorAll('[$_ownMarker]').toList()) {
    own.remove();
  }
  return '<!doctype html>\n${document.documentElement!.outerHtml}';
}

/// The largest page a remix sends; larger pages are built again instead.
const websiteRemixInputBytes = 400000;

final _edit = RegExp(
  r'<<<<<<< FIND\r?\n([\s\S]*?)\r?\n=======\r?\n([\s\S]*?)\r?\n?>>>>>>> REPLACE',
);

/// Applies a remix to [source] (see [websiteSource]). The model returns
/// either FIND/REPLACE edits, each of which must match exactly once, or a
/// whole new document for a sweeping change. Throws [FormatException] when
/// the remix does not fit the page, leaving it unchanged.
String applyWebsiteRemix(String source, String output) {
  var text = output.trim();
  final fence = _fence.firstMatch(text);
  if (fence != null) text = fence.group(1)!.trim();
  if (RegExp(r'^(<!doctype html|<html)', caseSensitive: false).hasMatch(text)) {
    return text;
  }
  final edits = _edit.allMatches(text).toList();
  if (edits.isEmpty) {
    throw const FormatException(
      'The remix could not be applied. Your website is unchanged; try again.',
    );
  }
  var page = source;
  for (final edit in edits) {
    final find = edit[1]!, replace = edit[2]!;
    final at = find.isEmpty ? -1 : page.indexOf(find);
    if (at < 0 || page.indexOf(find, at + 1) >= 0) {
      throw const FormatException(
        'The remix did not match the page. Your website is unchanged; try again.',
      );
    }
    page = page.replaceRange(at, at + find.length, replace);
  }
  return page;
}
