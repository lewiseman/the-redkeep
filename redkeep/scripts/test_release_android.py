"""Offline checks for publishing boundaries and Android artifact validation."""
import hashlib
from pathlib import Path
import tempfile
import unittest
import zipfile
from unittest.mock import patch

import release_android as release


class FakeGitHub:
    def __init__(self, existing=None, fail_upload=False, wrong_digest=False, tag_lookup_missing=False):
        self.existing = existing
        self.fail_upload = fail_upload
        self.wrong_digest = wrong_digest
        self.tag_lookup_missing = tag_lookup_missing
        self.events = []

    def api(self, method, endpoint, data=None, **kwargs):
        self.events.append((method, endpoint, data))
        if endpoint == "commits/sha":
            return {"sha": "sha"}
        if endpoint.startswith("releases/tags/"):
            return None if self.tag_lookup_missing else self.existing
        if endpoint.startswith("releases?per_page="):
            return [self.existing] if self.existing else []
        if endpoint.startswith("git/ref/tags/"):
            return None
        if method == "POST":
            return {"id": 12}
        if endpoint == "releases/12/assets?per_page=100":
            return []
        if method == "PATCH":
            return {"id": 12, "html_url": "https://github.com/lewiseman/the-redkeep/releases/tag/v0.1.0+2"}
        if endpoint == "releases/latest":
            return {"id": 12, "assets": [{"name": event[1]} for event in self.events if event[0] == "UPLOAD"]}
        raise AssertionError((method, endpoint))

    def upload(self, release_id, file):
        self.events.append(("UPLOAD", file.name, None))
        if self.fail_upload:
            raise release.ReleaseError("Upload interrupted")
        return {"size": file.stat().st_size, "state": "uploaded",
                "digest": "sha256:wrong" if self.wrong_digest else "sha256:" + hashlib.sha256(file.read_bytes()).hexdigest()}


