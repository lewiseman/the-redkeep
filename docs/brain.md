# Brain: optional device AI

M10 implements Brain at **More → Brain** (`/settings/brain`). Its continuation
survives required-artwork setup and onboarding. Normal Notes, Diary and Flow
writing does not create Brain providers, inspect model files, contact a model
host, initialize the plugin, or load weights. Model downloads are optional and
have no connection to the required-media catalog or its startup gate.

## Assignments and capability boundary

`features/brain/domain/brain.dart` defines rewriting, summarizing and short
reflection, model metadata, safe failures, cancellation and injected assignment/
file boundaries. Schema **7** of the existing background Drift database adds
only `brain_assignments`, keyed by capability. Fresh installations have no
assignments. A row contains a stable pinned model ID and `source = device`;
constraints reject unsupported source/capability values. Assignment feedback
follows the committed write. Versions 1–6 retain their writing, drafts, metadata,
tombstones, revisions and sequence tokens.

An assignment can be saved before downloading. Removal retains assignments and
writing, so reinstalling can restore readiness without reconfiguration. Unknown
or incompatible assignments are shown as unavailable and cannot execute.
Controller and executor validate capability support; a stored row alone is not
proof of compatibility or installed files. Only device execution is selectable.
There are no API keys, companion controls, embedding profiles or backend stubs.

The current catalog contains the same Apache-2.0 Qwen3 0.6B INT8 LiteRT-LM
artifact qualified in [M03](ai-feasibility.md): revision
`722a0a54c1301a4b07a9856a9590d56362f0969b`, **613,722,264 bytes** (585.29 MiB),
SHA-256 `c5f39b4191926786c3e6668b62af4d6eb15248dfc7a5348252a9b406f33f2108`.
`tool/ai/qwen3-0.6b.json` retains the native harness pin. The production catalog
uses its immutable public HTTPS URL. Core **2.5.5** and LiteRT-LM **1.19.1**
remain pinned; no dependency or native configuration changed in M10.

## Installation, readiness and recovery

`FileBrainModels` keeps weights in app support `brain-models/<model-id>.litertlm`.
Transfers use a sibling `.part`; neither a complete-looking partial nor a saved
assignment is an installation. Each install starts from zero, bounds received
bytes, verifies exact size/SHA-256, flushes/closes the file, then promotes it by
same-filesystem rename. The previous target is not removed before promotion.
Completed files are recognized after restart without a network check. A crash
before rename leaves an **interrupted** partial; a crash after rename leaves a
verifiable installation. There is no trusted range-resume state or background
transfer promise.

The injected HTTPS downloader follows at most five HTTPS redirects for the
Hugging Face CDN, rejects credential-bearing/insecure hops and non-200 responses,
requests identity bytes, and bounds connection/header/body inactivity. The file
store also bounds total transfer time to one hour. Cancellation closes HTTP,
cancels stream consumption and removes partial bytes before releasing its slot.
Failure/cancellation allows explicit retry. OS kills may leave a partial, which
is never loaded. Storage/permission failures remain actionable errors; repair
never deletes the writing database or required media.

The page distinguishes unchecked, missing, interrupted, corrupt and verified
files. Hashing runs on a worker isolate when checking Brain and immediately
before every load, including same-size replacements. No large-file hashing
runs during ordinary startup. Paths are derived from constrained catalog IDs;
model files, root links and targeted cache links are rejected. Checks assume
app-private storage, not defense against another privileged process swapping
files between validation and native open.

Removal is serialized after resource cancellation and deletes weights, partials
and only this model's known LiteRT 1.19.1 cache names in app support:
`<id>.litertlm_<numeric timestamp>_<pinned bytes>.xnnpack_cache` or
`..._mldrift_{program,weight}_cache.bin`. Unknown runtime cache formats are
retained rather than guessing which files to delete. Plugin registration
metadata may retain the old file reference; it is never used as readiness or an
active model, and explicit load registers the verified current path again.
File rename/flush does not establish directory-fsync, native disk-full or
power-loss qualification. A verified download does not prove sufficient RAM,
OS/runtime compatibility, useful quality or low-end performance.

## Requests and resource lifetime

`BrainExecutor` is a lazy scope-owned device executor using the M03
`LocalInferenceAdapter` and `openFlutterEdgeModel`. It is the current execution
boundary for future writing actions. Its caller provides a compatible descriptor,
capability, bounded text and delta callback. The Brain controller resolves the
persisted assignment; the settings page's **Test** buttons use only the visible
synthetic tree paragraph. M10 does not read writing, propose replacements or
add the floating helper.

