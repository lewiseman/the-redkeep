import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';

const KEY = 'redkeep-cover-name';
const LEGACY_KEY = 'journal-owner';
const CoverNameContext = createContext<{ name: string; setName: (value: string) => void } | null>(null);

// Each rendered site owns its state. Storage is accessed only in the browser,
// so static rendering never contains a visitor's name or shares mutable state.
export function CoverNameProvider({ children }: { children: ReactNode }) {
  const [name, setCurrentName] = useState('');
  useEffect(() => {
    try {
      setCurrentName((localStorage.getItem(KEY) ?? localStorage.getItem(LEGACY_KEY) ?? '').slice(0, 24));
    } catch {
      // Blocked storage still allows editing for this page visit.
    }
  }, []);
  const setName = (value: string) => {
    const next = value.slice(0, 24);
    setCurrentName(next);
    try { localStorage.setItem(KEY, next); } catch { /* Keep the in-memory name. */ }
  };
  return <CoverNameContext value={{ name, setName }}>{children}</CoverNameContext>;
}

export function useCoverName() {
  const value = useContext(CoverNameContext);
  if (!value) throw new Error('Cover name requires the site provider.');
  return value;
}
