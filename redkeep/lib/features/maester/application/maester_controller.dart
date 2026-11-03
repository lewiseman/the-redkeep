import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/application/brain_executor.dart';
import '../../brain/application/brain_providers.dart';
import '../../brain/domain/brain.dart';
import '../domain/maester_source.dart';

final maesterControllerProvider = NotifierProvider.autoDispose
    .family<MaesterController, MaesterState, MaesterContext>(
      MaesterController.new,
    );

class MaesterState {
  const MaesterState({
    this.busy = false,
    this.checking = false,
    this.ready = const {},
    this.output = '',
    this.proposal,
    this.failure,
    this.expired = false,
    this.accepted = false,
  });
  final bool busy;
  final bool checking;
  final Map<BrainCapability, BrainModel> ready;
  final String output;
  final MaesterProposal? proposal;
  final BrainFailure? failure;
  final bool expired;
  final bool accepted;
}

/// One explicit interaction. Never loads at startup, resumes automatically, or
/// writes a document. Only a reviewed rewrite can call the injected edit boundary.
class MaesterController extends Notifier<MaesterState> {
  MaesterController(this.context);
  final MaesterContext context;
  BrainExecutor? _executor;
  final _owner = Object();
  bool _ownsExecution = false;
  bool _running = false;
  bool _reviewing = false;
  bool _foreground = true;
  bool _invalidated = false;
  int _generation = 0;
  MaesterSource? _captured;

  @override
  MaesterState build() {
    ref.onDispose(() {
      _generation++;
      if (_ownsExecution) unawaited(_executor?.cancel(owner: _owner));
    });
    return const MaesterState();
  }

  bool _current(int generation, MaesterSource source) =>
      ref.mounted &&
      _foreground &&
      !_invalidated &&
      generation == _generation &&
      source.matches(context.current());

  Future<Map<BrainCapability, BrainModel>> _readiness() async {
    final assignments = await ref.read(brainAssignmentsProvider).read();
    if (!ref.mounted) return {};
    final catalog = ref.read(brainCatalogProvider);
    final ready = <BrainCapability, BrainModel>{};
    final checked = <String, ModelFileState>{};
    for (final assignment in assignments) {
      final compatible = catalog.where(
        (m) =>
            m.id == assignment.modelId &&
            m.capabilities.contains(assignment.capability),
      );
      if (compatible.isEmpty) continue;
      final model = compatible.first;
      if (!checked.containsKey(model.id)) {
        final files = await ref.read(brainModelFilesProvider.future);
        if (!ref.mounted) return {};
        checked[model.id] = await files.inspect(model);
        if (!ref.mounted) return {};
      }
      if (checked[model.id] == ModelFileState.available) {
        ready[assignment.capability] = model;
      }
    }
    return Map.unmodifiable(ready);
  }

  Future<void> refresh() async {
    if (!ref.mounted || state.busy || !_foreground) return;
    final generation = ++_generation;
    state = const MaesterState(busy: true, checking: true);
    try {
      final ready = await _readiness();
      if (ref.mounted && generation == _generation) {
        state = MaesterState(ready: ready);
      }
    } catch (error) {
      if (ref.mounted && generation == _generation) {
        state = MaesterState(failure: _failure(error));
      }
    }
  }

