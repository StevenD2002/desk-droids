# desk-droids

A tiny droid that lives in your macOS menu bar and acts out what Claude Code is doing:
reading, typing, running commands, waiting on you, done.

It's a little pixel-art droid with legs, and it wears a different hat for each kind of work:

| Claude is…              | The droid…                                     |
|-------------------------|------------------------------------------------|
| thinking                | wears a wizard hat, eyes up                    |
| reading / searching     | wears a grad cap, eyes darting left and right  |
| editing files           | wears a chef hat, marching in place            |
| running a command       | wears a hard hat, squinting, marching          |
| spawning subagents      | wears a crown                                  |
| using other tools (MCP) | wears a spinning propeller beanie              |
| compacting context      | wobbles with dizzy eyes                        |
| waiting on permission   | hops with wide orange eyes and a "!"           |
| done                    | wears a party hat, with sparkles               |
| idle for 5 minutes      | sits down in a nightcap and snoozes            |

The body follows the menu bar's text color (white in dark mode, black in light mode); hats are in color.
Pick **Fashion show** from its menu to see every outfit. `swift run DeskDroids --ascii` prints them all in the terminal.

Click it to see every active Claude session and what each one is up to.

### The cat

A tuxedo cat shares the stage and bothers the droid. Pick how much cat you want from **Cat** in the menu:
*No cat*, *Visits now and then* (strolls in every 4–6 minutes), or *Always around* (sits beside the
droid, flicks its tail, naps when the droid naps). **Summon the cat** starts trouble immediately.

Its bits: a stare-down, poking the droid in the face, swatting its hat off (the hat stays gone until
the next task), loafing on its head, walking across the keyboard mid-edit (garbled beeps), and
napping next to a sleeping droid. It always clears off when the droid needs you.

Trigger one directly with `curl -X POST localhost:4747/cat/headLoaf`
(`stare`, `poke`, `hatThief`, `headLoaf`, `keyboard`, `nap`), or watch one in the terminal with
`swift run DeskDroids --ascii-cat hatThief writing`.

### Beeps

The droid talks in synthesized R2-style chirps (no sound files; every phrase varies a little):
a boot-up sweep when a session starts, an "on it!" chirp when you send a prompt, soft chatter on tool
calls, an urgent "hey?!" when it needs permission (repeated every 45s if ignored), a happy trill when
it's done, a confused warble while compacting, and a sleepy whistle when it nods off.

**Sounds** in its menu switches between *All beeps*, *Important only* (no chatter), and *Muted*.
To hear a phrase on demand: `curl -X POST localhost:4747/say/happy`
(`boot`, `acknowledge`, `chatter`, `alert`, `happy`, `confused`, `sleepy`, and the cat-related
`mrrp`, `purr`, `startled`, `grumpy`, `garbled`).

## Run it

```sh
swift run
```

Requires macOS 13+ and the Swift toolchain (Xcode or Command Line Tools). No dependencies.

## Hook it up to Claude Code

The droid listens on `http://localhost:4747/hook` (loopback only). Add an `http` hook for each event
in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart":     [{ "hooks": [{ "type": "http", "url": "http://localhost:4747/hook", "timeout": 1 }] }],
    "SessionEnd":       [{ "hooks": [{ "type": "http", "url": "http://localhost:4747/hook", "timeout": 1 }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "http", "url": "http://localhost:4747/hook", "timeout": 1 }] }],
    "PreToolUse":       [{ "hooks": [{ "type": "http", "url": "http://localhost:4747/hook", "timeout": 1 }] }],
    "PostToolUse":      [{ "hooks": [{ "type": "http", "url": "http://localhost:4747/hook", "timeout": 1 }] }],
    "Notification":     [{ "hooks": [{ "type": "http", "url": "http://localhost:4747/hook", "timeout": 1 }] }],
    "Stop":             [{ "hooks": [{ "type": "http", "url": "http://localhost:4747/hook", "timeout": 1 }] }],
    "SubagentStop":     [{ "hooks": [{ "type": "http", "url": "http://localhost:4747/hook", "timeout": 1 }] }],
    "PreCompact":       [{ "hooks": [{ "type": "http", "url": "http://localhost:4747/hook", "timeout": 1 }] }]
  }
}
```

The droid always answers with an empty `200`, so it can never block or alter a tool call. When it isn't
running, the hooks just time out quietly.

`curl localhost:4747/state` shows what the droid currently thinks is going on.

## Roadmap

1. ~~Plumbing: menu bar app, hook server, session tracking~~
2. ~~Pixel-art droid with legs and a hat for every task~~
3. ~~Droid beeps (synthesized), with mute~~
4. ~~A tuxedo cat that bothers the droid~~
5. Smarter reactions: failures, subagent minions, compaction bonk
6. Proper `.app` bundle + launch at login
7. Personality system, then more droids (snarky, relentlessly optimistic)
