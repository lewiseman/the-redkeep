import { useEffect } from 'react';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import NavBar from './components/NavBar';
import Hero from './components/Hero';
import Book from './components/Book';
import Screens from './components/Screens';
import Features from './components/Features';
import Footer from './components/Footer';
import { CoverNameProvider } from './cover-name';
export default function App() {
  useEffect(() => { const refresh = () => ScrollTrigger.refresh(); window.addEventListener('load', refresh); document.fonts.ready.then(refresh); return () => window.removeEventListener('load', refresh); }, []);
  return <CoverNameProvider><div className="site"><a className="skip-link" href="#features">Skip to product information</a><NavBar /><main><Hero /><Book /><Screens /><Features /></main><Footer /></div></CoverNameProvider>;
}
