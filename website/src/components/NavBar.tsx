import { useEffect, useState } from 'react';
import { LINKS } from '../site';
import { DownloadButton } from './Buttons';
import { GitHub } from './Icons';
export default function NavBar() {
  const [solid, setSolid] = useState(false);
  useEffect(() => { const update = () => setSolid(window.scrollY > 30); update(); window.addEventListener('scroll', update, { passive: true }); return () => window.removeEventListener('scroll', update); }, []);
  return <header className={`nav ${solid ? 'nav--solid' : ''}`}><div className="nav__bar">
    <a href="#hero" onClick={e => { e.preventDefault(); window.scrollTo({ top: 0, behavior: 'instant' }); }} className="nav__brand wordmark" aria-label="Redkeep, back to top">Redkeep</a>
    <nav className="nav__actions" aria-label="Main navigation">

      <a className="nav__icon" href={LINKS.github} aria-label="Redkeep source on GitHub"><GitHub /></a>
      <DownloadButton />
    </nav>
  </div></header>;
}
