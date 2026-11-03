# M03 local inference qualification

M03 is **Partial**. The application-owned adapter and synthetic harness are
implemented; physical Galaxy S24 Ultra CPU/GPU and iOS simulator CPU runs pass.
Physical iOS inference, Android 11/iOS 15 hardware, low-end phones, sustained release
performance and production signing remain unverified. M10 adds short Galaxy release-mode CPU evidence without closing those gaps. These gaps block corresponding AI release
claims. Independent M04 work can proceed. This guide retains M03 qualification evidence; [M10 Brain](brain.md) now consumes the adapter.

## Ownership and recovery

`features/ai/domain/local_inference.dart` defines plugin-free model/session
boundaries and safe failure categories. `LocalInferenceAdapter` accepts an
injected, explicitly loaded model and owns its lifetime. M03 introduced no global app service or AI provider. M10 now composes a lazy
Brain executor for explicit requests; normal startup and writing remain
independent of model files and plugin initialization.

`openFlutterEdgeModel` is the only plugin integration. On explicit invocation it
registers `LiteRtLmEngine(backendFallback: false)`, registers a local file with
`ModelType.qwen3` and `ModelFileType.litertlm`, and opens `installation.spec`
without activating the package's global active model. The package internally
uses a process registry and stores file-registration metadata; that registry
is contained at this boundary. No application database is accessed. File
installation registers the existing path without copying its weights. This
spike accepts one verified local file; model download/install UI and durable
application model assignments are now implemented in [M10](brain.md).

Each request uses a fresh session, keeping prompt/history separate while sharing
weights. Only one request may be outstanding. Requests are single-subscription
streams with a `done` future and `failure` result. Callers must listen, cancel,
or close; abandoning a live subscription is not cancellation. Both explicit
cancel and subscription cancellation call native `stopGeneration`, suppress late
chunks, wait for session cleanup, and then release the slot. Cancellation during
session creation waits for the created resource and closes it without sending
the prompt. Closing an adapter also cancels an unobserved/active request and
waits before releasing the model. Close is terminal and idempotent.

Native errors become safe load/generation/cancellation/cleanup failures; raw
paths/prompts are not returned by this adapter. Ordinary generation failures
allow retry in a new session. Failed stop/session cleanup poisons the adapter:
close it and explicitly load a new instance. A model close failure remains
observable on repeated close. This does not recover from process termination,
OS memory kills, or a hung native API. M10 adds lifecycle/background cancellation and bounded resources through Brain.
Source revision checks and proposal review remain M11 work.

## Qualified versions and native setup

Checked on 2 November 2026 against current package documentation, pub.dev package
metadata, and the downloaded published source:

| Component | Pinned/resolved version and constraint |
| --- | --- |
| Flutter / Dart | 3.47.5 / 3.13.4 locally; packages require Flutter ≥3.44, Dart ≥3.12 <4 |
| `flutter_edge_ai` | Exactly 2.5.5; archive SHA-256 `e768469f5bc6e59e40e9cc172327d2cbca9abf6b23cb4b154b7deebac1ff6c57` |
| `flutter_edge_ai_litertlm` | Exactly 1.19.1; requires core ^2.5.5; archive SHA-256 `85bce0526a5d21bd6ddb7be452f6cf1df07c99f68187331023dab9157becf5d2` |
| Native library | `native-v0.18.0-h`, LiteRT-LM 0.18.0; SHA-verified build-hook archives |
| Hashing | `crypto` ^3.0.6, lock resolves 3.0.8; consumed by artifact verification |
| Android | App minimum API 30 (Android 11); ARM64 only. `abiFilters.clear()` followed by `arm64-v8a`; final APK inspection confirms API 30 and only ARM64 |
| iOS | Existing Runner target remains 15.0; Swift Package Manager and Native Assets work without a Podfile. Simulator uses CPU; physical device Metal remains unverified |

Native archive SHA-256 values from the pinned engine hook:

