import AppKit
import Foundation

struct AIProvider: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifiers: [String]
    let webURL: URL?
    let canBeAutomaticDefault: Bool
    let requiresOrganizationAI: Bool

    static let all: [AIProvider] = [
        AIProvider(
            id: "feishu",
            name: "豆包",
            bundleIdentifiers: ["com.bytedance.Lark", "com.bytedance.Feishu"],
            webURL: URL(string: "https://www.feishu.cn/next/messenger/"),
            canBeAutomaticDefault: false,
            requiresOrganizationAI: true
        ),
        AIProvider(
            id: "dingtalk",
            name: "钉钉 AI",
            bundleIdentifiers: ["com.alibaba.DingTalkMac", "com.alibaba.DingTalk"],
            webURL: URL(string: "https://www.dingtalk.com/"),
            canBeAutomaticDefault: false,
            requiresOrganizationAI: true
        ),
        AIProvider(
            id: "workbuddy",
            name: "WorkBuddy",
            bundleIdentifiers: ["com.workbuddy.workbuddy"],
            webURL: nil,
            canBeAutomaticDefault: false,
            requiresOrganizationAI: false
        ),
        AIProvider(
            id: "chatgpt",
            name: "ChatGPT",
            bundleIdentifiers: ["com.openai.chat", "com.openai.chatgpt"],
            webURL: URL(string: "https://chatgpt.com/"),
            canBeAutomaticDefault: false,
            requiresOrganizationAI: false
        ),
    ]

    func installedApplicationURL(workspace: NSWorkspace = .shared) -> URL? {
        bundleIdentifiers.lazy.compactMap { workspace.urlForApplication(withBundleIdentifier: $0) }.first
    }

    func isInstalled(workspace: NSWorkspace = .shared) -> Bool {
        installedApplicationURL(workspace: workspace) != nil
    }

    func runningApplication() -> NSRunningApplication? {
        bundleIdentifiers.lazy.compactMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0).first
        }.first
    }
}
