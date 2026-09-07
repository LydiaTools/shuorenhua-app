import AppKit
import Foundation

@MainActor
final class ClipboardModel: ObservableObject {
    @Published var sourceText = ""
    @Published var intention = ""
    @Published var reply = ""
    @Published private(set) var plain = ""
    @Published private(set) var actionItems: [String] = []
    @Published private(set) var unclear = ""
    @Published private(set) var reportedReplyRisks: [String] = []
    @Published private(set) var isWorking = false
    @Published private(set) var clipboardHint = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var needsServiceSetup = false
    @Published private(set) var serviceConfigured = false
    @Published private(set) var installedProviderIDs: Set<String> = []
    @Published var selectedSceneID: String {
        didSet { UserDefaults.standard.set(selectedSceneID, forKey: "preferredWorkplaceScene") }
    }
    @Published var selectedProviderID: String {
        didSet { UserDefaults.standard.set(selectedProviderID, forKey: "preferredAIProviderV2") }
    }

    var onHandoff: (() -> Void)?
    var onResult: (() -> Void)?

    private var task: Task<Void, Never>?
    private var lastClipboardCount = -1
    private var lastCopiedText = ""
    private var isPreview = false

    init() {
        installedProviderIDs = Set(AIProvider.all.filter { $0.isInstalled() }.map(\.id))
        let savedScene = UserDefaults.standard.string(forKey: "preferredWorkplaceScene") ?? "leader"
        selectedSceneID = WorkplaceScene.all.contains { $0.id == savedScene } ? savedScene : "leader"
        let savedProvider = UserDefaults.standard.string(forKey: "preferredAIProviderV2") ?? "feishu"
        selectedProviderID = AIProvider.all.contains { $0.id == savedProvider } ? savedProvider : "feishu"
        serviceConfigured = DeepSeekCredentialStore.load() != nil
    }

