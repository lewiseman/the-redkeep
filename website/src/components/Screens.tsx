import { useEffect, useRef, useState } from "react";
import { useReveal } from "../use-reveal";


/* ───────────────────────────────────────────────────────────────────────
   Screens: real screens from the app, in a coverflow of phones.
   The images are rendered by the app's own widget tests (sample content,
   no status bar), see README. Click a phone, drag or swipe, or use the
   arrow keys. The original entrance fan and 4.8-second autoplay stop when interacted with.
─────────────────────────────────────────────────────────────────────── */

const SHOTS = [
  { src: 'diary.jpg', label: 'Diary', title: 'A page for every day.', text: 'Original Journal diary screenshot, retained as a visual reference.' },
  { src: 'photo-story.jpg', label: 'Photo stories', title: 'Memories, on paper.', text: 'Original Journal photo-story screenshot. Photo stories are outside the current Redkeep scope.' },
  { src: 'flow.jpg', label: 'Flow', title: 'Catch loose thoughts.', text: 'Original Journal Flow screenshot, retained as a visual reference.' },
  { src: 'note-tools.jpg', label: 'Notes', title: 'Room for your ideas.', text: 'Original Journal tools screenshot. Redkeep does not include every tool pictured here.' },
  { src: 'talk.jpg', label: 'Voice', title: 'The familiar notebook.', text: 'Original Journal voice screenshot. Voice and desktop pairing are outside the current Redkeep scope.' },
  { src: 'ask.jpg', label: 'Search', title: 'A thought, rediscovered.', text: 'Original Journal search screenshot. Redkeep currently uses keyword search, without semantic search.' },
];

const N = SHOTS.length;
const AUTOPLAY_MS = 4800;


// Shortest signed distance from the front phone, so the ring wraps around.
const offsetOf = (i: number, active: number) => ((i - active + N + Math.floor(N / 2)) % N) - Math.floor(N / 2);

function pose(o: number, fanned: boolean) {
  if (!fanned) {
    // stacked in a neat pile before the section scrolls in
    return { transform: `translateX(0) translateZ(${-Math.abs(o) * 30}px) rotateZ(${o * 2.5}deg) scale(0.9)`, opacity: Math.abs(o) > 2 ? 0 : 1 };
  }
  const a = Math.abs(o);
  return {
    transform: `translateX(calc(${o} * var(--spread))) translateZ(${-a * 140}px) rotateY(${-o * 24}deg) scale(${1 - Math.min(a, 3) * 0.1})`,
    opacity: a >= 3 ? 0 : 1,
  };
}

export default function Screens() {
  const root = useReveal();
  // the front phone, and the one before it (to spot phones wrapping round)
  const [{ active, last }, setPos] = useState({ active: 0, last: 0 });
  const [fanned, setFanned] = useState(false);
  const [auto, setAuto] = useState(true);

  const [drag, setDrag] = useState(0);
  const start = useRef<number | null>(null);
  const moved = useRef(0); // live drag distance, read on release

  const go = (d: number) => setPos((p) => ({ active: (p.active + d + N) % N, last: p.active }));
  const pick = (i: number) => {
    setAuto(false);
    setPos((p) => ({ active: i, last: p.active }));
  };

  // Original stacked entrance, then fan out as the section comes into view.
  useEffect(() => {
    const io = new IntersectionObserver(([entry]) => entry.isIntersecting && setFanned(true), { threshold: 0.35 });
    if (root.current) io.observe(root.current);
    return () => io.disconnect();
  }, [root]);
  useEffect(() => {
    if (!auto || !fanned) return;
    const timer = setInterval(() => go(1), AUTOPLAY_MS);
    return () => clearInterval(timer);
  }, [auto, fanned]);

  const onDown = (e: React.PointerEvent<HTMLDivElement>) => {
    start.current = e.clientX;
    moved.current = 0;
  };
  const onMove = (e: React.PointerEvent<HTMLDivElement>) => {
    if (start.current === null) return;
    moved.current = e.clientX - start.current;
    setDrag(moved.current);
  };
  const onUp = () => {
    if (start.current === null) return;
    if (Math.abs(moved.current) > 40) {
      setAuto(false);
      go(moved.current < 0 ? 1 : -1);
    }
    start.current = null;
    setDrag(0);
  };

  const onKey = (e: React.KeyboardEvent<HTMLDivElement>) => {
    if (e.key === "ArrowRight") {
      e.preventDefault();
      setAuto(false);
      go(1);
    } else if (e.key === "ArrowLeft") {
      e.preventDefault();
      setAuto(false);
      go(-1);
    }
  };

  const s = SHOTS[active];

  return (
    <section id="inside" ref={root} className="section section--paper" aria-label="Legacy Journal screenshot gallery">
      <div className="wrap">
        <h2 className="inside__eyebrow reveal">Inside the app</h2><p className="gallery-note">Original Journal screenshots · visual references, not current Redkeep screens.</p>

        <div
          className="inside__stage"
          style={{ "--drag": `${drag * 0.5}px` }}
          onPointerDown={onDown}
          onPointerMove={onMove}
          onPointerUp={onUp}
          onPointerCancel={onUp}
          onPointerLeave={onUp}
          onKeyDown={onKey}
          onMouseEnter={() => setAuto(false)}
          onFocus={() => setAuto(false)}

          tabIndex={0}
          role="group"
          aria-roledescription="carousel"
          aria-label="App screens, use the arrow keys to browse"
        >
          {SHOTS.map((shot, i) => {
            const o = offsetOf(i, active);
            // a phone wrapping round the back of the ring jumps instead of flying across
            const jumped = Math.abs(o - offsetOf(i, last)) > N / 2 - 0.5;
            return (
              <button
                key={shot.src}
                className={`phone ${o === 0 ? "phone--front" : ""}`}
                style={{
                  ...pose(o, fanned),
                  zIndex: 10 - Math.abs(o),
                  transition: jumped ? "none" : undefined,
                  transitionDelay: fanned && !jumped ? `${Math.abs(o) * 40}ms` : undefined,
                }}
                onClick={() => o !== 0 && Math.abs(moved.current) < 5 && pick(i)}
                tabIndex={-1}
                aria-hidden={true}
                aria-label={`Show ${shot.label}`}
              >
                <span className="phone__screen">
                  <img src={`/shots/${shot.src}`} alt={o === 0 ? `${shot.label}, original Journal screenshot` : ""} loading="lazy" draggable="false" />
                </span>
              </button>
            );
          })}
        </div>

        <div className="inside__caption" aria-live="polite">
          <div key={s.src} className="caption-in">
            <h3 className="display">{s.title}</h3>
            <p>{s.text}</p>
          </div>
        </div>

        <div className="inside__tabs" role="group" aria-label="Choose a screen">
          <button className="inside__arrow" onClick={() => { setAuto(false); go(-1); }} aria-label="Previous screen">
            ←
          </button>
          {SHOTS.map((shot, i) => (
            <button key={shot.src} aria-pressed={i === active} onClick={() => pick(i)}>
              {shot.label}
            </button>
          ))}
          <button className="inside__arrow" onClick={() => { setAuto(false); go(1); }} aria-label="Next screen">
            →
          </button>
        </div>
      </div>
    </section>
  );
}
