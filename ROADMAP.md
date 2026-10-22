# Roadmap

Milestones 1–4 are done (see README). Each milestone ends with a commit and push once Steven has seen
it working in his menu bar.

## 5. Smarter reactions

More personality from the events Claude Code already sends.

- **Failed commands → sad whistle + facepalm.** A new `oops` state/pose (squeezed-shut eyes, maybe a
  storm-cloud prop) and a descending `sad` phrase. *Open question:* how to detect failure. Check the
  hooks docs (https://code.claude.com/docs/en/hooks) for a `PostToolUseFailure` event; otherwise inspect
  `tool_response` in `PostToolUse`. Log a few real payloads first. Any new event also has to be added
  to the `http` hooks in `~/.claude/settings.json`.
- **Subagents → minion drones.** Count active subagents per session (PreToolUse `Task`/`Agent` is +1,
  `SubagentStop` is −1; check whether a `SubagentStart` event exists). Draw tiny 3–4px drones buzzing
  around the droid's head, one per subagent, capped at about 3. Stage space is tight, so they'll have
  to overlap the hat area.
- **Compaction → head bonk.** Replace the current dizzy wobble with a bonk (stars prop, a head-bump
  frame), then a short "?" afterward, as if it forgot something.
- Ideas for this milestone: a celebration for a long task finishing (more confetti than usual for
  sessions that ran more than about 5 minutes), and the cat reacting to the party hat.

## 6. Real `.app` + launch at login

Right now the droid only runs because a Claude session started `.build/debug/DeskDroids` in the
background. It dies on reboot.

- A `make app` (or script) that does a release build and wraps it into `DeskDroids.app` with an
  `Info.plist` (`LSUIElement = true`, so no Dock icon, and a bundle id like `com.stevendew.desk-droids`),
  ad-hoc codesigns it, and copies it to `~/Applications`.
- **Open at login** toggle in the menu via `SMAppService.mainApp` (macOS 13+).
- Gotcha: UserDefaults moves from the `DeskDroids` domain to the bundle id, which resets the sound
  and cat settings. Migrate them, or accept the reset.
- Gotcha: a second copy can't bind port 4747 and shows the broken (red dizzy) droid. That's fine, but
  the README should say to quit the dev build before launching the app.

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
- More cat bits (chasing the antenna ball, knocking the party hat off on purpose), and other cats.
