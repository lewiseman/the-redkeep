"""Opt-in public artifact fetch; never part of pub get, tests, or startup."""
import hashlib
import json
from pathlib import Path
import sys
import urllib.request

metadata = json.loads(Path(__file__).with_name('qwen3-0.6b.json').read_text())
destination = Path(sys.argv[1]).expanduser().resolve()
destination.mkdir(parents=True, exist_ok=True)
target = destination / metadata['MODEL_FILENAME']
url = (f"https://huggingface.co/{metadata['MODEL_REPOSITORY']}/resolve/"
       f"{metadata['MODEL_REVISION']}/{metadata['MODEL_FILENAME']}")
partial = target.with_suffix('.partial')
try:
    if not target.exists():
        urllib.request.urlretrieve(url, partial)
        candidate = partial
    else:
        candidate = target
    hasher = hashlib.sha256()
    with candidate.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            hasher.update(chunk)
    digest = hasher.hexdigest()
    if (candidate.stat().st_size != int(metadata['MODEL_BYTES']) or
            digest != metadata['MODEL_SHA256']):
        raise ValueError('Artifact size/SHA-256 mismatch; do not run it.')
    if candidate == partial:
        partial.replace(target)
    print(json.dumps({'path': str(target), 'bytes': target.stat().st_size,
                      'sha256': digest, 'revision': metadata['MODEL_REVISION']}))
finally:
    partial.unlink(missing_ok=True)
