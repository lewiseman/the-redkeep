import 'dart:convert';

import 'ai_operation.dart';

class AiJob {
  const AiJob({
    required this.id,
    required this.operation,
    required this.key,
    required this.created,
    required this.provider,
    this.computerId = '',
    this.deviceId = '',
    this.modelId = '',
    this.providerId = '',
    this.providerName = '',
    this.prompt = '',
    this.source = '',
    this.phase = 'submitting',
    this.text,
    this.accepted = false,
    this.cancelWanted = false,
    this.ackPending = false,
  });
  final String id,
      key,
      provider,
      computerId,
      deviceId,
      modelId,
      providerId,
      providerName,
      prompt,
      source,
      phase;
  final AiOperation operation;
  final int created;
  final String? text;
  final bool accepted, cancelWanted, ackPending;
  bool get terminal => const {
    'completed',
    'failed',
    'cancelled',
    'interrupted',
    'expired',
  }.contains(phase);

  /// Old `device` tasks can still appear until their receipts age out.
  String get destinationLabel => switch (provider) {
    'companion' => 'Computer',
    'provider' => providerName,
    _ => 'Phone',
  };
  int get expires => created + const Duration(hours: 24).inMilliseconds;
  AiJob copy({
    String? phase,
    String? text,
    bool? accepted,
    bool? cancelWanted,
    bool? ackPending,
  }) => AiJob(
    id: id,
    operation: operation,
    key: key,
    created: created,
    provider: provider,
    computerId: computerId,
    deviceId: deviceId,
    modelId: modelId,
    providerId: providerId,
    providerName: providerName,
    prompt: prompt,
    source: source,
    phase: phase ?? this.phase,
    text: text ?? this.text,
    accepted: accepted ?? this.accepted,
    cancelWanted: cancelWanted ?? this.cancelWanted,
    ackPending: ackPending ?? this.ackPending,
  );
  Map<String, dynamic> json({bool sensitive = true}) => {
    'id': id,
    'operation': operation.name,
    'key': key,
    'created': created,
    'provider': provider,
    'computerId': computerId,
    'deviceId': deviceId,
    'modelId': modelId,
    'providerId': providerId,
    'providerName': providerName,
    'phase': phase,
    'accepted': accepted,
    'cancelWanted': cancelWanted,
    'ackPending': ackPending,
    if (sensitive) ...{'prompt': prompt, 'source': source, 'text': text},
  };
  factory AiJob.fromJson(Map<String, dynamic> j) {
    if (j['id'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{8,80}$').hasMatch(j['id'] as String) ||
        !{'device', 'companion', 'provider'}.contains(j['provider']) ||
        j['created'] is! int ||
        j['key'] is! String ||
        (j['source'] as String? ?? '').length > 131072 ||
        utf8.encode(j['prompt'] as String? ?? '').length >
            AiOperation.values.byName(j['operation'] as String).inputBytes) {
      throw const FormatException('Invalid protected AI task');
    }
    return AiJob(
      id: j['id'] as String,
      operation: AiOperation.values.byName(j['operation'] as String),
      key: j['key'] as String,
      created: j['created'] as int,
      provider: j['provider'] as String,
      computerId: j['computerId'] as String? ?? '',
      deviceId: j['deviceId'] as String? ?? '',
      modelId: j['modelId'] as String? ?? '',
      providerId: j['providerId'] as String? ?? '',
      providerName: j['providerName'] as String? ?? '',
      prompt: j['prompt'] as String? ?? '',
      source: j['source'] as String? ?? '',
      phase: j['phase'] as String? ?? 'interrupted',
      text: j['text'] as String?,
      accepted: j['accepted'] == true,
      cancelWanted: j['cancelWanted'] == true,
      ackPending: j['ackPending'] == true,
    );
  }
}
