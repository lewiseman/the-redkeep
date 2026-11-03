import type { ReactNode } from 'react';
import { art, BOOK_PAPERS } from '../site';
import { useCoverName } from '../cover-name';
const Sheet = ({ className = '', children }: { className?: string; children: ReactNode }) => <div className={`page__inner ${className}`}>{children}</div>;
export function CoverArt() { return <div className="cover-art" role="img" aria-label="The Redkeep: lavender linen cover with a gold castle emblem" />; }
export function CoverFront() {
  const { name, setName } = useCoverName();
  return <><CoverArt /><input className="cover-name" value={name} onChange={e => setName(e.target.value)} placeholder="write your name" aria-label="Write your name on the cover" maxLength={24} spellCheck={false} autoComplete="off" /></>;
}
export function CoverInside() {
  const { name } = useCoverName();
  return <Sheet className="items-center justify-center gap-[3cqw] text-center"><p className="font-serif text-[3cqw] uppercase tracking-[0.4em] opacity-60">Ex libris</p><img src={art('j.png')} alt="" className="w-[34cqw]" /><p className="font-serif text-[4.2cqw] opacity-75">This journal belongs to</p><p className="hand -mt-[1cqw] min-h-[12cqw] text-[11cqw] leading-none text-[#4b2f4f]">{name || 'you'}</p><span className="h-px w-[40%] bg-[#2a1b2f]/25" /><p className="max-w-[78%] text-[3.4cqw] leading-snug opacity-60">Your cover name stays in this browser. Keep scrolling to explore the app.</p></Sheet>;
}
export const Contents = () => <Sheet><p className="font-serif text-[3cqw] uppercase tracking-[0.35em]">Redkeep</p><h3 className="display text-[11cqw] my-[3cqw]">Contents</h3><nav className="toc" aria-label="Book chapters">{BOOK_PAPERS.map((paper, i) => <a key={paper.id} href={`#feature-${paper.id}`} onClick={e => { e.preventDefault(); window.dispatchEvent(new CustomEvent('book:goto', { detail: i + 2 })); }}><span><em>0{i + 1}</em>{paper.label}</span><b>{i * 2 + 1}</b></a>)}</nav><p className="hand mt-auto text-[6cqw]">a place for you</p></Sheet>;
export const Leaf = ({ paper, side }: { paper: typeof BOOK_PAPERS[number]; side: 'L' | 'R' }) => <div className={`leaf leaf--${side}`} style={{ backgroundImage: `url(${art(paper.artwork)})` }} aria-hidden="true"><span className={`leaf-brand leaf-brand--${side}`}>{side === 'R' ? `REDKEEP / ${paper.label.toUpperCase()}` : 'REDKEEP'}</span></div>;
export const MoreBack = () => <Sheet className="justify-center gap-[4cqw]"><p className="font-serif text-[3cqw] uppercase">Your words, on your device</p><h3 className="display text-[9cqw]">Room to<br />write.</h3><p className="text-[4cqw] leading-relaxed">Notes, Diary and Flow keep writing locally. Optional assistance starts only after model setup.</p><p className="text-[3.5cqw] leading-relaxed">This website is a product tour. It does not store journal entries.</p></Sheet>;
export function EndFront() {
  const { name } = useCoverName();
  return <Sheet className="items-center justify-center gap-[4cqw] text-center"><img src={art('j.png')} alt="" className="w-[30cqw]" /><h3 className="display text-[9cqw]">Start your<br />first page{name ? `, ${name}` : ''}.</h3><p className="text-[4cqw]">Public downloads are not available yet.</p><button className="book-download text-[4cqw]" disabled>Download</button></Sheet>;
}