  Future<void> run(BrainCapability capability) async {
    if (!ref.mounted || state.busy || !_foreground) return;
    final source = context.current();
    if (source == null || !source.actions.contains(capability)) return;
    _running = true;
    _captured = source;
    _invalidated = false;
    final generation = ++_generation;
    final previousReady = state.ready;
    state = MaesterState(busy: true, ready: previousReady);
    try {
      if (!source.bounded) throw const BrainException(BrainFailure.input);
      if (!await context.validate(source)) {
        sourceChanged(force: true);
        return;
      }
      if (!_current(generation, source)) return;
      // Resolve committed assignments again for every explicit attempt.
      final ready = await _readiness();
      if (!_current(generation, source)) return;
      final model = ready[capability];
      if (model == null) throw const BrainException(BrainFailure.unassigned);
      final executor = await ref.read(brainExecutorProvider.future);
      if (!_current(generation, source)) return;
      _executor = executor;
      final work = executor.execute(
        owner: _owner,
        model: model,
        capability: capability,
        text: source.text,
        onChunk: (chunk) {
          if (_current(generation, source)) {
            state = MaesterState(
              busy: true,
              ready: ready,
              output: state.output + chunk,
            );
          }
        },
      );
      _ownsExecution = true;
      await work;
      _ownsExecution = false;
      if (!_current(generation, source)) return;
      if (!await context.validate(source)) {
        sourceChanged(force: true);
        return;
      }
      if (!_current(generation, source)) return;
      if (state.output.trim().isEmpty) {
        throw const BrainException(BrainFailure.generation);
      }
      state = MaesterState(
        ready: ready,
        output: state.output,
        proposal: MaesterProposal(source, capability, state.output),
      );
    } catch (error) {
      if (ref.mounted && generation == _generation) {
        final failure = _failure(error);
        state = MaesterState(
          ready:
              failure == BrainFailure.missing ||
                  failure == BrainFailure.integrity ||
                  failure == BrainFailure.unassigned
              ? const {}
              : previousReady,
          output: state.output,
          failure: failure,
        );
      }
    } finally {
      _running = false;
      _ownsExecution = false;
      if (ref.mounted && state.busy) {
        state = MaesterState(
          ready: state.ready,
          expired: state.expired || generation == _generation,
          failure: state.failure,
        );
      }
    }
  }

  Future<bool> accept() async {
    final proposal = state.proposal;
    final apply = context.accept;
    if (proposal == null ||
        state.busy ||
        apply == null ||
        proposal.capability != BrainCapability.rewrite) {
      return false;
    }
    final generation = _generation;
    _reviewing = true;
    bool valid() => _current(generation, proposal.source);
    state = MaesterState(
      busy: true,
      ready: state.ready,
      output: proposal.output,
      proposal: proposal,
    );
    try {
      if (!valid() || !await context.validate(proposal.source) || !valid()) {
        sourceChanged(force: true);
        return false;
      }
      final accepted = await apply(proposal, valid);
      if (!ref.mounted) return false;
      // Applying the edit deliberately changes the source and expires its token.
      if (accepted) _captured = null;
      state = accepted
          ? const MaesterState(accepted: true)
          : const MaesterState(expired: true);
      return accepted;
    } catch (_) {
      if (ref.mounted) state = const MaesterState(expired: true);
      return false;
    } finally {
      _reviewing = false;
      if (ref.mounted && state.busy) {
        state = const MaesterState(expired: true);
      }
    }
  }

  void sourceChanged({bool force = false}) {
    if (!ref.mounted ||
        _captured == null ||
        !force && _captured!.matches(context.current())) {
      return;
    }
    _invalidated = true;
    _generation++;
    final busy = _running || _reviewing;
    state = MaesterState(busy: busy, ready: state.ready, expired: true);
    if (_ownsExecution) unawaited(_executor?.cancel(owner: _owner));
  }

  Future<void> cancel() async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    _invalidated = true;
    final busy = _running || _reviewing;
    state = MaesterState(
      busy: busy,
      ready: state.ready,
      failure: BrainFailure.cancelled,
    );
    if (_ownsExecution) await _executor?.cancel(owner: _owner);
    if (ref.mounted && generation == _generation && !_running && !_reviewing) {
      state = MaesterState(
        ready: state.ready,
        failure: state.failure,
        expired: state.expired,
      );
    }
  }

  /// Suppress output synchronously on widget disposal without publishing state
  /// while Flutter is unmounting the route. The provider owns final teardown.
  void detach() {
    _foreground = false;
    _invalidated = true;
    _generation++;
    if (_ownsExecution) unawaited(_executor?.cancel(owner: _owner));
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) unawaited(cancel());
  }

  BrainFailure _failure(Object error) =>
      error is BrainException ? error.failure : BrainFailure.storage;
}
