import AppKit
import ApplicationServices

@MainActor
enum AXBridge {
    static func value(_ e: AXUIElement, _ key: String) -> CFTypeRef? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(e, key as CFString, &v) == .success else { return nil }
        return v
    }
    static func text(_ e: AXUIElement, _ key: String) -> String { value(e, key) as? String ?? "" }
    static func element(_ e: AXUIElement, _ key: String) -> AXUIElement? {
        guard let v = value(e, key), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(v, to: AXUIElement.self)
    }
    static func walk(_ root: AXUIElement, limit: Int = 2200) -> [AXUIElement] {
        var result: [AXUIElement] = []
        func visit(_ item: AXUIElement, _ depth: Int) {
            guard depth < 26, result.count < limit else { return }
            result.append(item)
            for child in value(item, kAXChildrenAttribute) as? [AXUIElement] ?? [] { visit(child, depth + 1) }
        }
        visit(root, 0)
        return result
    }
    static func isTextInput(_ e: AXUIElement) -> Bool {
        [kAXTextAreaRole, kAXTextFieldRole].contains(text(e, kAXRoleAttribute)) && (value(e, kAXEnabledAttribute) as? Bool ?? true)
    }
    static func window(_ app: NSRunningApplication) -> AXUIElement? {
        element(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedWindowAttribute)
    }
    static func key(_ code: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        for pressed in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: pressed)
            event?.flags = flags; event?.post(tap: .cghidEventTap)
        }
    }
    static func pause(_ seconds: Double) async throws { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
}

@MainActor
final class PasteboardLease {
    private var items: [[NSPasteboard.PasteboardType: Data]] = []
    private var ownedChange: Int?
    init() {
        items = (NSPasteboard.general.pasteboardItems ?? []).map { item in
            var snapshot: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let bytes = item.data(forType: type) { snapshot[type] = bytes } }
            return snapshot
        }
    }
    func set(_ text: String) -> Bool {
        let board = NSPasteboard.general; board.clearContents()
        let result = board.setString(text, forType: .string); ownedChange = board.changeCount
        return result
    }
    func claimCurrentContents() { ownedChange = NSPasteboard.general.changeCount }
    func restore() {
        let board = NSPasteboard.general
        guard board.changeCount == ownedChange else { items = []; return }
        board.clearContents()
        let restored = items.map { snapshot in
            let item = NSPasteboardItem()
            for (type, data) in snapshot { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { board.writeObjects(restored) }
        items = []; ownedChange = nil
    }
}

enum AIBridgeError: LocalizedError {
    case permission, notInstalled, inputUnavailable, focusChanged, timeout, cancelled, failed
    var errorDescription: String? {
        switch self {
        case .permission: return "自动接回结果需要辅助功能权限；这次不会替你打开系统设置。"
        case .notInstalled: return "没有找到这个 AI。可以换一个，或用手动接力。"
        case .inputUnavailable: return "没有找到空白输入框，请先登录并打开新对话。原消息还在。"
        case .focusChanged: return "窗口已经切换，这次没有继续输入。"
        case .timeout: return "还没接到完整结果。可以去 AI 看看，或重试；不会自动重复发送。"
        case .cancelled: return "已停止接收。AI 中已发出的任务不会被撤回。"
        case .failed: return "这次没有接上。原消息还在，可以重试或手动接力。"
        }
    }
}

@MainActor
enum DesktopAI {
    static func run(provider: AIProvider, prompt: String, token: String, status: (String) -> Void) async throws -> BridgeResponse {
        // Never make macOS reopen System Settings by itself. Permission is requested
        // only when the user explicitly chooses the inline settings action.
        guard AXIsProcessTrusted() else { throw AIBridgeError.permission }
        guard let url = provider.installedApplicationURL() else { throw AIBridgeError.notInstalled }
        status("正在打开 \(provider.name)…")
        let app: NSRunningApplication
        if let running = provider.runningApplication() { app = running }
        else { app = try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) }
        try Task.checkCancellation()
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        try await AXBridge.pause(0.5)
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { throw AIBridgeError.focusChanged }
        guard provider.id == "workbuddy" else { throw AIBridgeError.inputUnavailable }
        AXBridge.key(45, flags: .maskCommand)
        var composer: AXUIElement?
        for _ in 0..<24 {
            try await AXBridge.pause(0.25)
            if let window = AXBridge.window(app) {
                composer = AXBridge.walk(window).first {
                    let value = AXBridge.text($0, kAXValueAttribute).replacingOccurrences(of: "\u{FEFF}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    return AXBridge.text($0, kAXRoleAttribute) == kAXTextAreaRole && (value.isEmpty || value.contains("今天帮你做些什么"))
                }
            }
            if composer != nil { break }
        }
        guard let composer else { throw AIBridgeError.inputUnavailable }
        try Task.checkCancellation()
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { throw AIBridgeError.focusChanged }
        guard AXUIElementSetAttributeValue(composer, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success else { throw AIBridgeError.inputUnavailable }
        let lease = PasteboardLease(); defer { lease.restore() }
        guard lease.set(prompt) else { throw AIBridgeError.failed }
        AXBridge.key(9, flags: .maskCommand)
        try await AXBridge.pause(0.35)
        try Task.checkCancellation()
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { throw AIBridgeError.focusChanged }
        guard AXBridge.text(composer, kAXValueAttribute).contains(token) else { throw AIBridgeError.failed }
        AXBridge.key(36)
        try await AXBridge.pause(0.25); lease.restore()
        status("\(provider.name) 正在理解，结果会回到这里…")
        for _ in 0..<60 {
            try await AXBridge.pause(1.5)
            guard !app.isTerminated, let window = AXBridge.window(app) else { continue }
            let pieces = AXBridge.walk(window).filter { AXBridge.text($0, kAXRoleAttribute) == kAXStaticTextRole }
                .map { AXBridge.text($0, kAXValueAttribute) }.filter { !$0.contains(PromptBuilder.marker) }
            for value in pieces.reversed() { if let result = BridgeResponse.parse(value, token: token) { return result } }
            if let result = BridgeResponse.parse(pieces.joined(separator: "\n"), token: token) { return result }
        }
        throw AIBridgeError.timeout
    }
}
