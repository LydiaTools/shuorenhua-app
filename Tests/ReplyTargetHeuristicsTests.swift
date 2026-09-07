import Foundation

@main
struct ReplyTargetHeuristicsTests {
    static func main() {
        precondition(ReplyTargetHeuristics.score("输入消息") > 0)
        precondition(ReplyTargetHeuristics.score("回复") > 0)
        precondition(ReplyTargetHeuristics.score("Write a message") > 0)
        precondition(ReplyTargetHeuristics.score("Message composer") > 0)
        precondition(ReplyTargetHeuristics.score("搜索联系人") < 0)
        precondition(ReplyTargetHeuristics.score("Search") < 0)
        precondition(ReplyTargetHeuristics.score("地址栏") < 0)
        precondition(ReplyTargetHeuristics.score("正文") == 0)
        print("ReplyTargetHeuristicsTests: 8 checks passed")
    }
}
