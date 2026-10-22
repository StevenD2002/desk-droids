# desk-droids

A macOS menu bar droid (plus a tuxedo cat) that acts out what Claude Code is doing. Swift package,
no dependencies, macOS 13+. What's next is in `ROADMAP.md`.

## How it fits together

- `HookServer`: a loopback HTTP server on port 4747. Claude Code's global `http` hooks in
  `~/.claude/settings.json` POST every event to `/hook`. It always answers with an empty 200, so it
  never blocks a tool call.
- `HookEvent` → `SessionStore`: per-session `DroidState`. The most urgent session wins
  (needs-you > busy > done > idle > sleeping). Time decays done → idle → sleeping.
- `StatusBarController`: animation tick every 0.4s, the menu (Sounds, Cat, Fashion show, Open at
  login), and sound triggers.
- `LoginItem`: the "Open at login" toggle (`SMAppService.mainApp`). It's only available in the `.app`.
- `SettingsMigration`: the dev build stores settings in the `DeskDroids` defaults domain and the
  `.app` stores them under `com.stevendew.desk-droids`. On launch, the app copies over any it's missing.
- `scripts/make-app.sh` (`make app`): builds and signs the bundle and installs it in `~/Applications`.
- `Sprite`: the droid as ASCII pixel grids (hat / head / eyes / legs / props), composited on a
  `Canvas`, one character per point. `Sprite.pose(for:tick:)` defines each state's look.
- `Cat`: `CatSprite` grids plus `CatDirector`, which plays scenes as timelines of `Beat`s and can
  adjust the droid's pose (knock the hat off, change its eyes).
- `Voice`: `Phrase`s are lists of exponential pitch-sweep `Tone`s, rendered to PCM buffers and played
  through AVAudioEngine.

## Checking changes (you can't see the menu bar)

- Steven normally runs the installed `~/Applications/DeskDroids.app`. To try a change, quit it and run
  the dev build instead: `pkill -f DeskDroids.app/Contents/MacOS; swift build && nohup .build/debug/DeskDroids >/dev/null 2>&1 &`.
  Only one copy can hold port 4747. When you're done, `make app` reinstalls the app; then `pkill -f
  .build/debug/DeskDroids; open ~/Applications/DeskDroids.app`.
- `swift test` runs the tests (only settings migration so far).
- `.build/debug/DeskDroids --ascii` prints every droid pose. `--ascii-cat <scene> [state]` plays a cat
  scene tick by tick. Use these to check sprite and choreography changes before asking Steven to look.
- `curl localhost:4747/state` shows the sessions. `curl -X POST localhost:4747/say/<phrase>` plays a
  sound, and `/cat/<scene>` summons the cat. Fake events: `curl -X POST localhost:4747/hook -d
  '{"hook_event_name":"Stop","session_id":"x"}'` (send a `SessionEnd` afterward to clean up).
- `screencapture` can't capture other apps' menu bar icons. Ask Steven for a screenshot; he's happy
  to send them.

## Working with Steven

- Work in milestones with natural stopping points. Commit each one, then **ask before pushing**.
- Commits in this repo use his personal email (set in the repo's git config), not his work one.
- He's iterating on look and feel by eye: make the change, restart the app, trigger it (`/say`,
  `/cat`), and ask for a screenshot or a listen.
- Black-ish sprites need care on the dark menu bar. The cat uses 20% gray fur plus a faint outline in
  dark mode (36% fur was too gray; 20% without an outline disappeared).
