import Foundation

@main
struct ReplyMemoryTests {
    static func main() {
        let suite = "com.lydiahub.shuorenhua.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        ReplyMemory.clear(defaults: defaults)
        precondition(ReplyMemory.load(defaults: defaults).isEmpty)

        ReplyMemory.remember("  收到，我先看一下。  ", defaults: defaults)
        precondition(ReplyMemory.load(defaults: defaults) == ["收到，我先看一下。"])

        ReplyMemory.remember("收到，我先看一下。", defaults: defaults)
        precondition(ReplyMemory.load(defaults: defaults).count == 1, "重复回复不能重复学习")

        for index in 0..<10 { ReplyMemory.remember("回复 \(index)", defaults: defaults) }
        let values = ReplyMemory.load(defaults: defaults)
        precondition(values.count == 8, "本机只保留最近八条")
        precondition(values.first == "回复 9")

        ReplyMemory.clear(defaults: defaults)
        precondition(ReplyMemory.load(defaults: defaults).isEmpty)

        print("ReplyMemoryTests: 6 checks passed")
    }
}
