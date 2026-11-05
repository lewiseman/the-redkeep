# Android releases

Redkeep's first release is **1.0.0+1**. The app source and APK releases live in
the public `lewiseman/the-redkeep` repository. The permanent download URL is:

<https://github.com/lewiseman/the-redkeep/releases/latest/download/redkeep-arm64-v8a.apk>

Every release contains `redkeep-arm64-v8a.apk`, `redkeep-arm64-v8a.apk.sha256`,
and `release.json`. Keep the APK filename for future releases so website links
continue to work. Supported phones run **Android 11+ (API 30) on ARM64**;
the current on-device AI runtime does not support ARM32 or x86_64.

## Local prerequisites

- Flutter matching the committed `pubspec.lock`, Python 3.9+, Git, and the Android
  SDK with Build Tools (`aapt` and `apksigner`). Configure `ANDROID_HOME` or
  `sdk.dir` in ignored `android/local.properties`.
- A JDK. On macOS the script uses Android Studio's bundled JDK when `JAVA_HOME`
  is unset; otherwise configure `JAVA_HOME` and `PATH`.
- The ignored `env.json` with the production HTTPS `ASSET_BASE_URL` and configured
  `GOOGLE_SERVER_CLIENT_ID`. Artwork continues through the existing catalog,
  download, verification, and local storage flow; model weights download separately.
- The existing ignored `android/key.properties` with `storeFile`, `storePassword`,
  `keyAlias`, and `keyPassword`. Relative keystore paths resolve from `android/app/`.
  Keep a private backup of the keystore and passwords, and use the same signing
  key for every update. Do not commit credentials or change native configuration.
- Google OAuth configured for `com.lewiseman.redkeep` and the release certificate's
  SHA-1. Verify Google sign-in and Drive sync on a phone using the release APK.
- For publication, GitHub authentication through `GH_TOKEN` / `GITHUB_TOKEN`,
  `gh auth login`, or the Git credential helper. A fine-grained token needs
  **Contents: read and write** for `lewiseman/the-redkeep`. Installing `gh` is optional.

## Prepare and verify

From `redkeep/`:

```sh
python3 -m unittest discover -s scripts -p 'test_release_android.py'
python3 scripts/release_android.py
```

The release tests are offline. The script resolves locked Flutter dependencies,
builds a signed ARM64 APK using `env.json`, and verifies its signature,
package ID, actual Android version code, minimum SDK, architecture, and SHA-256.
It rejects Android debug signing keys. Native library packaging stays as configured.
The existing Gradle configuration already restricts the APK to ARM64. The script
does not add conflicting ABI splits, so build `1` is Android version code `1`.

Output goes to ignored `build/releases/v1.0.0+1/`, including generated release notes.
The script also refreshes `../website/src/release.json` with the verified APK's
version, size, checksum, certificate, and source commit. Build-only mode accepts
local app changes and marks `sourceDirty: true`; those builds cannot be published
without committing the source and rebuilding.

## Publish and update the website

1. Commit the app source and release tooling, and push that exact commit to GitHub.
   The app subtree must be clean; generated website metadata can be committed
   separately after publication.
2. From `redkeep/`, publish the release:

   ```sh
   python3 scripts/release_android.py --publish
   ```

   The script checks that the exact source commit exists on GitHub, builds and
   verifies the APK, creates a draft tagged `v1.0.0+1` at that commit, uploads all
   three artifacts, then publishes it as latest. Interrupted uploads leave a draft;
   rerunning can replace that draft's artifacts. Published releases and tags are
   never overwritten. Custom notes use `--notes-file /absolute/path/notes.md`.
3. Review and commit `website/src/release.json` and the download links. From
   `website/`, run:

   ```sh
   npm run build
   npm test -- --grep 'release downloads|readable without JavaScript'
   ```

4. Deploy through the website's existing Vercel project after the APK is available.
   The landing page links directly to the APK; the footer links to release notes
   and installation instructions. The stable URLs need no changes on later releases.

For later updates, increase the build number in `pubspec.yaml`, for example
`1.0.1+2`, and repeat. The build number must exceed the latest release's number;
the certificate must match so users can update without losing their local writing.

## Install

Download the APK and open it on a supported phone. If Android prompts, allow the
browser or file manager to install apps. Future updates should be installed over
Redkeep; do not uninstall first. A development APK signed with another certificate
cannot be updated with the release APK.

To check the downloaded APK, place its checksum alongside it and run:

```sh
shasum -a 256 -c redkeep-arm64-v8a.apk.sha256
```

The first launch downloads and verifies the required artwork. Automated checks
verify packaging and release behavior; installation, OAuth, Drive sync, and device
AI still need a release-device smoke test.

References: [Flutter Android distribution](https://docs.flutter.dev/deployment/android),
[GitHub Releases API](https://docs.github.com/en/rest/releases/releases),
[permanent release links](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases).