Each explicit request revalidates files, loads CPU weights with fallback disabled,
checks the actual backend, opens a fresh session and closes the session and
weights before reporting success/releasing the request slot. Requests are
limited to 1–2,000 UTF-16 code units, 2,048 context tokens, 96 output tokens,
16,000 output code units and a 90-second cooperative deadline. Character bounds
are not a tokenizer guarantee; oversized token sequences can still fail safely.
Sampling remains temperature 0, top-k 1, top-p 1, seed 42, thinking off. Rewrite
preserves meaning, summary asks for source facts, reflection asks for a brief
gentle response. Output can be cut off or invent details; these instructions do
not establish quality/safety. No output modifies or persists writing.

Only one request runs at a time. Cancel, leaving Brain and inactive/hidden/paused
lifecycle states suppress late deltas, request native stop and wait for cleanup.
Returning to the foreground never restarts work. Cancellation/disposal while a
load is pending waits for the late model, then closes it without sending text.
A deadline cannot kill a hung native call; the slot stays occupied until it
returns. Load failure offers memory/device guidance and an explicit retry;
failed stop/session/model cleanup poisons the executor until app restart.
Cleanup failure remains observable rather than claiming successful release.
The provider holds no weights between operations. Native allocators and drivers
may retain process memory even after successful close.

## Future sources

M11 may consume assignments and the executor, but must add source revision/
selection validation, contextual lifecycle cancellation and explicit proposal
review before edits. Those behaviors are not implemented in M10. Brain's
synthetic test output is ephemeral and separate from writing.

D02 can add a versioned companion assignment source and a real authenticated
transport executor. P02 can add a provider/profile identity, supported capability
metadata, secure credential reference and a real API executor. At those phases,
extend `BrainAssignment` and migrate its source constraint, then dispatch only
to the user's explicitly selected source. Retain the same cancellation, bounded
request/delta/failure and cleanup semantics while representing remote readiness
and disconnection honestly. Device files remain owned by the local model store.
Do not silently fall back or transmit writing to another source. No speculative
companion/API adapter, transport or key field is registered now.

## Verification

Routine checks need no model, network, account or existing user database:

```sh
cd redkeep
flutter test test/features/brain test/features/ai test/core/storage test/app
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed lib test tool
```

Tests cover background assignment reopen, failed commits, schema preservation,
missing/same-size corrupt/replaced files, interrupted/invalid transfers,
redirects, cancelled stalls, storage/link errors, cache deletion isolation,
incompatible capabilities, native resource failures, deadlines, overlapping work,
load/session/disposal races, background/route cancellation, normal writing with
unavailable AI storage and narrow/large-text/keyboard/safe/theme/effects layouts.

Opt-in native harness commands extend [M03 reproduction](ai-feasibility.md).
Append `--dart-define=VERIFY_BRAIN=true` to a CPU harness build and stage the exact
artifact under `m03-verification/qwen3-06b-int8-722a0a54.litertlm` instead of its
original filename. This adds all three Brain operations and cancellation after
one delta, with per-operation close. GPU repetition uses M03's original filename
and `--dart-define=AI_BACKEND=gpu` without `VERIFY_BRAIN`. Never distribute the
alternate entry point. Restore the ordinary build afterwards without clearing
application data. A release-mode verification uses `flutter build apk --release`
with the same arguments. For an installation using the debug certificate,
re-sign a separate verification copy with the standard local Android debug key;
keep the user's release signing configuration intact. This is not production
signing acceptance. Export its report after restoring a debug
build if `run-as` is unavailable in the release build.

Implementation and available checks are finished; the tracker remains Partial for
missing hardware qualification. Exact checks, native reports, hashes and remaining hardware gaps are recorded in
[M10 evidence](evidence/m10/verification.json) and the migration phase record.
Physical iOS/Metal, Android 11/iOS 15 phones, low-end hardware, sustained thermal/
energy/peak-memory, OS memory-kill recovery and native storage-failure evidence
remain unverified. These block corresponding AI release claims. Simulator,
widget and high-end Galaxy checks cannot substitute for them. M04's production
required-artwork host prerequisite is unchanged. M11 is the next phase and
remains unstarted.
