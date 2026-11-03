import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve, relative } from 'node:path';
const html = await readFile('dist/index.html', 'utf8');
assert(html.includes('Every day') && html.includes('Notes'));
for (const text of ['Redkeep', 'Skip to product information', 'Privacy policy', 'Grand Maester', 'Original Journal screenshots']) assert(html.includes(text), `Missing prerendered content: ${text}`);
assert(!/href=["'][^"']*(?:download|releases)/i.test(html), 'No empty or legacy download URLs');
assert(!/qvac|googleapis|gstatic|<textarea/i.test(html), 'No retired branding, remote fonts or writing app');
assert((html.match(/<input\b/g) ?? []).length === 1 && html.includes('aria-label="Write your name on the cover"'), 'Only the decorative cover-name input is rendered');
assert(html.includes('disabled=""'), 'Download remains disabled');
for (const page of ['index', 'privacy', 'terms']) {
  const text = await readFile(`dist/${page}.html`, 'utf8');
  assert(/<html lang="en"/.test(text));
  assert(/<title>[^<]*Redkeep|<title>Redkeep/.test(text));
  assert(text.includes('name="description"'));
  for (const match of text.matchAll(/(?:src|href)="(\/[^"#?]*)"/g)) {
    const path = match[1];
    if (path === '/') continue;
    assert((await stat(resolve('dist', path.slice(1)))).isFile(), `Missing local asset: ${path}`);
  }
}
// Preserve the selected mascot and original screenshots without duplicate image files.
const preservedArtwork = {
  'art/j.png': '5e698de4f5ab0413e36094c45ee16a67e11bcbc7408a9a7fb558c391a9be10e5',
  'shots/ask.jpg': 'ace3521748c92539363bfbc39efa64b0f5f46df8ba07bf59061f3aa3e6eee7b1',
  'shots/diary.jpg': '323c7290c4f74bf35f6d6619b62f6b253c730a25e71b57c154524fccac2c629c',
  'shots/flow.jpg': '419390b329164e9b706fa0d1100d79122464903f1d04df6b8a1b8b21b4a80d0e',
  'shots/note-tools.jpg': '920bd6539e4dcc7ef8fbf538172a3f1e1ba186f71f05ec767b81f08bf6ebbf56',
  'shots/photo-story.jpg': '355178cabae23a3e104e1248555abe3814c0f1d83212c7a9da5eaadf6453c1c9',
  'shots/talk.jpg': '23634c5bca50117325970ad3083c05bdd1e32cb9a66499d0e5a35e393d0dfdb2',
};
async function* filesUnder(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const path = `${dir}/${entry.name}`;
    if (entry.isDirectory()) yield* filesUnder(path);
    else {
      assert(entry.isFile(), `Expected a regular static file: ${path}`);
      yield path;
    }
  }
}
const publicPaths = new Set();
for await (const source of filesUnder('public')) {
  const path = relative('public', source);
  const content = await readFile(source);
  assert(content.equals(await readFile(resolve('dist', path))), `Published file must match its public source: ${path}`);
  publicPaths.add(path);
}
let bytes = 0;
for await (const path of filesUnder('dist')) {
  bytes += (await stat(path)).size;
  if (/\.(jpe?g|png|webp|ttf)$/.test(path)) assert(publicPaths.has(relative('dist', path)), `Missing public source: ${path}`);
}
// Includes the four user-added shared app images (327,851 bytes).
assert(bytes < 7_500_000, `Static site exceeds reviewed 7.5 MB budget: ${bytes}`);
for (const [path, hash] of Object.entries(preservedArtwork)) {
  const data = await readFile(resolve('public', path));
  assert.equal(createHash('sha256').update(data).digest('hex'), hash, `Selected artwork changed: ${path}`);
}
assert.equal((await readdir('public/shots')).length, 6, 'Keep the six selected screenshots');
console.log(`Build integrity, static content, metadata, public source copies, selected mascot, six unchanged screenshots and disabled downloads passed (${bytes.toLocaleString('en')} bytes).`);
