import Foundation

enum DroidState: String {
    case sleeping, idle, thinking, reading, writing, running, delegating, tinkering, compacting, needsYou, done

    /// When several sessions are active, the droid shows the most urgent one.
    var priority: Int {
        switch self {
        case .needsYou: return 5
        case .thinking, .reading, .writing, .running, .delegating, .tinkering, .compacting: return 4
        case .done: return 3
        case .idle: return 2
        case .sleeping: return 1
        }
    }

    var isBusy: Bool { priority == 4 }

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
        case .needsYou: return "Needs you"
        case .done: return "Done"
        }
    }
}

final class Session {
    let id: String
    var cwd: String
    var state: DroidState = .idle
    var detail = ""
    var updated = Date()

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
    private static let doneLingers: TimeInterval = 20
    private static let idleUntilSleep: TimeInterval = 5 * 60
    private static let busyGoesStale: TimeInterval = 10 * 60
    private static let forgetAfter: TimeInterval = 6 * 60 * 60

    private(set) var sessions: [String: Session] = [:]
    var onChange: (() -> Void)?
    private var ticker: Timer?

    init() {
        ticker = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.decay() }
    }

    /// The session the droid should be acting out right now.
    var focus: Session? {
        sessions.values.max { a, b in
            a.state.priority == b.state.priority ? a.updated < b.updated : a.state.priority < b.state.priority
        }
    }

    var state: DroidState { focus?.state ?? .sleeping }

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
            set(session, .thinking, "Thinking about your prompt")
        case "PreToolUse":
            let (state, detail) = Self.describeTool(event)
            set(session, state, detail)
        case "PostToolUse":
            set(session, .thinking, "Thinking")
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
            set(session, .done, "Finished")
        case "PreCompact":
            set(session, .compacting, "Compacting context")
        default:
            session.updated = Date()
        }
        onChange?()
    }

    private func set(_ session: Session, _ state: DroidState, _ detail: String) {
        session.state = state
        session.detail = detail
        session.updated = Date()
    }

    /// Time-based transitions: done → idle → sleeping, and forgetting sessions that vanished
    /// without a SessionEnd (killed terminals, crashes).
    private func decay() {
        let now = Date()
        var changed = false
        for session in sessions.values {
            let age = now.timeIntervalSince(session.updated)
            if age > Self.forgetAfter {
                sessions[session.id] = nil
                changed = true
            } else if session.state == .done, age > Self.doneLingers {
                session.state = .idle
                session.detail = "Waiting for you"
                changed = true
            } else if session.state.isBusy, age > Self.busyGoesStale {
                session.state = .idle
                session.detail = "Went quiet"
                changed = true
            } else if session.state == .idle, age > Self.idleUntilSleep {
                session.state = .sleeping
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