- Android ARM64: `d7ed14f761905cfe50bc06e3693e9abf934a96584c869410a78dfaef26080e62`
- iOS ARM64: `5d673601ef4691da74adee13e09230969399f41f7983aab9e305014663faaed1`
- iOS simulator ARM64: `739ca01a86b369b6542dba29c7003d6a51374c356032cce8aa2633001365e3f5`

The engine package supplies native libraries through its build hook. Core's
Android manifest merges optional OpenCL/vendor library declarations; no manual
JNI, JavaScript, Gradle inference runtime, or ProGuard additions are needed.
No NPU flags/runtimes or other engine/vector/API packages were added. Existing
AGP 9.1.0/Kotlin 2.4.0/Java 17 target settings are preserved. No file-sharing,
local-network permission, or large-model entitlement was added for the private
local-file harness. Release model downloads are outside this spike; a later
downloader must handle its own network permission and storage lifecycle.

The app lockfile includes the package's transitive download/shared-preference
dependencies. These do not replace the appearance Drift database. Fresh package
and native-library acquisition needs network access; cached routine tests run
fake models without model files, private data, accounts, or service calls.

## Artifact and settings

The machine-readable pin is `redkeep/tool/ai/qwen3-0.6b.json`. It identifies the
ungated `litert-community/Qwen3-0.6B` **Qwen3-0.6B.litertlm** artifact:

- Repository revision: `722a0a54c1301a4b07a9856a9590d56362f0969b`.
- SHA-256: `c5f39b4191926786c3e6668b62af4d6eb15248dfc7a5348252a9b406f33f2108`.
- Size: **613,722,264 bytes** (585.29 MiB); dynamic INT8 weights, float KV,
  bundled Qwen3 tokenizer/template, advertised 4096-token context.
- License: **Apache-2.0**, as declared by the artifact card and linked upstream
  Qwen license. No weights or production writing are bundled or committed.
- Harness: 2048 context tokens, 96 output tokens, temperature 0, top-k 1, top-p 1,
  seed 42, thinking off, no vision/audio/tools; system instruction is
  `Follow the instruction. Answer briefly.` Activation type uses bundle/runtime
  defaults. Backend is explicit CPU or GPU; fallback is disabled and actual
  backend is checked. The package's first-generation sampler remains consistent
  for every session sharing a model.

The selected artifact includes the October tokenizer repair. The newer dynamic
INT4 artifact under a different filename needs LiteRT-LM 0.19 for its Android
GPU path and is not the qualified artifact here. Do not substitute a file just
because its model name matches.

## Reproduction (explicit opt-in only)

From `redkeep/`, use Python 3.9+ to fetch the immutable public URL and verify its
size/hash before atomic rename. An existing target is verified without network:

```sh
python3 tool/ai/download_model.py /tmp/redkeep-m03-model
flutter test test/features/ai
flutter devices
```

For Android, select a real ARM64 device (substitute its ID). Build/install the
alternate entry point, stage the model in its private harness directory, then
launch. This uses the existing debug app identity and preserves its data; never
use this alternate entry point for a distributed build.

```sh
flutter build apk --debug --target-platform android-arm64 -t tool/verify_ai.dart --dart-define-from-file=tool/ai/qwen3-0.6b.json
adb -s <android-id> install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s <android-id> shell run-as com.lewiseman.redkeep mkdir -p files/m03-verification
adb -s <android-id> exec-in run-as com.lewiseman.redkeep sh -c 'cat > files/m03-verification/Qwen3-0.6B.litertlm' < /tmp/redkeep-m03-model/Qwen3-0.6B.litertlm
adb -s <android-id> shell am force-stop com.lewiseman.redkeep
adb -s <android-id> shell am start -n com.lewiseman.redkeep/.MainActivity
adb -s <android-id> exec-out run-as com.lewiseman.redkeep cat files/m03-verification/report-cpu.json
```

