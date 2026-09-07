import Foundation

enum ReplyTargetHeuristics {
    private static let blocked = ["搜索", "查找", "地址", "网址", "search", "find", "address", "url"]
    private static let strong = ["输入消息", "发送消息", "回复消息", "发消息", "write a message", "send a message", "message composer", "reply"]
    private static let weak = ["输入", "回复", "消息", "composer", "message"]

    static func score(_ rawLabel: String) -> Int {
        let label = rawLabel.lowercased()
        guard !blocked.contains(where: label.contains) else { return -100 }
        var score = 0
        for term in strong where label.contains(term) { score += 5 }
        for term in weak where label.contains(term) { score += 1 }
        return score
    }
}
