import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: ClipboardModel
    let sendReply: (String, Bool, Bool) -> Void
    let startOver: () -> Void

    @State private var showHelp = false
    @State private var showSettings = false
    @State private var showServiceSetup = false
    @State private var serviceKey = ""

    private let purple = Color(red: 0.43, green: 0.29, blue: 0.88)
    private let pink = Color(red: 0.95, green: 0.34, blue: 0.52)

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            header
            scenePicker

            Group {
                if model.hasReply {
                    replyStage
                } else if model.hasResult {
                    understandingStage
                } else {
                    inputStage
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            statusLine
            Divider()
            bottomBar
        }
        .padding(18)
        .frame(width: 420, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(model.$needsServiceSetup) { needed in
            if needed { showServiceSetup = true }
        }
        .sheet(isPresented: $showServiceSetup, onDismiss: model.dismissServiceSetup) {
            serviceSetup
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let url = Bundle.main.url(forResource: "LydiaLogo", withExtension: "png"),
               let logo = NSImage(contentsOf: url) {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("LYDIA 脑洞小工具")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .tracking(0.65)
                Text("说人话")
                    .font(.system(size: 21, weight: .bold))
            }
            Spacer()
            Button {
                if let url = URL(string: "https://afdian.com/a/lydiahub2026") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                    Text("投喂脑洞").fixedSize()
                }
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(pink)
                .padding(.horizontal, 8)
                .frame(height: 25)
                .background(pink.opacity(0.10), in: Capsule())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("投喂一下，继续脑洞大开")

            Button { showSettings.toggle() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .foregroundStyle(.secondary)
            .accessibilityLabel("设置")
            .popover(isPresented: $showSettings, arrowEdge: .bottom) { settingsContent }
        }
    }

    private var scenePicker: some View {
        HStack(spacing: 6) {
            ForEach(WorkplaceScene.all) { scene in
                Button {
                    model.selectScene(scene.id)
                } label: {
                    Text(scene.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(scene.id == model.selectedSceneID ? Color.white : Color.secondary)
                        .padding(.horizontal, 11)
                        .frame(height: 27)
                        .background(
                            scene.id == model.selectedSceneID ? purple : Color.secondary.opacity(0.08),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .help("换个场景，听话和回话的重点也会跟着变")
    }

    private var inputStage: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.selectedScene.name + model.selectedScene.firstLineTail)
                Text(model.selectedScene.secondLine)
            }
            .font(.system(size: 20, weight: .bold))
            .lineSpacing(2)

            Text("把那句每个字都认识、连起来却听不懂的话放进来。")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)

            textEditor(
                text: $model.sourceText,
                placeholder: "粘贴对方的原话…",
                height: 186,
                label: "对方的原话"
            )

            primaryButton("说白了", systemImage: "quote.bubble.fill") {
                model.understand()
            }
            .disabled(!model.hasUsableMessage || model.isWorking)
        }
    }

    private var understandingStage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    stageLabel("说白了", icon: "text.bubble.fill", color: purple)
                    Spacer()
                    Button("换一句") { startOver() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                resultCard {
                    Text(model.plain)
                        .font(.system(size: 15, weight: .semibold))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                }

                if !model.actionItems.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        stageLabel("要做的事", icon: "checkmark.circle.fill", color: .green)
                        resultCard {
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(Array(model.actionItems.enumerated()), id: \.offset) { index, item in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 18, height: 18)
                                            .background(Color.green, in: Circle())
                                        Text(item)
                                            .font(.system(size: 13.5))
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                }

                if !model.unclear.isEmpty {
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: "questionmark.bubble.fill")
                            .foregroundStyle(Color.orange)
                        Text("动手前最好问：\(model.unclear)")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 3)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("其实想回什么？")
                        .font(.system(size: 13, weight: .semibold))
                    textEditor(
                        text: $model.intention,
                        placeholder: "不用组织语言，直接说你的大白话…",
                        height: 72,
                        label: "我真正想回的意思"
                    )
                }

                primaryButton("按我的意思改一下", systemImage: "wand.and.stars") {
                    model.composeReply()
                }
                .disabled(model.intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isWorking)
            }
            .padding(.trailing, 2)
        }
    }

    private var replyStage: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                stageLabel("按你的意思", icon: "bubble.left.and.text.bubble.right.fill", color: purple)
                Spacer()
                Button("改我的意思") {
                    model.reply = ""
                    model.showStatus("你的原意还在，改完再生成")
                }
                .buttonStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            }

            textEditor(
                text: $model.reply,
                placeholder: "正在生成…",
                height: 190,
                label: "生成的回复"
            )

            if model.replyRisks.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(Color.green)
                    Text("没替你多答应")
                        .font(.system(size: 12, weight: .semibold))
                    Text("时间、范围、责任都按你的原意")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.shield.fill")
                        Text("先别发，回复里多答应了：")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.orange)
                    Text(model.replyRisks.joined(separator: "、"))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Button("按我的意思重写") { model.composeReply(removingRisks: true) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(10)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            primaryButton("放回原输入框", systemImage: "arrow.uturn.backward.circle.fill") {
                sendReply(model.reply, false, true)
            }
            .disabled(model.replyRisks.isEmpty == false || model.isWorking)

            Text("先放进去，不会替你按发送。你用过的回复只在本机学语气。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if model.isWorking {
            HStack(spacing: 7) {
                ProgressView().controlSize(.small)
                Text(model.clipboardHint)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
        } else if let error = model.errorMessage, !error.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                Text(error)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Color.orange)
        } else if model.hasReply, !model.replyRisks.isEmpty {
            Text("发现了你没说过的承诺，先别发")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.orange)
                .lineLimit(2)
        } else if !model.clipboardHint.isEmpty {
            Text(model.clipboardHint)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button("好的，收到") { sendReply("好的，收到", true, false) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("不用 AI；能确认原输入框时直接发送，否则只复制")

            Menu {
                Button("收到，我先看一下") { sendReply("收到，我先看一下", true, false) }
                Button("我确认下再回你") { sendReply("我确认下再回你", true, false) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("更多不用 AI 的快捷回复")

            Spacer()

            Menu {
                ForEach(AIProvider.all) { provider in
                    Button {
                        model.selectedProviderID = provider.id
                        model.manualHandoff()
                    } label: {
                        Text("换用 \(provider.name)")
                    }
                }
            } label: {
                Label("换用别的 AI", systemImage: "arrow.up.forward.app")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(!model.hasUsableMessage || model.isWorking)
        }
    }

    private var serviceSetup: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                    .font(.system(size: 19))
                    .foregroundStyle(purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("连接内置 AI")
                        .font(.system(size: 16, weight: .bold))
                    Text("开发验证设置，正式版不会让用户填密钥")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }

            SecureField("智谱 API Key", text: $serviceKey)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("继续使用功能原型") {
                    model.loadPreview()
                    showServiceSetup = false
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("连接") {
                    if model.saveServiceKey(serviceKey) {
                        serviceKey = ""
                        showServiceSetup = false
                        model.understand()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(purple)
                .disabled(serviceKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置")
                .font(.system(size: 15, weight: .bold))

            HStack {
                Circle()
                    .fill(model.serviceConfigured ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(model.serviceConfigured ? "内置 AI 已连接" : "功能原型 · Codex 预置场景")
                Spacer()
                Button(model.serviceConfigured ? "重新连接" : "连接") {
                    showSettings = false
                    showServiceSetup = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("我的说话习惯")
                    Text("已在本机记住 \(model.learnedReplyCount) 条用过的回复")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("清除") { model.clearStyleMemory() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.learnedReplyCount == 0)
            }

            Divider()
            Button("使用说明") { showHelp.toggle() }
                .buttonStyle(.plain)
            if model.serviceConfigured {
                Button("断开开发用 AI") { model.forgetServiceKey() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.red)
            }
        }
        .font(.system(size: 12))
        .padding(16)
        .frame(width: 292)
        .popover(isPresented: $showHelp, arrowEdge: .trailing) { helpContent }
    }

    private var helpContent: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("三步就够了")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
            Text("复制一段消息，按 ⌃⌥R。")
            Text("先点“说白了”，再用大白话写下自己真正想回什么。")
            Text("生成后会检查有没有替你多答应；确认无误，再放回原输入框。")
            Divider()
            Text("固定快捷回复不用 AI。无法确认原聊天框时只复制，不会乱发。")
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(17)
        .frame(width: 300)
    }

    private func textEditor(text: Binding<String>, placeholder: String, height: CGFloat, label: String) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: text)
                .font(.system(size: 13.5))
                .scrollContentBackground(.hidden)
                .padding(7)
                .accessibilityLabel(label)
                .disabled(model.isWorking)
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: height)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.14)))
    }

    private func resultCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.08)))
    }

    private func stageLabel(_ title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(color)
    }

    private func primaryButton(_ title: String, systemImage: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(purple, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
