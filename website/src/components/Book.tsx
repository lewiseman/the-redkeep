import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { PAGES } from './BookPages';
import { CHAPTERS } from '../site';
import { scrollTo } from '../scroll';
gsap.registerPlugin(ScrollTrigger);
const OPEN = 1;
const chapterAt = (t: number) => t < OPEN + 0.5 ? 0 : Math.min(CHAPTERS.length - 1, Math.floor(t - OPEN + 0.5));
export default function Book() {
  const root = useRef<HTMLElement>(null);
  const trigger = useRef<ScrollTrigger | null>(null);
  const [chapter, setChapter] = useState(0);
  useLayoutEffect(() => {
    const ctx = gsap.context(() => {
      const els = gsap.utils.toArray<HTMLElement>('.book__page');
      const master = gsap.timeline({ paused: true, defaults: { ease: 'none' } });
      master.fromTo('.book', { scale: 0.62, rotateZ: -4 }, { scale: 1, rotateZ: 0, duration: OPEN, ease: 'power2.out' }, 0);
      els.forEach((el, i) => {
        const restZ = i === 0 ? 13 : -i;
        gsap.set(el, { z: restZ });
        if (i === els.length - 1) return;
        const flip = gsap.timeline({ defaults: { ease: 'none' } })
          .fromTo(el, { rotateY: 0 }, { rotateY: -(180 - i / 2), duration: 1, ease: 'power1.inOut' }, 0)
          .fromTo(el, { z: restZ }, { z: i === 0 ? -13 : i, duration: 0.5 }, 0)
          .fromTo(el.querySelector('.page__half--front .page__light'), { opacity: 0 }, { opacity: 1, duration: 0.5 }, 0)
          .fromTo(el.querySelector('.page__half--back .page__light'), { opacity: 0.9 }, { opacity: 0, duration: 0.5 }, 0.5);
        if (i === 0) flip.fromTo('.book', { xPercent: 0 }, { xPercent: 50, duration: 1, ease: 'power1.inOut' }, 0);
        master.add(flip, OPEN + i);
      });
      master.to({}, { duration: 0.8 });
      let current = 0;
      master.eventCallback('onUpdate', () => { const c = chapterAt(master.time()); if (c !== current) setChapter(current = c); });
      trigger.current = ScrollTrigger.create({ animation: master, trigger: root.current, start: 'top top', end: () => `+=${master.duration() * window.innerHeight * 0.75}`, pin: true, scrub: true, invalidateOnRefresh: true });
    }, root);
    return () => { ctx.revert(); trigger.current = null; };
  }, []);
  const goto = (i: number) => {
    const next = Math.max(0, Math.min(CHAPTERS.length - 1, i));
    const st = trigger.current;
    if (!st?.animation) { setChapter(next); return; }
    const time = next === 0 ? OPEN * 0.85 : OPEN + next;
    scrollTo(st.start + time / st.animation.duration() * (st.end - st.start) + 2, { immediate: true });
  };
  useEffect(() => {
    const go = (e: Event) => { const i: unknown = (e as CustomEvent).detail; if (typeof i === 'number' && Number.isFinite(i)) goto(i); };
    window.addEventListener('book:goto', go);
    return () => window.removeEventListener('book:goto', go);
  });
  const c = CHAPTERS[chapter];
  return <section id="book" ref={root} aria-label="A tour of Redkeep, as a book" onKeyDown={e => {
    if (e.target instanceof HTMLInputElement) return;
    if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') { e.preventDefault(); goto(chapter + (e.key === 'ArrowRight' ? 1 : -1)); }
  }}>
    <h2 className="sr-only">Explore Redkeep</h2>
    <div className="book-stage"><div className="book-tilt"><div className="book"><div className="book__shadow" /><div className="book__spine" />
      {PAGES.map((def, i) => <div key={def.id} className={`page book__page ${def.type ? `book__cover book__cover--${def.type === 'cover-front' ? 'front' : 'back'}` : ''}`} data-page={def.id} style={{ '--page-index': i + 1 }}>
        <div className="page__half page__half--front" inert={chapter !== i} aria-hidden={chapter !== i}><div className="page__content">{def.front}</div><span className="page__light" /></div>
        <div className="page__half page__half--back" inert={chapter !== i + 1} aria-hidden={chapter !== i + 1}><div className="page__content">{def.back}</div><span className="page__light" /></div>
      </div>)}
    </div></div></div>
    <div className="book__caption" tabIndex={0} role="region" aria-label="Current chapter description" aria-live="polite"><div key={c.id} className="caption-in"><span className="eyebrow">{c.label}</span><h3 className="display">{c.title}</h3><p>{c.text}</p></div></div>
    <nav className="book__rail" aria-label="Jump to a chapter">{CHAPTERS.map((ch, i) => <button key={ch.id} aria-current={i === chapter} onClick={() => goto(i)}>{ch.label}</button>)}</nav>
  </section>;
}
