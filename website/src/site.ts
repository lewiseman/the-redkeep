export const LINKS = { github: 'https://github.com/lewiseman/the-redkeep' };
export const art = (name: string) => `/art/${name}`;
export const BOOK_PAPERS = [
  { id: 'notes', label: 'Notes', artwork: 'notes.webp', title: 'Catch a thought.', text: 'Write plain-text notes, organize with tags and pins, search by keyword, and preview Markdown. Deleted notes go to Trash.', scene: 'Illustrated paper note cards.' },
  { id: 'diary', label: 'Diary', artwork: 'diary.webp', title: 'Keep the moments.', text: 'Keep dated text entries, browse your calendar and find entries with local keyword search. Unfinished writing has recovery drafts.', scene: 'An illustrated sunny diary page and a cup of coffee.' },
  { id: 'maester', label: 'Grand Maester', artwork: 'ai.webp', title: 'Find your next thought.', text: 'Optional on-device writing assistance after a compatible model is installed. Review suggestions before keeping them. Device qualification is still in progress.', scene: 'Illustrated paper writing prompts.' },
  { id: 'flow', label: 'Flow', artwork: 'flow.jpg', title: 'Let your thoughts flow.', text: 'Capture passing thoughts, revisit them, edit or delete them. Writing is stored locally, with recovery for unfinished drafts.', scene: 'Illustrated floating thought cards.' },
  { id: 'appearance', label: 'Appearance', artwork: 'appearance.jpg', title: 'Make it yours.', text: 'Choose light, dark or system appearance, reduce motion and use simpler effects. Writing stays readable on small screens and with larger text.', scene: 'Illustrated paper swatches and sun and moon cards.' },
];
export const CHAPTERS = [
  { id: 'cover', label: 'Cover', title: "A journal that's yours alone.", text: 'Write your name on the cover. Your cover name stays in this browser. Then scroll to explore the app.' },
  { id: 'contents', label: 'Contents', title: 'Five chapters. One quiet place.', text: 'Notes, Diary, Grand Maester, Flow and Appearance. The artwork is decorative; the descriptions explain the current mobile build.' },
  ...BOOK_PAPERS,
  { id: 'writing', label: 'Your words', title: 'A little space for you.', text: 'Keep your days, ideas and passing thoughts together. Redkeep is in development; downloads are not available yet.' },
];
