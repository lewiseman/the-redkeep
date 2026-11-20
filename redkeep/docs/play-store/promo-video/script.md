# The Redkeep — promo video script

Target length: about 3:00. One narrator, one music bed, short sound effects.

Formats: a 16:9 master (1920×1080, phone framed beside graphics, for the Play Store
YouTube promo) and a 9:16 cut (1080×1920, phone filling the frame, for Reels/Shorts/TikTok).
Both use the same audio.
Every feature appears once, in the order a new user meets it.

## What to generate in ElevenLabs

### Voiceover settings (same for every line)

- **Voice:** one warm, calm, unhurried narrator. Test VO-01 on 2–3 library voices first, then keep one.
- **Model:** Eleven Multilingual v2 (most consistent tone across separate lines).
- **Settings:** Stability ~50, Similarity ~75, Style 0–15, Speed ~0.95.
- **Output:** MP3 44.1 kHz 192 kbps (or WAV if your plan allows).
- **One file per line**, named by its ID: `VO-01.mp3`, `VO-02.mp3` … Don't stitch them; I time each line to the picture.
- If a line comes out rushed, add a comma or `...` where you want the pause and regenerate just that line.

### Voiceover lines

| ID | Scene | Line |
|---|---|---|
| VO-01 | Cold open | Some days deserve to be remembered. Some thoughts deserve a place to land. |
| VO-02 | Title | This is The Redkeep. |
| VO-03 | Onboarding | It opens like a book. Turn the pages, put your name on the cover... and if you've been here before, your journal comes straight back. |
| VO-04 | Diary day reader | Your diary hangs on a little cord of days. Swipe through them, by sunlight, or by starlight. |
| VO-05 | Moods | Every day gets a feeling. Pick one, or any emoji you like. |
| VO-06 | Writing an entry | Then write. Ruled paper, a gentle prompt, and room for as much or as little as you want. In a hurry? Save it as a quick thought. |
| VO-07 | Photo stories | Turn your photos into stories. Pin the prints, caption every moment, and put them in any order you like. |
| VO-08 | Raven memories | And when an old day echoes today, a raven arrives with a letter. A year ago. A month ago. Last week. |
| VO-09 | Calendar zoom | Pinch the calendar to travel through time. Days, weeks, months, a whole year, each with its own page to write. |
| VO-10 | Diary search | Forgot when it happened? Just ask. A few words can bring a day back. |
| VO-11 | Notes collection | Notes are for everything else. Colourful paper, pinned to the top, gathered by tags. |
| VO-12 | Note editor | Headings, checklists and files are a tap away, and you can tick things off without ever opening the editor. |
| VO-13 | Note backgrounds | Give each note a colour, a piece of artwork, or a photo from anywhere in the world. |
| VO-14 | Voice dictation | Or don't type at all. Just speak, then review your words. |
| VO-15 | Maester intro | And when you need a hand... meet the Maester. |
| VO-16 | Title and tag ideas | Stuck on a title? It suggests one. Not sure how to tag it? It finds the right tags for you. |
| VO-17 | Ask the Maester | Or just ask, in your own words. Add a photo or a file, and watch it write straight into your note. |
| VO-19 | Maester settings | Bring your own AI. Any OpenAI-compatible service, a model for each skill, and your key never leaves your phone. |
| VO-20 | Watchlist wall | When the writing's done, there's your watchlist. Every film and series, on one wall. |
| VO-21 | Explore by mood | Find something by mood. Cozy night in. Make me laugh. Mind-bending. |
| VO-22 | Title page, stamps, episodes, lists | Open any title, stamp it planned, watching or watched, track every episode, and sort it into your own lists. |
| VO-23 | Pick for me | Can't choose? Your companion will pick one for you. |
| VO-24 | Appearance | Make it yours. Light or dark, six accent colours, and the fonts you love, with calmer motion whenever you need it. |
| VO-25 | Home screen widgets | Keep it on your home screen too. Your month of moods at a glance, and a fresh page, one tap away. |
| VO-26 | Backup | Everything lives on your phone, and works offline. It backs up to your own Google Drive while you sleep. |
| VO-27 | Closing | The Redkeep. A quiet place for your notes, your days, and the thoughts in between. |
| VO-28 | Signature | Made with love, by Lewis. |

About 2,400 characters in total.

### Sound effects

