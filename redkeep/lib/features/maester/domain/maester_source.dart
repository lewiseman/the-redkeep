import '../../brain/domain/brain.dart';

enum MaesterKind { note, diary, flow }

/// Immutable request provenance. [version] includes the editor's change counter,
/// title and raw selection, so editing and then undoing still expires a proposal.
class MaesterSource {
  const MaesterSource({
    required this.kind,
    required this.id,
    required this.revision,
    required this.version,
    required this.body,
    this.start = 0,
    required this.end,
    this.editing = false,
  });
  final MaesterKind kind;
  final String id;
  final int revision;
  final Object version;
  final String body;
  final int start;
  final int end;
  final bool editing;
  String get text => body.substring(start, end);
  bool get bounded => text.trim().isNotEmpty && text.length <= 2000;
  bool get selected => start != 0 || end != body.length;
  List<BrainCapability> get actions => switch (kind) {
    MaesterKind.note => [
      if (editing) BrainCapability.rewrite,
      BrainCapability.summarize,
    ],
    MaesterKind.diary => [BrainCapability.summarize],
    MaesterKind.flow => [BrainCapability.reflect],
  };

  bool matches(MaesterSource? other) =>
      other != null &&
      kind == other.kind &&
      id == other.id &&
      revision == other.revision &&
      version == other.version &&
      body == other.body &&
      start == other.start &&
      end == other.end &&
      editing == other.editing;
}

class MaesterProposal {
  const MaesterProposal(this.source, this.capability, this.output);
  final MaesterSource source;
  final BrainCapability capability;
  final String output;
}

/// Each mounted helper owns one context; callbacks resolve the current feature
/// boundary rather than holding a mutable document or database row.
class MaesterContext {
  const MaesterContext({
    required this.current,
    required this.validate,
    this.accept,
  });
  final MaesterSource? Function() current;
  final Future<bool> Function(MaesterSource) validate;
  final Future<bool> Function(MaesterProposal, bool Function() stillCurrent)?
  accept;
}
