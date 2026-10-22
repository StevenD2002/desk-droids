import Foundation

/// The bits of a Claude Code hook payload the droid cares about.
/// See https://code.claude.com/docs/en/hooks for the full shapes.
struct HookEvent {
    let name: String
    let sessionID: String
    let cwd: String?
    let toolName: String?
    let toolInput: [String: Any]
    let notificationType: String?
    let message: String?

    init?(json data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = object["hook_event_name"] as? String,
              let sessionID = object["session_id"] as? String
        else { return nil }

        self.name = name
        self.sessionID = sessionID
        cwd = object["cwd"] as? String
        toolName = object["tool_name"] as? String
        toolInput = object["tool_input"] as? [String: Any] ?? [:]
        notificationType = object["notification_type"] as? String
        message = object["message"] as? String
    }
}