class ReleaseTests(unittest.TestCase):
    def test_versions(self):
        self.assertEqual(release.parse_version("0.1.2+13"), ("0.1.2", 13))
        for value in ("1.2.3", "1.2.3+0", "1.2.3+-1", "v1.2.3+1", "01.2.3+1",
                      "1.2.3+2100000001", "1.2.3+1; echo unsafe", "1.2.3+1\n"):
            with self.subTest(value=value), self.assertRaises(release.ReleaseError):
                release.parse_version(value)

    def test_apk_metadata_and_hash(self):
        signature = "Signer #1 certificate SHA-256 digest: abc123\n"
        badging = ("package: name='com.lewiseman.redkeep' versionCode='2' versionName='0.1.0'\n"
                   "sdkVersion:'30'\nnative-code: 'arm64-v8a'\n")
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "redkeep-arm64-v8a.apk"
            with zipfile.ZipFile(apk, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                archive.writestr("lib/arm64-v8a/libfixture.so", b"native library fixture" * 50)
            with patch.object(release, "run", side_effect=[signature, badging]):
                info = release.inspect_apk(apk, Path(directory), "0.1.0", 2)
            self.assertEqual(info["sha256"], hashlib.sha256(apk.read_bytes()).hexdigest())
            self.assertEqual(info["architectures"], ["arm64-v8a"])
            self.assertEqual(info["minSdk"], 30)
            self.assertTrue(info["nativeLibraryCompression"])
            self.assertEqual(info["sizeBytes"], apk.stat().st_size)
            for invalid in (badging.replace("versionCode='2'", "versionCode='1'"),
                            badging.replace("com.lewiseman.redkeep", "com.other.app"),
                            badging.replace("'arm64-v8a'", "'arm64-v8a' 'x86_64'"),
                            badging.replace("sdkVersion:'30'", "sdkVersion:'29'")):
                with self.subTest(badging=invalid), patch.object(release, "run", side_effect=[signature, invalid]):
                    with self.assertRaises(release.ReleaseError):
                        release.inspect_apk(apk, Path(directory), "0.1.0", 2)
            with zipfile.ZipFile(apk, "w", compression=zipfile.ZIP_STORED) as archive:
                archive.writestr("lib/arm64-v8a/libfixture.so", b"uncompressed native library")
            with patch.object(release, "run", side_effect=[signature, badging]):
                self.assertFalse(release.inspect_apk(apk, Path(directory), "0.1.0", 2)["nativeLibraryCompression"])

    def test_debug_key_is_rejected(self):
        with patch.object(release, "run", return_value="Signer #1 certificate DN: CN=Android Debug, O=Android"):
            with self.assertRaisesRegex(release.ReleaseError, "debug key"):
                release.inspect_apk(Path("unused.apk"), Path("tools"), "0.1.0", 2)

    def test_published_releases_are_never_replaced(self):
        client = FakeGitHub(existing={"draft": False})
        with self.assertRaisesRegex(release.ReleaseError, "already published"):
            release.publish(client, "v0.1.0+2", [], "notes", "sha")
        self.assertEqual(len(client.events), 2)

    def test_wrong_draft_source_is_rejected(self):
        client = FakeGitHub(existing={"draft": True, "target_commitish": "other"})
        with self.assertRaisesRegex(release.ReleaseError, "different commit"):
            release.publish(client, "v0.1.0+2", [], "notes", "sha")
        self.assertEqual(len(client.events), 2)

    def test_existing_tag_must_match_the_release_commit(self):
        client = FakeGitHub()
        with patch.object(client, "api", side_effect=[{"sha": "sha"}, None, [],
                                                      {"object": {"type": "commit", "sha": "other"}}]):
            with self.assertRaisesRegex(release.ReleaseError, "different commit"):
                release.publish(client, "v0.1.0+2", [], "notes", "sha")

    def test_publish_only_after_every_upload_completes(self):
        with tempfile.TemporaryDirectory() as directory:
            files = [Path(directory) / name for name in ("redkeep-arm64-v8a.apk", "redkeep-arm64-v8a.apk.sha256", "release.json")]
            for file in files:
                file.write_text("fixture")
            client = FakeGitHub()
            with patch("builtins.print"):
                release.publish(client, "v0.1.0+2", files, "notes", "sha")
            actions = [event[0] for event in client.events]
            created = next(event for event in client.events if event[0] == "POST")
            self.assertTrue(created[2]["draft"])
            self.assertEqual(created[2]["target_commitish"], "sha")
            self.assertEqual(actions.count("UPLOAD"), 3)
            self.assertLess(max(i for i, a in enumerate(actions) if a == "UPLOAD"), actions.index("PATCH"))
            self.assertFalse(client.events[actions.index("PATCH")][2]["draft"])
            interrupted = FakeGitHub(fail_upload=True)
            with self.assertRaisesRegex(release.ReleaseError, "interrupted"):
                release.publish(interrupted, "v0.1.0+2", files, "notes", "sha")
            self.assertNotIn("PATCH", [event[0] for event in interrupted.events])

    def test_incomplete_or_corrupt_upload_stays_draft(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / release.APK_NAME
            file.write_bytes(b"APK fixture")
            client = FakeGitHub(wrong_digest=True)
            with self.assertRaisesRegex(release.ReleaseError, "digest differs"):
                release.publish(client, "v1.0.0+1", [file], "notes", "sha")
            self.assertNotIn("PATCH", [event[0] for event in client.events])
            client = FakeGitHub()
            with patch.object(client, "upload", return_value={"size": 1, "state": "uploaded"}):
                with self.assertRaisesRegex(release.ReleaseError, "complete upload"):
                    release.publish(client, "v1.0.0+1", [file], "notes", "sha")
            self.assertNotIn("PATCH", [event[0] for event in client.events])

    def test_draft_without_a_published_tag_is_reused(self):
        draft = {"id": 12, "tag_name": "v1.0.0+1", "draft": True, "target_commitish": "sha"}
        client = FakeGitHub(existing=draft, tag_lookup_missing=True)
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / release.APK_NAME
            file.write_bytes(b"APK fixture")
            with patch("builtins.print"):
                release.publish(client, "v1.0.0+1", [file], "notes", "sha")
        self.assertNotIn("POST", [event[0] for event in client.events])
        self.assertIn(("UPLOAD", release.APK_NAME, None), client.events)

    def test_duplicate_drafts_are_not_modified(self):
        client = FakeGitHub()
        with patch.object(client, "api", side_effect=[None, [{"tag_name": "v1.0.0+1"}] * 2]):
            with self.assertRaisesRegex(release.ReleaseError, "Multiple releases"):
                release.find_release(client, "v1.0.0+1")


if __name__ == "__main__":
    unittest.main()