Repeat the build/install/launch with `--dart-define=AI_BACKEND=gpu` appended to
the build command; read `report-gpu.json`. The same staged artifact is reused.
Do not change the device's private writing or clear application data.

For an installed/booted ARM64 iOS simulator:

```sh
flutter build ios --simulator --debug -t tool/verify_ai.dart --dart-define-from-file=tool/ai/qwen3-0.6b.json
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
M03_CONTAINER="$(xcrun simctl get_app_container booted com.lewiseman.redkeep data)"
mkdir -p "$M03_CONTAINER/Library/Application Support/m03-verification"
cp /tmp/redkeep-m03-model/Qwen3-0.6B.litertlm "$M03_CONTAINER/Library/Application Support/m03-verification/"
xcrun simctl launch --terminate-running-process booted com.lewiseman.redkeep
cat "$M03_CONTAINER/Library/Application Support/m03-verification/report-cpu.json"
```

Re-query the container after reinstalling; its UUID can change. Physical iOS
needs available hardware, signing, private model staging, and a fresh run on the
device. An unsigned `flutter build ios --no-codesign --debug` checks packaging
only. Optional `MODEL_PATH` can point to an already staged private file; model
identity still comes from `--dart-define-from-file` and hash verification.

The harness records integrity, missing/corrupt loads, streaming, cancellation
after the first non-empty chunk, reuse, repeated requests, close, reload, and
inference after reload. It saves progress and a final JSON report under app
support `m03-verification/`. Require `completed: true` and all cases passing;
an `inProgress` entry without completion is interrupted/hung evidence. A 90s
generation deadline requests cancellation; it cannot forcibly kill hung native
code. Timings are local Stopwatch durations and chunk counts are not token/s.
Keyword quality checks are advisory and do not decide functional pass/fail.

Restore the ordinary app with the README's default-target build/install. Remove
only the staged model and its specifically identified Qwen cache files after
exporting reports. Never delete the primary database or clear app storage to
repair a verification run.

## Evidence and limits

Raw synthetic reports: [Android CPU](evidence/m03/android-s24-ultra-cpu.json),
[Android GPU](evidence/m03/android-s24-ultra-gpu.json), and
[iOS simulator CPU](evidence/m03/ios-simulator-cpu.json). Hardware/tooling,
exact commands, timings, checks, and gaps are recorded in the M03 migration
phase record. All runs are debug, short, and performed on devices already in
use; timing variation/cache state is not controlled. OS-floor declarations and
successful newer-OS builds are not tests on those minimum OS releases.

Arithmetic returned `17 + 25 = 42`, despite asking for just the result. Emoji
copying and the tiny tree summary worked in these runs. This is a feasibility
sample, not evidence for reliable rewriting, factuality, safety, long-context
quality, sustained latency, energy, or low-memory behavior. No OOM/thermal test
was performed. Native logs confirm conversation/engine deletion, but one
post-cleanup Android CPU process sample still reported roughly 1.24 GiB PSS;
successful close does not prove prompt return of all allocator/cache memory.
No physical iOS/Metal or minimum-OS/low-end release claim is authorized by this
evidence.

## Official references checked

- [Core 2.5.5](https://pub.dev/packages/flutter_edge_ai/versions/2.5.5) and
  [engine 1.19.1](https://pub.dev/packages/flutter_edge_ai_litertlm/versions/1.19.1).
- [Installation/platform setup](https://flutteredge.ai/docs/installation) and
  [LiteRT-LM APIs, context/output limits, and fallback](https://flutteredge.ai/docs/litertlm).
- [Google LiteRT-LM](https://developers.google.com/edge/litert-lm).
- [Pinned artifact card](https://huggingface.co/litert-community/Qwen3-0.6B/blob/722a0a54c1301a4b07a9856a9590d56362f0969b/README.md)
  and [upstream Qwen license](https://huggingface.co/Qwen/Qwen3-0.6B/blob/main/LICENSE).
- [Flutter ABI filtering](https://docs.flutter.dev/release/breaking-changes/default-abi-filters-android).
