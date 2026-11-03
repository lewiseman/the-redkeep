import type { ReactNode } from 'react';
import { CoverFront, CoverInside, Contents, Leaf, MoreBack, EndFront } from './BookFaces';
import { BOOK_PAPERS } from '../site';
export interface BookPage { id: string; type?: 'cover-front' | 'cover-back'; front: ReactNode; back: ReactNode }
export const PAGES: BookPage[] = [
  { id: 'cover', type: 'cover-front', front: <CoverFront />, back: <CoverInside /> },
  { id: 'contents', front: <Contents />, back: <Leaf paper={BOOK_PAPERS[0]} side="L" /> },
  ...BOOK_PAPERS.map((paper, i) => ({ id: paper.id, front: <Leaf paper={paper} side="R" />, back: BOOK_PAPERS[i + 1] ? <Leaf paper={BOOK_PAPERS[i + 1]} side="L" /> : <MoreBack /> })),
  { id: 'end', type: 'cover-back', front: <EndFront />, back: null },
];
