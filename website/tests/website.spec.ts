import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { mkdir, writeFile } from 'node:fs/promises';
const evidence = 'test-results/evidence';
test.beforeEach(async ({ page }) => {
  await page.route('**/*', route => new URL(route.request().url()).hostname === '127.0.0.1' ? route.continue() : route.abort());
});
test('initial content, local resources, disabled downloads and metadata', async ({ page }) => {
  const errors: string[] = []; const external: string[] = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('request', r => { if (new URL(r.url()).hostname !== '127.0.0.1') external.push(r.url()); });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await expect(page.locator('.pin-spacer')).toHaveCount(2);
  await expect(page.getByRole('button', {name:'Simpler view'})).toHaveCount(0);
  await expect(page).toHaveTitle('Redkeep · A little space for your days');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Every daydeserves a page.');
  await expect(page.getByRole('button', { name: 'Download', exact: true }).first()).toBeDisabled();
  await expect(page.locator('.nav__actions small, .download-state')).toHaveCount(0);
  await expect(page.locator('a[href*="download"], a[href*="releases"], input:not(.cover-name), textarea')).toHaveCount(0);
  await expect(page.locator('.gallery-note')).toContainText('Original Journal screenshots');
  await expect(page.locator('.book__controls')).toHaveCount(0);
  await expect(page.locator('meta[name="description"]')).toHaveAttribute('content', /Redkeep/);
  expect(await page.locator('img').evaluateAll(imgs => imgs.filter(i => i instanceof HTMLImageElement && i.complete && i.naturalWidth === 0).map(i => (i as HTMLImageElement).src))).toEqual([]);
  expect(errors).toEqual([]); expect(external).toEqual([]);
  await mkdir(evidence, { recursive: true }); await expect.poll(() => page.locator('.mascot img').evaluate(el => getComputedStyle(el).opacity)).toBe('1'); await page.screenshot({ path: `${evidence}/desktop-hero.png` });
  const resources = await page.evaluate(() => performance.getEntriesByType('resource').map(e => { const r = e as PerformanceResourceTiming; return { path:new URL(r.name).pathname, encodedBytes:r.encodedBodySize }; }));
  await writeFile(`${evidence}/initial-resources.json`, JSON.stringify({resources, encodedBytes:resources.reduce((sum, r) => sum + r.encodedBytes, 0)}, null, 2) + '\n');
});
test('keyboard skips animation and reaches readable product content', async ({ page }) => {
  await page.goto('/'); await page.keyboard.press('Tab');
  await expect(page.getByRole('link', { name: 'Skip to product information' })).toBeFocused();
  await page.keyboard.press('Enter'); await expect(page).toHaveURL(/#features$/);
  await expect(page.getByRole('heading', { name: 'Catch a thought.' })).toBeInViewport();
  await page.getByRole('link', {name:'Redkeep, back to top', exact:true}).click();
  await expect.poll(() => page.evaluate(() => scrollY)).toBe(0);
});
test('book controls, rail and arrow keys navigate every chapter', async ({ page }) => {
  await page.goto('/');
  const chapter = page.getByRole('region', { name: 'Current chapter description', exact: true });
  await chapter.scrollIntoViewIfNeeded(); await chapter.press('ArrowLeft');
  await expect.poll(() => page.locator('.book__caption .caption-in').evaluate(el => getComputedStyle(el).filter)).toMatch(/^(none|blur\(0px\))$/);
  await page.screenshot({ path: `${evidence}/castle-cover-desktop.png` });
  await chapter.press('ArrowRight');
  await expect(page.locator('.book__caption h3')).toHaveText('Five chapters. One quiet place.');
  await chapter.press('ArrowRight'); await expect(page.locator('.book__caption h3')).toHaveText('Catch a thought.');
  await page.getByRole('navigation', { name: 'Jump to a chapter' }).getByRole('button', { name: 'Flow', exact: true }).click();
  await expect(page.locator('.book__caption h3')).toHaveText('Let your thoughts flow.');
  await page.getByRole('button', { name: 'Your words', exact: true }).click();
  await expect(page.locator('.book__caption .eyebrow')).toHaveText('Your words');
  await expect(page.getByRole('group', { name: 'Turn the book pages' })).toHaveCount(0);
  await page.screenshot({ path: `${evidence}/desktop-book.png` });
});
test('gallery retains six originals and supports manual navigation', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Next screen' }).click();
  await expect(page.locator('.inside__caption h3')).toHaveText('Memories, on paper.');
  await page.locator('.inside__stage').press('ArrowRight');
  await expect(page.locator('.inside__caption h3')).toHaveText('Catch loose thoughts.');
  await page.getByRole('button', { name: 'Notes', exact: true }).last().click();
  await expect(page.locator('.inside__caption p')).toContainText('does not include every tool');
  expect(await page.locator('.phone img').count()).toBe(6);
});
for (const viewport of [{ width: 390, height: 844 }, { width: 320, height: 568 }, { width: 844, height: 390 }]) {
  test(`touch layout ${viewport.width}x${viewport.height}`, async ({ browser }) => {
    const context = await browser.newContext({ viewport, hasTouch: true, isMobile: true }); const page = await context.newPage();
    await page.route('**/*', route => new URL(route.request().url()).hostname === '127.0.0.1' ? route.continue() : route.abort());
    await page.goto('/'); await page.getByRole('button', { name: 'Say hello to the Redkeep mascot' }).tap();
    await expect(page.locator('.bubble')).toHaveText('A little space for your days.');
    await page.locator('#book').scrollIntoViewIfNeeded();
    await page.getByRole('region', { name: 'Current chapter description', exact: true }).press('ArrowLeft');
    if (viewport.width === 390) {
      const name = page.getByRole('textbox', { name: 'Write your name on the cover' });
      await name.tap(); await name.pressSequentially('Mira'); await expect(name).toHaveValue('Mira');
      await expect.poll(() => page.locator('.book__caption .caption-in').evaluate(el => getComputedStyle(el).filter)).toMatch(/^(none|blur\(0px\))$/);
      await page.screenshot({ path: `${evidence}/castle-cover-mobile.png` });
    }
    await page.getByRole('region', { name: 'Current chapter description', exact: true }).press('ArrowRight');
    await expect(page.locator('.book__caption h3')).toHaveText('Five chapters. One quiet place.');
    await page.getByRole('button', { name: 'Next screen' }).tap();
    await expect(page.locator('.inside__caption h3')).toHaveText('Memories, on paper.');
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
    await page.goto('/'); await expect.poll(() => page.locator('.mascot img').evaluate(el => getComputedStyle(el).opacity)).toBe('1'); await page.screenshot({ path: `${evidence}/touch-${viewport.width}.png` }); await context.close();
  });
}
test('320px with 300% root text keeps reading and controls in flow', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 568 }); await page.goto('/');
  await page.addStyleTag({ content: 'html { font-size: 300% !important; }' });
  // Exercise remeasurement at the enlarged text size.
  await page.setViewportSize({ width: 321, height: 568 }); await page.setViewportSize({ width: 320, height: 568 });
  await page.locator('#book').scrollIntoViewIfNeeded();
  await page.getByRole('region', { name: 'Current chapter description', exact: true }).click();
  await expect(page.locator('.book__caption p')).toBeVisible();
  await page.locator('#features').scrollIntoViewIfNeeded();
  const overflow = await page.evaluate(() => ({ width:innerWidth, scroll:document.documentElement.scrollWidth, items:[...document.querySelectorAll('body *')].filter(el=>el.getBoundingClientRect().right > innerWidth+1).map(el=>({tag:el.tagName,cls:el.className,right:el.getBoundingClientRect().right})) }));
  expect(overflow, JSON.stringify(overflow)).toMatchObject({ scroll: 320 });
  await page.screenshot({ path: `${evidence}/large-text.png` });
});
for (const path of ['/', '/privacy.html', '/terms.html']) test(`accessibility ${path}`, async ({ page }) => {
  await page.goto(path);
  const result = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
  expect(result.violations).toEqual([]);
});
test('production content is readable without JavaScript', async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false, viewport: { width: 390, height: 844 } }); const page = await context.newPage();
  await page.goto('/'); await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await page.getByRole('link', { name: 'Skip to product information' }).focus(); await page.keyboard.press('Enter');
  await expect(page.getByRole('heading', { name: 'Catch a thought.' })).toBeInViewport();
  await page.getByRole('link', { name: 'Privacy policy' }).click(); await expect(page.getByRole('heading', { level: 1 })).toHaveText('Your journal is yours.');
  await page.screenshot({ path: `${evidence}/no-javascript-policy.png` }); await context.close();
});

