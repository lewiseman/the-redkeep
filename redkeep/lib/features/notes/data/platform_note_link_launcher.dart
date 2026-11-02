import 'package:url_launcher/url_launcher.dart';

import '../domain/note_link_launcher.dart';

class PlatformNoteLinkLauncher implements NoteLinkLauncher {
  const PlatformNoteLinkLauncher();
  @override
  Future<bool> open(Uri uri) async {
    if (safeNoteLink(uri.toString()) == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