    var selectedScene: WorkplaceScene {
        WorkplaceScene.all.first { $0.id == selectedSceneID } ?? WorkplaceScene.all[0]
    }
    var selectedProvider: AIProvider {
        AIProvider.all.first { $0.id == selectedProviderID } ?? AIProvider.all[0]
    }
    var hasUsableMessage: Bool {
        !PromptBuilder.normalize(sourceText).isEmpty && !PromptBuilder.isGeneratedTask(sourceText)
    }
    var automaticAvailable: Bool { serviceConfigured }
    var hasResult: Bool { !plain.isEmpty }
    var hasReply: Bool { !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var replyRisks: [String] {
        CommitmentGuard.detect(intention: intention, reply: reply, reported: reportedReplyRisks)
    }
    var learnedReplyCount: Int { ReplyMemory.load().count }

    @discardableResult
    func acceptSelectedText(_ raw: String) -> Bool {
        guard !isWorking else {
            clipboardHint = "上一句话还在处理中"
            return false
        }
        let text = PromptBuilder.normalize(raw)
        guard !text.isEmpty, !PromptBuilder.isGeneratedTask(text) else {
            clipboardHint = "没有读到可处理的文字"
            return false
        }
        sourceText = text
        clearResult()
        clipboardHint = "已接住选中的话"
        return true
    }

    func refreshClipboard(force: Bool = false) {
        guard !isWorking else { return }
        let board = NSPasteboard.general
        guard force || lastClipboardCount != board.changeCount else { return }
        lastClipboardCount = board.changeCount
        guard let raw = board.string(forType: .string) else { return }
        let text = PromptBuilder.normalize(raw)
        guard !text.isEmpty,
              !PromptBuilder.isGeneratedTask(text),
              text != lastCopiedText,
              text != sourceText else { return }
        sourceText = text
        clearResult()
        clipboardHint = ""
    }

    func selectScene(_ id: String) {
        guard id != selectedSceneID else { return }
        selectedSceneID = id
        if hasResult || hasReply { clearResult() }
    }

    func clearResult(keepIntention: Bool = false) {
        plain = ""
        actionItems = []
        unclear = ""
        reply = ""
        reportedReplyRisks = []
        if !keepIntention { intention = "" }
        errorMessage = nil
        isPreview = false
    }

    func reset() {
        cancel()
        sourceText = ""
        clearResult()
        clipboardHint = ""
    }

    func understand() {
        guard !isWorking, hasUsableMessage else { return }
        guard let key = DeepSeekCredentialStore.load() else {
            runPrototypeUnderstanding()
            return
        }

        errorMessage = nil
        needsServiceSetup = false
        clearResult()
        isWorking = true
        clipboardHint = "正在把话说明白…"
        let message = sourceText
        let scene = selectedScene

        task = Task {
            do {
                let result = try await connectedService(key: key).understand(message: message, scene: scene)
                try Task.checkCancellation()
                plain = result.plain
                actionItems = result.actions
                unclear = result.missing
                clipboardHint = "已经说明白了"
            } catch {
                errorMessage = error is CancellationError ? "已取消" : error.localizedDescription
                clipboardHint = "原话还在，点一下就能重试"
            }
            isWorking = false
            task = nil
            onResult?()
        }
    }

    func composeReply(removingRisks: Bool = false) {
        guard !isWorking, hasUsableMessage,
              !intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if DeepSeekCredentialStore.load() == nil {
            runPrototypeReply()
            return
        }
        guard let key = DeepSeekCredentialStore.load() else {
            needsServiceSetup = true
            clipboardHint = "先连接内置 AI，也可以先看效果"
            return
        }

        errorMessage = nil
        needsServiceSetup = false
        isWorking = true
        let risksToRemove = removingRisks ? replyRisks : []
        reply = ""
        reportedReplyRisks = []
        clipboardHint = "正在按你的意思改…"
        let message = sourceText
        let userIntention = intention
        let scene = selectedScene
        let styleExamples = ReplyMemory.load()

        task = Task {
            do {
                let result = try await connectedService(key: key).composeReply(
                    message: message,
                    intention: userIntention,
                    scene: scene,
                    styleExamples: styleExamples,
                    removeRisks: risksToRemove
                )
                try Task.checkCancellation()
                reply = result.reply
                reportedReplyRisks = result.addedCommitments
                clipboardHint = CommitmentGuard.detect(
                    intention: userIntention,
                    reply: result.reply,
                    reported: result.addedCommitments
                ).isEmpty ? "没替你多答应" : "发现了你没说过的承诺，先别发"
            } catch {
                errorMessage = error is CancellationError ? "已取消" : error.localizedDescription
                clipboardHint = "你的意思还在，点一下就能重试"
            }
            isWorking = false
            task = nil
            onResult?()
        }
    }

    @discardableResult
    func saveServiceKey(_ raw: String) -> Bool {
        do {
            try DeepSeekCredentialStore.save(raw)
            serviceConfigured = true
            needsServiceSetup = false
            errorMessage = nil
            clipboardHint = "内置 AI 已连接"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func forgetServiceKey() {
        DeepSeekCredentialStore.delete()
        serviceConfigured = false
        clipboardHint = "内置 AI 已断开"
    }

    func dismissServiceSetup() { needsServiceSetup = false }

    func recordUsedReply(_ text: String) {
        ReplyMemory.remember(text)
        clipboardHint = "已放回原输入框，也记住了你的说话习惯"
    }

    func clearStyleMemory() {
        ReplyMemory.clear()
        clipboardHint = "已经忘掉之前学过的回复"
    }

    func loadPreview() {
        cancel()
        let sample = Self.preview(for: selectedSceneID)
        sourceText = sample.source
        plain = sample.plain
        actionItems = sample.actions
        unclear = sample.missing
        intention = sample.intention
        reply = ""
        reportedReplyRisks = []
        errorMessage = nil
        needsServiceSetup = false
        isPreview = true
        clipboardHint = "这是效果预览，不会发送任何消息"
        onResult?()
    }

    private func runPrototypeUnderstanding() {
        errorMessage = nil
        isWorking = true
        clipboardHint = "功能原型 · 正在把话说明白…"
        let message = sourceText
        let sceneID = selectedSceneID
        task = Task {
            try? await Task.sleep(nanoseconds: 420_000_000)
            guard !Task.isCancelled else { return }
            let result = PrototypeEngine.understand(message: message, sceneID: sceneID)
            plain = result.plain
            actionItems = result.actions
            unclear = result.missing
            isPreview = true
            clipboardHint = "功能原型 · Codex 预置场景"
            isWorking = false
            task = nil
            onResult?()
        }
    }

    private func runPrototypeReply() {
        errorMessage = nil
        isWorking = true
        reply = ""
        reportedReplyRisks = []
        clipboardHint = "功能原型 · 正在按你的意思改…"
        let userIntention = intention
        let sceneID = selectedSceneID
        task = Task {
            try? await Task.sleep(nanoseconds: 420_000_000)
            guard !Task.isCancelled else { return }
            let result = PrototypeEngine.composeReply(intention: userIntention, sceneID: sceneID)
            reply = result.reply
            reportedReplyRisks = result.addedCommitments
            clipboardHint = "功能原型 · 没替你多答应"
            isWorking = false
            task = nil
            onResult?()
        }
    }

    private func connectedService(key: String) -> DeepSeekService {
        DeepSeekService(
            apiKey: key,
            endpoint: URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions")!,
            model: "glm-4.5-air"
        )
    }

    func cancel() {
        task?.cancel()
        task = nil
        isWorking = false
    }

    func showStatus(_ text: String) { clipboardHint = text }

    func copyQuickReply(_ text: String) {
        copy(text)
        clipboardHint = "已复制，回到聊天里粘贴"
    }

    func copy(_ text: String) {
        let board = NSPasteboard.general
        board.clearContents()
        if board.setString(text, forType: .string) {
            lastCopiedText = text
            lastClipboardCount = board.changeCount
        }
    }

    func manualHandoff() {
        guard hasUsableMessage else { return }
        copy(PromptBuilder.build(from: sourceText, scene: selectedScene))
        clipboardHint = "已整理好，去 \(selectedProvider.name) 粘贴发送"
        onHandoff?()
        if let app = selectedProvider.runningApplication() {
            app.activate(options: [.activateIgnoringOtherApps])
        } else if let url = selectedProvider.installedApplicationURL() {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else if let url = selectedProvider.webURL {
            NSWorkspace.shared.open(url)
        }
    }

    private static func preview(for sceneID: String) -> (source: String, plain: String, actions: [String], missing: String, intention: String, reply: String) {
        switch sceneID {
        case "client":
            return (
                "我们希望这版整体再有冲击力一点，最好今天能看到，不过细节还是要兼顾，预算暂时先按原来的来。",
                "客户想今天看到一版更有冲击力的修改稿，但没有增加预算。",
                ["确认要改的具体页面", "先给出一版修改稿"],
                "“更有冲击力”的判断标准没有说清。",
                "我可以今天先改首页，但其他页面和新增内容要另排时间。",
                "收到，我今天先调整首页，先按现有预算给您一版。其他页面和新增内容需要另排时间，您先确认一下这次最想加强的是视觉还是文案？"
            )
        case "colleague":
            return (
                "这个需求我已经大概过了一遍，接口这边问题不大，你方便的话把前端也一起接一下，后面联调应该会快很多。",
                "他希望你把前端接入也一起做了，这样后面联调更快。",
                ["确认是否接下前端接入", "约定联调前的交付边界"],
                "他负责到哪一步、你接手哪些内容还没说清。",
                "我可以帮忙接页面，但接口文档和联调还是他负责。",
                "页面接入我可以帮忙，接口文档和后续联调还是你来负责。你把可用接口和字段说明发我，我就开始接。"
            )
        case "girlfriend":
            return (
                "没事，你忙你的吧，反正我说了你也不一定记得。",
                "她不是单纯让你去忙，她在意的是自己说过的事没有被你放在心上。",
                ["先回应她的失落", "说清楚你现在会怎么补救"],
                "她具体希望你记住的是哪件事，需要结合前文确认。",
                "我不是不在乎，是我刚才确实没记住。先道歉，再问清是哪件事，别讲道理。",
                "是我刚才没把你说的事记住，让你觉得自己没被放在心上，对不起。你再告诉我是哪件事，我这次认真记下来，不跟你讲道理。"
            )
        default:
            return (
                "这件事我们还是要从全局视角出发，抓住关键矛盾，尽快形成可落地的方案，同时也要注意节奏和质量。",
                "领导要你尽快拿出一份能执行的方案，但还没说先解决什么、什么时候交。",
                ["找出最关键的问题", "整理一份可执行方案"],
                "截止时间和优先级没有说清。",
                "我先列一个方案框架，今天只给方向，不承诺最终交付时间。",
                "收到，我先把关键问题和方案框架列出来，今天先给您看方向。最终交付时间等方向确认后再定。"
            )
        }
    }
}
