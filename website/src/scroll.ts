// Native scrolling preserves touch, keyboard and browser anchor behavior.
export function scrollTo(target: number | string, { immediate = false } = {}) {
  const top = typeof target === 'number' ? target : (document.querySelector(target)?.getBoundingClientRect().top ?? 0) + window.scrollY;
  window.scrollTo({ top, behavior: immediate ? 'instant' : 'smooth' });
}
