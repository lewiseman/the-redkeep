import { useEffect, useState, type ReactNode } from "react";
import { art, BOOK_PAPERS } from "../site";
import { useReveal } from "../use-reveal";
import { Search } from "./Icons";
import TornEdge from "./TornEdge";

// One entry in the ruled index: label, illustration over an ink wash,
// heading, a line of copy and its little live demo.
function Feature({ n, label, icon, wash, title, children, demo, id }: { n: number; label: string; icon: string; wash: string; title: string; children: ReactNode; demo: ReactNode; id?: string }) {
  return (
    <article id={id} className="feature reveal">
      <div className="feature__top">
        <span className="feature__label">
          {String(n).padStart(2, "0")} · {label}
        </span>
        <span className="feature__art" style={{ "--wash": wash }}>
          <img src={art(icon)} alt="" />
        </span>
      </div>
      <h3>{title}</h3>
      <p>{children}</p>
      <div className="feature__demo">{demo}</div>
    </article>
  );
}

/* ── little live bits inside the cards ───────────────────────────────── */

const PRINTS = [
  { name: "ai", artwork: "ai.webp", r: -8, fx: "-80px", cap: "lavender", pos: "74% 30%" },
  { name: "notes", artwork: "notes.webp", r: 6, fx: "80px", cap: "a little note", pos: "76% 42%" },
  { name: "diary", artwork: "diary.webp", r: -1, fx: "0px", cap: "sunday", pos: "60% 38%" },
];

function Prints() {
  return (
    <div className="prints" aria-hidden="true">
      {PRINTS.map((p) => (
        <figure key={p.name} style={{ "--r": `${p.r}deg`, "--fx": p.fx }}>
          <div style={{ backgroundImage: `url(${art(p.artwork)})`, backgroundPosition: p.pos }} />
          <figcaption>{p.cap}</figcaption>
        </figure>
      ))}
    </div>
  );
}

const ASKS = [
  "When did I last feel this calm?",
  "What did I promise Mum in June?",
  "Which books did I love this year?",
  "Why was last Tuesday so good?",
];

function Ask() {
  const [i, setI] = useState(0);
  const [shown, setShown] = useState("");
  useEffect(() => {
    const full = ASKS[i];
    let n = 0;
    let hold = 0;
    const t = setInterval(() => {
      if (n <= full.length) setShown(full.slice(0, n++));
      else if (++hold > 40) {
        clearInterval(t);
        setI((v) => (v + 1) % ASKS.length);
      }
    }, 45);
    return () => clearInterval(t);
  }, [i]);
  return (
    <div className="ask" aria-hidden="true">
      <Search />
      <span>
        {shown}
        <span className="demo__caret" />
      </span>
    </div>
  );
}

function ScanDemo() {
  return (
    <div className="scan" aria-hidden="true">
      <div className="scan__page">
        <p className="hand">buy flowers for maya</p>
        <p className="hand">call the plumber (tues)</p>
        <p className="hand">start the novel</p>
        <i className="scan__beam" />
      </div>
      <div className="scan__text">
        <p>Buy flowers for Maya</p>
        <p>Call the plumber (Tues)</p>
        <p>Start the novel</p>
      </div>
    </div>
  );
}

const THOUGHTS = ["what if the café opened earlier?", "call Sam back", "the light at 6pm, again", "a book about rivers"];

function Drift() {
  return (
    <div className="drift" aria-hidden="true">
      {THOUGHTS.map((t, i) => (
        <span key={t} className="hand" style={{ animationDelay: `${i * -2.2}s`, "--x": `${[6, 38, 14, 44][i]}%` }}>
          {t}
        </span>
      ))}
    </div>
  );
}

function Wave() {
  return (
    <div className="wave" aria-hidden="true">
      {Array.from({ length: 34 }, (_, i) => (
        <i
          key={i}
          style={{
            "--h": `${30 + Math.abs(Math.sin(i * 1.7)) * 70}%`,
            animationDelay: `${-i * 0.07}s`,
            backgroundPosition: `${(i / 34) * 100}% 0`,
          }}
        />
      ))}
    </div>
  );
}

const ACCENTS = [
  ["Indigo", "#161658"],
  ["Plum", "#6b3fa0"],
  ["Sage", "#6f8a68"],
  ["Rose", "#c0606f"],
  ["Amber", "#c98a2c"],
];

function Appearance() {
  const [dark, setDark] = useState(false);
  const [accent, setAccent] = useState(ACCENTS[0][1]);
  return (
    <>
      <div className="swatches" role="group" aria-label="Accent colour">
        {ACCENTS.map(([n, c]) => (
          <button key={n} aria-label={n} aria-pressed={accent === c} style={{ "--c": c }} onClick={() => setAccent(c)} />
        ))}
        <button
          className="ml-auto !w-auto rounded-full !border-0 px-3 text-xs font-extrabold"
          style={{ "--c": dark ? "#f4ead4" : "#17151d", color: dark ? "#17151d" : "#f4ead4" }}
          onClick={() => setDark((d) => !d)}
        >
          {dark ? "Light" : "Dark"}
        </button>
      </div>
      <div
        className="theme-demo"
        style={{ "--td-bg": dark ? "#17151d" : "#faf8fc", "--td-fg": dark ? "#f4ead4" : "#2a1b2f", "--accent": dark && accent === "#161658" ? "#8f8fff" : accent }}
      >
        <img src={art(dark ? "theme_dark.png" : "theme_light.png")} alt="" />
        <div className="flex-1">
          <b>Thursday, 29 October</b>
          <span>Today felt like sunshine.</span>
          <div className="bar" />
        </div>
      </div>
    </>
  );
}

/* ── section ─────────────────────────────────────────────────────────── */

export default function Features() {
  const root = useReveal();
  const [notes, diary, maester, flow, appearance] = BOOK_PAPERS;
  return (
    <section id="features" ref={root} className="section section--paper">
      <div className="wrap"><h2 className="sr-only">In the current mobile build</h2>
        <div className="features">
          <Feature id="feature-diary" n={1} label="Diary" icon="diary.png" wash="#d98a7a" title={diary.title} demo={<Prints />}>{diary.text}</Feature>
          <Feature id="feature-notes" n={2} label="Notes" icon="notes.png" wash="#8c9b81" title={notes.title} demo={<ScanDemo />}>{notes.text}</Feature>
          <Feature id="feature-maester" n={3} label="Grand Maester" icon="j.png" wash="#a796bd" title={maester.title} demo={<Ask />}>{maester.text}</Feature>
          <Feature id="feature-flow" n={4} label="Flow" icon="flow.png" wash="#a796bd" title={flow.title} demo={<Drift />}>{flow.text}</Feature>
          <Feature n={5} label="Your words" icon="more.png" wash="#cfaa62" title="A little space for you." demo={<Wave />}>Writing lives on your device. Notes, Diary and Flow keep recovery drafts for unfinished writing, and saving commits your changes locally.</Feature>
          <Feature id="feature-appearance" n={6} label="Appearance" icon="theme_light.png" wash="#8c9b81" title={appearance.title} demo={<Appearance />}>{appearance.text}</Feature>
        </div>
      </div><TornEdge />
    </section>
  );
}
