import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let model = ClipboardModel()
    private var panel: NSPanel!
    private var returnTarget: ReplyTarget?
    private var returnApplication: NSRunningApplication?
    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMenus()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let url = Bundle.main.url(forResource: "LydiaLogo", withExtension: "png"), let logo = NSImage(contentsOf: url) {
                logo.size = NSSize(width: 19, height: 19); button.image = logo
            } else { button.image = NSImage(systemSymbolName: "quote.bubble.fill", accessibilityDescription: "说人话") }
            button.toolTip = "说人话 · ⌃⌥R"
            button.target = self; button.action = #selector(toggle)
        }
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 600),
                        styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
        panel.title = "Lydia 脑洞小工具 · 说人话"
        panel.isFloatingPanel = true; panel.level = .floating
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: ContentView(model: model,
            sendReply: { [weak self] in self?.returnReply($0, send: $1, remember: $2) },
            startOver: { [weak self] in
                self?.model.reset()
                self?.returnTarget = nil
                self?.returnApplication = nil
            }))
        panel.center()
        NSApp.servicesProvider = self
        model.onHandoff = { [weak self] in self?.panel.orderOut(nil) }
        model.onResult = { [weak self] in
            guard let self else { return }
            let current = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            if self.model.selectedProvider.bundleIdentifiers.contains(current ?? "") || current == Bundle.main.bundleIdentifier {
                self.show(capture: false)
            } else {
                self.panel.orderFrontRegardless()
            }
        }
        registerHotKey()
        NSUpdateDynamicServices()
        show(capture: true)
    }

    /// macOS Services entry point. In apps that expose standard text selection,
    /// users can select a complete message and choose Services > 说人话.
    @objc(humanize:userData:error:)
    func humanize(_ pasteboard: NSPasteboard,
                  userData: String?,
                  error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string), model.acceptSelectedText(text) else {
            error.pointee = "没有读到可处理的文字" as NSString
            show(capture: false)
            return
        }

        // Capture the exact originating field before this panel or the AI app takes focus.
        if let current = NSWorkspace.shared.frontmostApplication,
           current.bundleIdentifier != Bundle.main.bundleIdentifier {
            returnApplication = current
            returnTarget = ReplyTarget.capture(current)
        }

        show(capture: false)
        // The service invocation itself is the user's command: do not ask for a second click.
        DispatchQueue.main.async { [weak self] in self?.model.understand() }
    }
    private func installMenus() {
        // A native menu keeps Cmd+A/C/V/Z available in the lightweight panel's text editors.
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "说人话")
        appMenu.addItem(withTitle: "退出说人话", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        // Workbench launcher only opens the panel; URLs can never submit text or send a reply.
        if urls.contains(where: { $0.scheme == "lydia-speak" }) { show(capture: true) }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        show(capture: true); return true
    }
    @objc private func toggle() {
        if panel.isVisible { panel.orderOut(nil) } else { show(capture: true) }
    }
    private func handleHotKey() async {
        if panel.isVisible {
            panel.orderOut(nil)
            return
        }

        guard let current = NSWorkspace.shared.frontmostApplication,
              current.bundleIdentifier != Bundle.main.bundleIdentifier else {
            show(capture: true)
            return
        }
        returnApplication = current
        returnTarget = ReplyTarget.capture(current)

        // With Accessibility permission, the same hotkey can act on the current
        // selection. Restore the user's original clipboard immediately afterward.
        if AXIsProcessTrusted() {
            let board = NSPasteboard.general
            let previousChange = board.changeCount
            let lease = PasteboardLease()
            AXBridge.key(CGKeyCode(kVK_ANSI_C), flags: .maskCommand)
            try? await AXBridge.pause(0.18)
            if board.changeCount != previousChange {
                lease.claimCurrentContents()
                let accepted = board.string(forType: .string).map { model.acceptSelectedText($0) } ?? false
                lease.restore()
                if accepted {
                    show(capture: false)
                    await Task.yield()
                    model.understand()
                    return
                }
            }
        }
        show(capture: true)
    }
    private func show(capture: Bool) {
        if capture {
            if !model.hasResult && !model.isWorking,
               let current = NSWorkspace.shared.frontmostApplication,
               current.bundleIdentifier != Bundle.main.bundleIdentifier {
                returnApplication = current
                returnTarget = ReplyTarget.capture(current)
            }
            model.refreshClipboard()
        }
        NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil)
    }
    private func returnReply(_ text: String, send: Bool, remember: Bool) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let resolvedTarget = returnTarget ?? returnApplication.flatMap { ReplyTarget.capture($0) }
        guard let target = resolvedTarget else {
            model.copyQuickReply(text)
            model.showStatus("已复制。未确认原输入框，回到聊天里粘贴即可。")
            return
        }
        returnTarget = target
        panel.orderOut(nil)
        Task {
            do {
                let status = try await target.paste(text, send: send)
                if remember { model.recordUsedReply(text) }
                else { model.showStatus(status) }
            }
            catch {
                model.copyQuickReply(text)
                model.showStatus("未自动发送，回复已复制；原输入框可能已切换或有草稿。")
                show(capture: false)
            }
        }
    }
    private func registerHotKey() {
        let id = EventHotKeyID(signature: 0x4C594449, id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_R), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &hotKeyReference)
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer in
            guard let pointer else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(pointer).takeUnretainedValue()
            Task { @MainActor in await delegate.handleHotKey() }
            return noErr
        }, 1, &type, pointer, &eventHandlerReference)
    }
    func applicationWillTerminate(_ notification: Notification) {
        model.cancel()
        if let hotKeyReference { UnregisterEventHotKey(hotKeyReference) }
        if let eventHandlerReference { RemoveEventHandler(eventHandlerReference) }
    }
}
@main
struct HumanSpeakApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate(); application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}
