import Foundation

enum DroidState: String {
    case sleeping, idle, thinking, reading, writing, running, delegating, tinkering, compacting, forgetful, oops, needsYou, done, triumph

    /// Every state, in the order the fashion show (and `--ascii`) shows them.
    static let lineup: [DroidState] = [.idle, .thinking, .reading, .writing, .running, .delegating, .tinkering,
                                       .oops, .compacting, .forgetful, .needsYou, .done, .triumph, .sleeping]

    /// When several sessions are active, the droid shows the most urgent one.
    var priority: Int {
        switch self {
        case .needsYou: return 5
        case .thinking, .reading, .writing, .running, .delegating, .tinkering, .compacting, .forgetful, .oops: return 4
        case .done, .triumph: return 3
        case .idle: return 2
        case .sleeping: return 1
        }
    }

    var isBusy: Bool { priority == 4 }
    var isDone: Bool { self == .done || self == .triumph }

    /// Reactions that hold the stage for a moment, even though Claude has already moved on.
    var isFlash: Bool { self == .oops || self == .forgetful }

    /// Everyday work (prompts, tool calls) that waits its turn while a flash state is showing.
    var waitsForFlash: Bool { isBusy && !isFlash && self != .compacting }

    var label: String {
        switch self {
        case .sleeping: return "Sleeping"
        case .idle: return "Idle"
        case .thinking: return "Thinking"
        case .reading: return "Reading"
        case .writing: return "Writing"
        case .running: return "Running"
        case .delegating: return "Delegating"
        case .tinkering: return "Tinkering"
        case .compacting: return "Compacting"
        case .forgetful: return "Huh?"
        case .oops: return "Oops"
        case .needsYou: return "Needs you"
        case .done: return "Done"
        case .triumph: return "Done, finally!"
        }
    }
}

final class Session {
    let id: String
    var cwd: String
    var state: DroidState = .idle
    var detail = ""
    var updated = Date()
    /// True until the session's first state change, so the droid can greet it.
    var isNew = true
    /// While a flash state is showing: when it ends, and what Claude moved on to in the meantime.
    var holdUntil: Date?
    var afterHold: (state: DroidState, detail: String)?
    /// When Claude started on the current prompt, for celebrating long tasks.
    var turnStarted: Date?
    /// Running subagents, by `agent_id`. Each one is a drone buzzing around the droid.
    var subagents: Set<String> = []

    init(id: String, cwd: String) {
        self.id = id
        self.cwd = cwd
    }

    var project: String {
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? "~" : name
    }
}

/// Turns the stream of hook events into per-session state. Main thread only.
final class SessionStore {
    private static let flashHold: TimeInterval = 3
    private static let doneLingers: TimeInterval = 20
    private static let longTask: TimeInterval = 5 * 60
    private static let idleUntilSleep: TimeInterval = 5 * 60
    private static let busyGoesStale: TimeInterval = 10 * 60
    private static let forgetAfter: TimeInterval = 6 * 60 * 60

    private let now: () -> Date
    private(set) var sessions: [String: Session] = [:]
    var onChange: (() -> Void)?
    /// Fires on every state set, even when the state doesn't change (each tool call, say).
    /// `from` is nil the first time a session is seen.
    var onStateSet: ((_ from: DroidState?, _ to: DroidState) -> Void)?
    private var ticker: Timer?

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    /// The session the droid should be acting out right now.
    var focus: Session? {
        sessions.values.max { a, b in
            a.state.priority == b.state.priority ? a.updated < b.updated : a.state.priority < b.state.priority
        }
    }

    var state: DroidState { focus?.state ?? .sleeping }

    var droneCount: Int { sessions.values.reduce(0) { $0 + $1.subagents.count } }

