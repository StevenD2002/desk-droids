# desk-droids

A tiny droid that lives in your macOS menu bar and acts out what Claude Code is doing:
reading, typing, running commands, waiting on you, done.

```
[•_•].    thinking
[◑_◑]     reading files
[•_•]✎    editing
[>_<]⚙    running a command
[°O°]!!   needs your permission  (orange)
[^_^]✓    done
[-_-] zZ  asleep
```

(Text faces are placeholders; a pixel-art droid is coming.)

Click it to see every active Claude session and what each one is up to.

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
2. Pixel-art droid sprite with per-state animations
3. Droid beeps (synthesized), with mute
4. Smarter reactions: failures, subagent minions, compaction bonk
5. Proper `.app` bundle + launch at login
6. Personality system, then more droids (snarky, relentlessly optimistic)
