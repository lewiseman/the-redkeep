class ThoughtReflection {
  const ThoughtReflection({
    required this.taskId,
    required this.thoughtId,
    required this.version,
    required this.text,
    required this.kept,
  });
  final String taskId, thoughtId, version, text;
  final bool kept;
}

class ThoughtReflections {
  const ThoughtReflections({this.proposal, this.kept});
  final ThoughtReflection? proposal, kept;
}