    func apply(_ event: HookEvent) {
        if event.name == "SessionEnd" {
            sessions[event.sessionID] = nil
            onChange?()
            return
        }

        let session = sessions[event.sessionID] ?? Session(id: event.sessionID, cwd: event.cwd ?? "")
        sessions[event.sessionID] = session
        if let cwd = event.cwd { session.cwd = cwd }

        switch event.name {
        case "SessionStart":
            set(session, .idle, "Session started")
        case "UserPromptSubmit":
            session.turnStarted = session.turnStarted ?? now()
            set(session, .thinking, "Thinking about your prompt")
        case "PreToolUse":
            let (state, detail) = Self.describeTool(event)
            set(session, state, detail)
        case "PostToolUse":
            set(session, .thinking, "Thinking")
        case "PostToolUseFailure" where event.isInterrupt:
            // Esc ends the turn, and no Stop follows.
            session.turnStarted = nil
            set(session, .idle, "Interrupted")
        case "PostToolUseFailure" where event.toolName != "Bash":
            set(session, .thinking, "Thinking")
        case "PostToolUseFailure":
            set(session, .oops, "Oops: \(Self.truncate(event.error ?? "something failed"))")
        case "Notification":
            switch event.notificationType {
            case "permission_prompt", "elicitation_dialog":
                set(session, .needsYou, event.message ?? "Needs your input")
            case "idle_prompt":
                set(session, .idle, "Waiting for you")
            default:
                if event.message?.localizedCaseInsensitiveContains("permission") == true {
                    set(session, .needsYou, event.message ?? "Needs permission")
                }
            }
        case "Stop":
            if let started = session.turnStarted, now().timeIntervalSince(started) > Self.longTask {
                set(session, .triumph, "Finished a long one")
            } else {
                set(session, .done, "Finished")
            }
            session.turnStarted = nil
        case "SubagentStart":
            if let id = event.agentID { session.subagents.insert(id) }
            session.updated = now()
        case "SubagentStop":
            if let id = event.agentID { session.subagents.remove(id) }
            session.updated = now()
        case "PreCompact":
            set(session, .compacting, "Compacting context")
        case "PostCompact":
            set(session, .forgetful, "Wait, what was I doing?")
            // A manual /compact leaves it waiting for you; an automatic one carries on with the task.
            session.afterHold = event.trigger == "auto" ? (.thinking, "Thinking") : (.idle, "Waiting for you")
        default:
            session.updated = now()
        }
        onChange?()
    }

    private func set(_ session: Session, _ state: DroidState, _ detail: String) {
        if let holdUntil = session.holdUntil, now() < holdUntil, state.waitsForFlash {
            session.afterHold = (state, detail)
            session.updated = now()
            return
        }
        session.holdUntil = state.isFlash ? now().addingTimeInterval(Self.flashHold) : nil
        session.afterHold = nil
        let from = session.isNew ? nil : session.state
        session.isNew = false
        session.state = state
        session.detail = detail
        session.updated = now()
        onStateSet?(from, state)
    }

    /// Time-based transitions: flash states ending, done → idle → sleeping, and forgetting sessions
    /// that vanished without a SessionEnd (killed terminals, crashes). Runs every second.
    func tick() {
        let now = now()
        var changed = false
        for session in sessions.values {
            if let holdUntil = session.holdUntil, now >= holdUntil {
                let next = session.afterHold ?? (.thinking, "Thinking")
                set(session, next.state, next.detail)
                changed = true
                continue
            }
            let age = now.timeIntervalSince(session.updated)
            if age > Self.forgetAfter {
                sessions[session.id] = nil
                changed = true
            } else if session.state.isDone, age > Self.doneLingers {
                session.state = .idle
                session.detail = "Waiting for you"
                changed = true
            } else if session.state.isBusy, age > Self.busyGoesStale {
                session.state = .idle
                session.detail = "Went quiet"
                session.turnStarted = nil
                changed = true
            } else if session.state == .idle, age > Self.idleUntilSleep {
                session.state = .sleeping
                session.subagents = []  // in case a SubagentStop went missing
                changed = true
            }
        }
        if changed { onChange?() }
    }

    private static func describeTool(_ event: HookEvent) -> (DroidState, String) {
        let tool = event.toolName ?? "tool"
        let input = event.toolInput
        let file = (input["file_path"] as? String).map { ($0 as NSString).lastPathComponent }

        switch tool {
        case "Read", "NotebookRead":
            return (.reading, "Reading \(file ?? "a file")")
        case "Grep", "Glob", "LS":
            return (.reading, "Searching \(truncate(input["pattern"] as? String ?? "files"))")
        case "WebFetch", "WebSearch":
            let target = (input["url"] as? String).flatMap { URL(string: $0)?.host } ?? input["query"] as? String
            return (.reading, "Browsing \(truncate(target ?? "the web"))")
        case "Edit", "MultiEdit", "Write", "NotebookEdit":
            return (.writing, "Editing \(file ?? "a file")")
        case "Bash":
            let what = input["description"] as? String ?? input["command"] as? String ?? "a command"
            return (.running, truncate(what))
        case "Task", "Agent":
            return (.delegating, "Delegating: \(truncate(input["description"] as? String ?? "a subagent"))")
        case "TodoWrite":
            return (.thinking, "Planning")
        default:
            return (.tinkering, "Using \(tool)")
        }
    }

    private static func truncate(_ text: String, to limit: Int = 48) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        return singleLine.count > limit ? String(singleLine.prefix(limit - 1)) + "…" : singleLine
    }

    func snapshotJSON() -> Data {
        let list = sessions.values.sorted { $0.updated > $1.updated }.map { s -> [String: Any] in
            ["id": s.id, "project": s.project, "cwd": s.cwd, "state": s.state.rawValue,
             "detail": s.detail, "updated": ISO8601DateFormatter().string(from: s.updated)]
        }
        let object: [String: Any] = ["state": state.rawValue, "sessions": list]
        return (try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }
}
