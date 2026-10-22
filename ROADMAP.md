# Roadmap

Milestones 1–6 are done (see README). Each milestone ends with a commit and push once Steven
has seen it working in his menu bar.

## 7. Personalities and more droids

Steven wants a couple of characters with their own personalities: the current R2-style beeper, a
**snarky** one, and a **relentlessly optimistic** one.

- Turn "the droid" into a definition: body tint/sprite variations, voice parameters (pitch range,
  speed, warble), and a set of lines per event.
- **Speech bubbles:** the menu bar is too short for text, so show lines in a small transient popover or
  panel under the status item for about 3s. Rate-limit them, and include a "quiet" option.
  - Snarky: *"Oh good, another permission prompt. Riveting."* / *"Tests failed. Shocking."*
  - Optimistic: *"WE DID IT!!"* / *"Ooh, a new file! I love new files!"*
- A droid picker in the menu. Start with one droid at a time. Several at once (one per session) is a
  later idea.

## Backlog

- **Context/cost meter:** the droid sweats as context fills. Hooks don't carry this, but the
  status line command gets JSON with context and cost, and it could POST that to the droid.
- **Click a session to jump to it.** kitty remote control (`kitty @ focus-window`, needs
  `allow_remote_control`), or herdr, which Steven also uses.
- Holiday hats (Santa in December, a pumpkin in October).
- More cat bits (chasing the antenna ball, batting at the drones, reacting to the party hat or knocking it
  off on purpose), and other cats.
