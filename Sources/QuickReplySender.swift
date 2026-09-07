import AppKit
import ApplicationServices

@MainActor
struct ReplyTarget {
    let app: NSRunningApplication
    let window: AXUIElement
    let title: String
    let input: AXUIElement
    let inputLabel: String
    static func capture(_ app: NSRunningApplication) -> ReplyTarget? {
        guard AXIsProcessTrusted(), let window = AXBridge.window(app) else { return nil }
        let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
        let focused = AXBridge.element(applicationElement, kAXFocusedUIElementAttribute)
        let input: AXUIElement

        if let focused,
           AXBridge.isTextInput(focused),
           currentDraft(focused).isEmpty,
           ReplyTargetHeuristics.score(label(focused)) >= 0 {
            input = focused
        } else {
            // Selecting an incoming message usually moves focus away from the composer.
            // Recover only a uniquely identifiable chat input; ambiguity must fall back to copy.
            let ranked = AXBridge.walk(window)
                .filter { AXBridge.isTextInput($0) && currentDraft($0).isEmpty }
                .map { ($0, ReplyTargetHeuristics.score(label($0))) }
                .filter { $0.1 > 0 }
                .sorted { $0.1 > $1.1 }
            guard let first = ranked.first,
                  ranked.dropFirst().first?.1 != first.1 else { return nil }
            input = first.0
        }
        return ReplyTarget(app: app, window: window, title: AXBridge.text(window, kAXTitleAttribute), input: input, inputLabel: label(input))
    }
    private static func currentDraft(_ input: AXUIElement) -> String {
        AXBridge.text(input, kAXValueAttribute)
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static func label(_ input: AXUIElement) -> String {
        [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute, "AXPlaceholderValue"].map { AXBridge.text(input, $0) }.joined(separator: "|")
    }
    func paste(_ text: String, send: Bool) async throws -> String {
        guard !app.isTerminated, let current = AXBridge.window(app), CFEqual(current, window),
              AXBridge.text(current, kAXTitleAttribute) == title, Self.label(input) == inputLabel,
              AXBridge.walk(current).contains(where: { CFEqual($0, input) }) else { throw AIBridgeError.focusChanged }
        let draft = AXBridge.text(input, kAXValueAttribute).replacingOccurrences(of: "\u{FEFF}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard draft.isEmpty else { throw AIBridgeError.inputUnavailable }
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        try await AXBridge.pause(0.2)
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
              AXUIElementSetAttributeValue(input, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success else { throw AIBridgeError.focusChanged }
        let lease = PasteboardLease(); defer { lease.restore() }
        guard lease.set(text) else { throw AIBridgeError.failed }
        AXBridge.key(9, flags: .maskCommand)
        try await AXBridge.pause(0.3)
        guard AXBridge.text(input, kAXValueAttribute).contains(text),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { throw AIBridgeError.failed }
        if send {
            AXBridge.key(36)
            return "已提交，请在聊天中确认送达"
        }
        return "已放回输入框，由你确认发送"
    }
}