Generate each with the duration shown (set it manually, don't leave it on auto). Name files by ID.
Ask for 1–2 variations at most; I only need the best one.

| ID | Duration | Prompt | Used for |
|---|---|---|---|
| SFX-01 | 1.5 s | A single page of a thick paper book turning, close and soft, quiet room | Onboarding pages, chapter changes |
| SFX-02 | 1.0 s | Soft airy paper whoosh, gentle swipe transition | Scene transitions |
| SFX-03 | 2.0 s | Fountain pen writing on textured paper, a few quick strokes | Writing an entry, name on cover |
| SFX-04 | 0.5 s | Soft muted wooden tap, subtle UI click | Mood pick, buttons |
| SFX-05 | 1.0 s | Polaroid photo placed on paper, then a piece of tape pressed down | Photo stories |
| SFX-06 | 2.0 s | A raven landing on a rope with a soft wing flutter, one quiet distant caw | Raven memories |
| SFX-07 | 2.5 s | Gentle magical shimmer with soft chimes rising, warm and calm, not sci-fi | Maester writing |
| SFX-08 | 0.7 s | Rubber stamp pressed firmly onto paper, satisfying thunk | Watchlist status stamps |
| SFX-09 | 2.0 s | Vintage film projector reel spinning up, clicking, then stopping | "Pick for me" spin |
| SFX-10 | 0.5 s | Pencil ticking a checkbox on paper, short scratch | Checklists |
| SFX-11 | 3.0 s | Quiet night ambience, soft crickets, a light breeze | Dark mode, starlight diary |
| SFX-12 | 1.5 s | Heavy leather-bound book closing gently, soft thud | Backup tome |
| SFX-13 | 1.5 s | Soft warm chime, single sparkle, gentle success | Backup done, AI result accepted |
| SFX-14 | 1.0 s | Camera lens zoom in, soft mechanical whirr, subtle | Calendar pinch zoom, focus pulls |

## Music (not ElevenLabs)

Get one track from **Pixabay Music** (free, no attribution, commercial use). Download its license
certificate PDF along with it.

- **Mood:** warm, gentle, hopeful. Acoustic guitar, piano or soft strings. No vocals.
- **Tempo:** about 80–95 BPM.
- **Length:** 2:30 or longer (I'll loop or cut it), ideally with a real ending, not a fade.
- **Search:** "cozy acoustic", "warm piano inspiring", "gentle storytelling", "soft folk background".
- Send me 2–3 candidates if you can't decide; I'll pick the one that fits the cut.

## Scene plan (for the edit)

Legend: **App** = recorded on the emulator with the seed data. **Render** = built in Flutter for the video
(title cards, close-ups, isolated widgets) using the app's own fonts, colours and artwork.

| # | VO | Visual | SFX |
|---|---|---|---|
| 1 | 01 | Render: ink-paper texture, handwriting kicker writes itself in | 03 |
| 2 | 02 | Render: "The Redkeep" title, the Maester's face fades in | 01 |
| 3 | 03 | App: onboarding book pages turn → cover with your name → "Your journal is back" | 01, 03 |
| 4 | 04 | App: diary cord swiping across days; Render: split day/night wipe | 02, 11 |
| 5 | 05 | App: "How did it feel?" sheet, Excited picked, then the emoji picker | 04 |
| 6 | 06 | App: ruled paper, typing an entry; zoom on "Save as thought" | 03 |
| 7 | 07 | App: photo story prints, caption, drag to reorder, "Revisit this moment" | 05 |
| 8 | 08 | Render: close-up of raven hopping onto the cord with the wax-sealed letter; App: opening it | 06 |
| 9 | 09 | App: pinch from days → weeks → months → year | 14 |
| 10 | 10 | App: "What do you remember?" search, result opens a day | 02 |
| 11 | 11 | App: notes grid scroll; collections sheet with tags | 02 |
| 12 | 12 | App: format bar, checklist, tick an item in read mode; Render: zoom on the tick | 10 |
| 13 | 13 | App: colour strip → artwork → stock photo search "ocean" → applied | 02 |
| 14 | 14 | App: dictate a note, "Listening", then "Review your words" | — |
| 15 | 15 | Render: the Maester slides up, handwritten "Meet the Maester" | 07 |
| 16 | 16 | App: AI desk tool ribbon; Render: tool names stack in kinetic type | 04 |
| 17 | 17 | App: composer with attachment → "The Maester is writing…" → Original/Proposal compare | 07, 13 |
| 18 | 18 | App: new note drafted from an idea | 07 |
| 19 | 19 | App: Maester settings, the chain of models, key added | 04 |
| 20 | 20 | App: More shelf → Watchlist wall of pinned posters | 02 |
| 21 | 21 | App: Explore moods → results | 02 |
| 22 | 22 | App: title page, stamp rack, episodes ticked, add to a list; Render: close-up stamp hit | 08, 10 |
| 23 | 23 | App: tap the companion, reel spins, "How about…" | 09 |
| 24 | 24 | App: Appearance sky, theme switch, accents, font picker | 11, 04 |
| 25 | 25 | App: Android home screen with month mood widget + quick capture | 04 |
| 26 | 26 | App: More page journal opens, backup schedule; Render: "Backed up today" card | 12, 13 |
| 27 | 27 | Render: montage of the strongest frames, then the welcome book | 01 |
| 28 | 28 | Render: "Made with love by Lewis" in handwriting, heart in the accent colour, app icon | 03 |
