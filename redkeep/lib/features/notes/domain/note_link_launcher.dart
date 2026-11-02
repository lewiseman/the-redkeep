/// Only explicit absolute web URLs may leave the preview. Relative, credential,
/// local-file, data and executable/custom schemes never reach a platform plugin.
Uri? safeNoteLink(String? value) {
  if (value == null || value.contains(RegExp(r'[\s\\\x00-\x1f\x7f]'))) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['https', 'http'].contains(uri.scheme) ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

abstract interface class NoteLinkLauncher {
  Future<bool> open(Uri uri);
}
