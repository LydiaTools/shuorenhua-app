import Foundation

@main
struct PrototypeEngineTests {
    static func main() {
        for scene in WorkplaceScene.all {
            let result = PrototypeEngine.understand(message: "测试消息", sceneID: scene.id)
            precondition(!result.plain.isEmpty)
            precondition(!result.actions.isEmpty && result.actions.count <= 3)
            precondition(!result.missing.isEmpty)

            let reply = PrototypeEngine.composeReply(intention: "先给方向，不承诺最终时间", sceneID: scene.id)
            precondition(!reply.reply.isEmpty)
            precondition(reply.addedCommitments.isEmpty)
        }
        print("PrototypeEngineTests: 20 checks passed")
    }
}
