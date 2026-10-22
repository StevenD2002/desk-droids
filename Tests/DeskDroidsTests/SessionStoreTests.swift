import XCTest
@testable import DeskDroids

final class SessionStoreTests: XCTestCase {
    private var now = Date(timeIntervalSince1970: 1_000_000)
    private var store: SessionStore!

    override func setUp() {
        store = SessionStore(now: { [unowned self] in self.now })
    }

    private func send(_ name: String, session: String = "s1", _ fields: [String: Any] = [:]) {
        var payload = fields
        payload["hook_event_name"] = name
        payload["session_id"] = session
        store.apply(HookEvent(json: try! JSONSerialization.data(withJSONObject: payload))!)
    }

    func testAFailedToolCallIsAnOops() {
        send("UserPromptSubmit")
        send("PreToolUse", ["tool_name": "Bash", "tool_input": ["command": "npm test"]])
        send("PostToolUseFailure", ["tool_name": "Bash", "error": "Exit code 1\nError: Cannot find module", "is_interrupt": false])

        XCTAssertEqual(store.state, .oops)
    }

    func testInterruptingAToolIsNotAnOops() {
        send("UserPromptSubmit")
        send("PreToolUse", ["tool_name": "Bash", "tool_input": ["command": "sleep 100"]])
        send("PostToolUseFailure", ["tool_name": "Bash", "error": "Interrupted", "is_interrupt": true])

        // No Stop comes after Esc, so the turn is over.
        XCTAssertEqual(store.state, .idle)
    }

    func testOnlyFailedCommandsAreAnOops() {
        send("UserPromptSubmit")
        send("PostToolUseFailure", ["tool_name": "Edit", "error": "old_string not found", "is_interrupt": false])

        XCTAssertEqual(store.state, .thinking)
    }

    func testCompactingCutsInOnAnOops() {
        send("UserPromptSubmit")
        send("PostToolUseFailure", ["tool_name": "Bash", "error": "Exit code 1", "is_interrupt": false])
        send("PreCompact", ["trigger": "auto"])

        XCTAssertEqual(store.state, .compacting)
    }

    func testAnOopsLingersBrieflyThenCatchesUp() {
        send("UserPromptSubmit")
        send("PostToolUseFailure", ["tool_name": "Bash", "error": "Exit code 1", "is_interrupt": false])
        now += 1
        send("PreToolUse", ["tool_name": "Read", "tool_input": ["file_path": "/x/Package.swift"]])

        XCTAssertEqual(store.state, .oops)

        now += 3
        store.tick()

        XCTAssertEqual(store.state, .reading)
        XCTAssertEqual(store.focus?.detail, "Reading Package.swift")
    }

    func testEachRunningSubagentIsADrone() {
        send("UserPromptSubmit")
        send("SubagentStart", ["agent_id": "a1", "agent_type": "Explore"])
        send("SubagentStart", ["agent_id": "a2", "agent_type": "Explore"])
        send("SubagentStart", session: "s2", ["agent_id": "b1", "agent_type": "Plan"])
        XCTAssertEqual(store.droneCount, 3)

        send("SubagentStop", ["agent_id": "a1", "agent_type": "Explore"])
        XCTAssertEqual(store.droneCount, 2)
    }

    func testDronesGoHomeWhenTheSessionFallsAsleep() {
        send("SubagentStart", ["agent_id": "a1", "agent_type": "Explore"])
        send("Stop")
        now += 21
        store.tick()
        now += 5 * 60
        store.tick()

        XCTAssertEqual(store.state, .sleeping)
        XCTAssertEqual(store.droneCount, 0)
    }

    func testAfterCompactingItForgetsWhatItWasDoing() {
        send("PreCompact", ["trigger": "manual"])
        XCTAssertEqual(store.state, .compacting)

        send("PostCompact", ["trigger": "manual"])
        XCTAssertEqual(store.state, .forgetful)

        now += 3
        store.tick()
        XCTAssertEqual(store.state, .idle)
    }

    func testAnAutoCompactGetsBackToWork() {
        send("UserPromptSubmit")
        send("PreCompact", ["trigger": "auto"])
        send("PostCompact", ["trigger": "auto"])
        now += 3
        store.tick()

        XCTAssertEqual(store.state, .thinking)
    }

    func testFinishingALongTaskIsATriumph() {
        send("UserPromptSubmit")
        now += 6 * 60
        send("Stop")

        XCTAssertEqual(store.state, .triumph)
    }

    func testFinishingAQuickTaskIsJustDone() {
        send("UserPromptSubmit")
        now += 30
        send("Stop")

        XCTAssertEqual(store.state, .done)
    }

    func testAQuickTurnAfterAnInterruptedLongOneIsJustDone() {
        send("UserPromptSubmit")
        now += 6 * 60
        send("PostToolUseFailure", ["tool_name": "Bash", "error": "Interrupted", "is_interrupt": true])
        send("UserPromptSubmit")
        now += 30
        send("Stop")

        XCTAssertEqual(store.state, .done)
    }

    func testALongTurnRightAfterACompactIsATriumph() {
        send("PostCompact", ["trigger": "manual"])
        send("UserPromptSubmit")
        now += 6 * 60
        send("Stop")

        XCTAssertEqual(store.state, .triumph)
    }
}
