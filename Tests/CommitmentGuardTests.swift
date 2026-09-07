import Foundation

@main
struct CommitmentGuardTests {
    static func main() {
        let risks = CommitmentGuard.detect(
            intention: "我先整理一个方向，确认后再排期。",
            reply: "我来负责全部内容，保证明天完成。"
        )
        precondition(risks.contains("我来负责"))
        precondition(risks.contains("全部"))
        precondition(risks.contains("保证"))
        precondition(risks.contains("明天"))

        let allowed = CommitmentGuard.detect(
            intention: "我保证明天给第一版。",
            reply: "好的，我保证明天给第一版。"
        )
        precondition(allowed.isEmpty, "用户明确说过的承诺不能被误拦")

        let negated = CommitmentGuard.detect(
            intention: "现在不能确定。",
            reply: "目前不能保证。"
        )
        precondition(negated.isEmpty, "否定承诺不能被当成新增承诺")

        let purpose = CommitmentGuard.detect(
            intention: "我可以先出第一版。",
            reply: "为了确保方向正确，我可以先出第一版。",
            reported: ["确保"]
        )
        precondition(purpose.isEmpty, "‘为了确保方向正确’不是新增交付承诺")

        let reported = CommitmentGuard.detect(
            intention: "先看看。",
            reply: "可以免费修改。",
            reported: ["免费修改", "免费修改"]
        )
        precondition(reported == ["免费修改"], "模型报告的风险需要合并并去重")

        print("CommitmentGuardTests: 8 checks passed")
    }
}
