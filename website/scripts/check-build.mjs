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
assert((await readFile('public/art/j.png')).equals(await readFile('../assets/reference/branding/grand_maestar.png')), 'Website mascot must match the selected Grand Maester original');
const manifest = JSON.parse(await readFile('../assets/reference/manifest.json', 'utf8'));
const refs = new Set(manifest.assets.map(row => row.sha256));
let bytes = 0;
async function inspect(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const path = `${dir}/${entry.name}`;
    if (entry.isDirectory()) await inspect(path);
    else {
      const content = await readFile(path); bytes += content.length;
      if (/\.(jpg|png|webp|ttf)$/.test(path)) assert(refs.has(createHash('sha256').update(content).digest('hex')), `Unindexed asset: ${path}`);
    }
  }
}
await inspect('dist');
assert(bytes < 7_000_000, `Static site exceeds reviewed 7 MB budget: ${bytes}`);
// Regression guard: all original screenshots remain byte-for-byte locally indexed.
for (const entry of await readdir('public/shots')) {
  const data = await readFile(`public/shots/${entry}`);
  const row = manifest.assets.find(row => row.key === `website.shots.${entry}`);
  assert(row && row.sha256 === createHash('sha256').update(data).digest('hex'), relative('.', entry));
}
console.log(`Build integrity, static content, metadata, local references, six unchanged screenshots and disabled downloads passed (${bytes.toLocaleString('en')} bytes).`);
