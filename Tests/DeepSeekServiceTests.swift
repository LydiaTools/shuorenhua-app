import Foundation

@main
struct DeepSeekServiceTests {
    static func main() throws {
        let understanding = try DeepSeekService.decodeUnderstanding("""
        {"plain":"领导要你先交一版方案。","actions":["列框架","确认优先级","交初稿","不应出现"],"missing":"截止时间没说。"}
        """)
        precondition(understanding.plain == "领导要你先交一版方案。")
        precondition(understanding.actions == ["列框架", "确认优先级", "交初稿"], "行动最多保留三项")
        precondition(understanding.missing == "截止时间没说。")

        let fenced = try DeepSeekService.decodeUnderstanding("""
        ```json
        {"plain":"客户想先看首页。","actions":[],"missing":""}
        ```
        """)
        precondition(fenced.plain == "客户想先看首页。", "应兼容偶发的 JSON 代码块")

        let reply = try DeepSeekService.decodeReply("""
        {"reply":"收到，我先整理框架。","added_commitments":["明天交付"]}
        """)
        precondition(reply.reply == "收到，我先整理框架。")
        precondition(reply.addedCommitments == ["明天交付"])

        do {
            _ = try DeepSeekService.decodeUnderstanding("{\"plain\":\"\",\"actions\":[],\"missing\":\"\"}")
            preconditionFailure("空的 plain 必须被拒绝")
        } catch DeepSeekServiceError.invalidResult {
            // Expected.
        }

        print("DeepSeekServiceTests: 10 checks passed")
    }
}