test('cover name edits, caret keys, personalization and reload persistence', async ({ page }) => {
  await page.goto('/');
  const chapter = page.getByRole('region', { name: 'Current chapter description', exact: true });
  const name = page.getByRole('textbox', { name: 'Write your name on the cover' });
  await chapter.press('ArrowLeft');
  await name.fill('Mira');
  await name.press('ArrowLeft'); await name.press('x');
  await expect(name).toHaveValue('Mirxa');
  await expect(page.locator('.book__caption .eyebrow')).toHaveText('Cover');
  await name.fill(''); await name.pressSequentially('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
  await expect(name).toHaveValue('ABCDEFGHIJKLMNOPQRSTUVWX');
  await name.fill('Mira');
  expect(await page.evaluate(() => localStorage.getItem('redkeep-cover-name'))).toBe('Mira');
  await expect(page.locator('.sunbook .cover-name')).toHaveText('Mira');
  await chapter.press('ArrowRight');
  await expect(page.locator('[data-page="cover"] .page__half--back')).toContainText('This journal belongs toMira');
  await page.getByRole('button', { name: 'Your words', exact: true }).click();
  await expect(page.locator('[data-page="end"] h3')).toContainText('first page, Mira.');
  await page.getByRole('navigation', { name: 'Jump to a chapter' }).getByRole('button', { name: 'Cover', exact: true }).click();
  await page.reload(); await chapter.press('ArrowLeft');
  await expect(name).toHaveValue('Mira');
  await expect.poll(() => page.locator('.book__caption .caption-in').evaluate(el => getComputedStyle(el).filter)).toMatch(/^(none|blur\(0px\))$/);
  await page.screenshot({ path: `${evidence}/editable-name.png` });
});

test('existing Journal cover names are retained, and clearing does not revive them', async ({ page }) => {
  await page.addInitScript(() => { if (localStorage.getItem('journal-owner') === null) localStorage.setItem('journal-owner', 'Avery'); });
  await page.goto('/');
  const name = page.getByRole('textbox', { name: 'Write your name on the cover' });
  await page.getByRole('region', { name: 'Current chapter description', exact: true }).press('ArrowLeft');
  await expect(name).toHaveValue('Avery');
  await name.fill(''); await page.reload();
  await expect(name).toHaveValue('');
});

test('blocked storage keeps the cover name editable for this visit', async ({ page }) => {
  await page.addInitScript(() => {
    for (const method of ['getItem', 'setItem']) Object.defineProperty(Storage.prototype, method, { value() { throw new DOMException('Storage blocked in isolated test', 'SecurityError'); } });
  });
  const errors: string[] = []; page.on('pageerror', e => errors.push(e.message));
  await page.goto('/');
  await page.getByRole('region', { name: 'Current chapter description', exact: true }).press('ArrowLeft');
  const name = page.getByRole('textbox', { name: 'Write your name on the cover' });
  await name.fill('Mira'); await expect(name).toHaveValue('Mira');
  await expect(page.locator('.sunbook .cover-name')).toHaveText('Mira');
  await page.reload(); await expect(name).toHaveValue('');
  expect(errors).toEqual([]);
});

test('legacy gallery fans in and autoplays until keyboard interaction', async ({ page }) => {
  await page.goto('/'); await page.mouse.move(0, 0);
  await page.locator('#inside').scrollIntoViewIfNeeded();
  await expect(page.locator('.inside__caption h3')).not.toHaveText('A page for every day.', { timeout: 7000 });
  const stage = page.getByRole('group', { name: 'App screens, use the arrow keys to browse' });
  await stage.press('ArrowRight');
  const selected = await page.locator('.inside__caption h3').innerText();
  await page.waitForTimeout(5100);
  await expect(page.locator('.inside__caption h3')).toHaveText(selected);
  await page.screenshot({ path: `${evidence}/restored-gallery.png` });
});

test('legacy feature animations and interactive theme preview are restored', async ({ page }) => {
  await page.goto('/'); await page.locator('#features').scrollIntoViewIfNeeded();
  for (const [selector, animation] of [['.scan__beam', 'beam'], ['.scan__text p', 'typein'], ['.drift span', 'drift'], ['.wave i', 'wave'], ['.demo__caret', 'caret']]) {
    expect(await page.locator(selector).first().evaluate(el => getComputedStyle(el).animationName)).toBe(animation);
  }
  await expect(page.locator('.ask')).not.toHaveText('');
  const appearance = page.locator('#feature-appearance');
  await appearance.getByRole('button', { name: 'Sage', exact: true }).click();
  await expect(appearance.getByRole('button', { name: 'Sage', exact: true })).toHaveAttribute('aria-pressed', 'true');
  await appearance.getByRole('button', { name: 'Dark', exact: true }).click();
  await expect.poll(() => appearance.locator('.theme-demo').evaluate(el => getComputedStyle(el).backgroundColor)).toBe('rgb(23, 21, 29)');
  await expect(appearance.getByRole('button', { name: 'Light', exact: true })).toBeVisible();
  await page.screenshot({ path: `${evidence}/restored-feature-animations.png` });
});
