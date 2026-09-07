import Foundation

/// Codex-authored scenario fixtures used only for the market-validation build.
/// The UI and every transition are real; model inference is replaced by these
/// local examples until a paid backend is connected.
enum PrototypeEngine {
    static func understand(message: String, sceneID: String) -> UnderstandingResult {
        switch sceneID {
        case "client":
            return UnderstandingResult(
                plain: "客户想尽快看到一版更有冲击力的修改稿，但预算仍按原来的来。",
                actions: ["确认这次要改的具体页面", "先给出一版修改稿"],
                missing: "“更有冲击力”的判断标准没有说清。"
            )
        case "colleague":
            return UnderstandingResult(
                plain: "同事希望你把前端接入也一起做了，这样后面联调会更快。",
                actions: ["确认是否接下前端接入", "约定双方的联调边界"],
                missing: "他负责到哪一步、你接手哪些内容还没说清。"
            )
        case "girlfriend":
            return UnderstandingResult(
                plain: "她不是单纯让你去忙，她在意的是自己说过的事没有被你放在心上。",
                actions: ["先回应她的失落", "说清楚你现在会怎么补救"],
                missing: "她具体希望你记住的是哪件事，需要结合前文确认。"
            )
        default:
            return UnderstandingResult(
                plain: "领导要你尽快拿出一份能执行的方案，但还没说先解决什么、什么时候交。",
                actions: ["找出最关键的问题", "整理一份可执行方案"],
                missing: "截止时间和优先级没有说清。"
            )
        }
    }

    static func composeReply(intention: String, sceneID: String) -> GeneratedReplyResult {
        switch sceneID {
        case "client":
            return GeneratedReplyResult(
                reply: "收到，我今天先调整首页，按现有预算给您一版。其他页面和新增内容需要另排时间，您先确认一下这次最想加强的是视觉还是文案？",
                addedCommitments: []
            )
        case "colleague":
            return GeneratedReplyResult(
                reply: "页面接入我可以帮忙，接口文档和后续联调还是你来负责。你把可用接口和字段说明发我，我就开始接。",
                addedCommitments: []
            )
        case "girlfriend":
            return GeneratedReplyResult(
                reply: "是我刚才没把你说的事记住，让你觉得自己没被放在心上，对不起。你再告诉我是哪件事，我这次认真记下来，不跟你讲道理。",
                addedCommitments: []
            )
        default:
            let normalized = intention.trimmingCharacters(in: .whitespacesAndNewlines)
            let reply = normalized.contains("今天")
                ? "收到，我先把关键问题和方案框架列出来，今天先给您看方向。最终交付时间等方向确认后再定。"
                : "收到，我先把关键问题和方案框架列出来，先给您看方向。最终交付时间等方向确认后再定。"
            return GeneratedReplyResult(reply: reply, addedCommitments: [])
        }
    }
}
