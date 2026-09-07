import AppKit
import AVFoundation
import Foundation
import ScreenCaptureKit

@available(macOS 15.0, *)
final class CaptureDelegate: NSObject, SCRecordingOutputDelegate, SCStreamDelegate {
    var finished = false
    var failure: Error?

    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        print("RECORDING_STARTED")
        fflush(stdout)
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        failure = error
        finished = true
    }

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        finished = true
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        failure = error
        finished = true
    }
}

@main
struct CaptureProduct {
    @MainActor
    static func main() async throws {
        _ = NSApplication.shared
        NSApplication.shared.setActivationPolicy(.prohibited)
        let arguments = CommandLine.arguments
        guard arguments.count >= 3 else {
            print("usage: capture-product screenshot|record output [seconds]")
            return
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        let windows = content.windows.filter {
            $0.owningApplication?.bundleIdentifier == "com.lydiahub.shuorenhua" &&
            ($0.title?.contains("说人话") ?? false) && $0.frame.width > 300 && $0.frame.height > 300
        }
        guard let window = windows.max(by: { left, right in
            let leftArea: CGFloat = left.frame.width * left.frame.height
            let rightArea: CGFloat = right.frame.width * right.frame.height
            return leftArea < rightArea
        }) else {
            throw NSError(domain: "capture", code: 1, userInfo: [NSLocalizedDescriptionKey: "说人话主窗口没有打开"])
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = max(840, Int(window.frame.width * 2))
        configuration.height = max(1200, Int(window.frame.height * 2))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.queueDepth = 3
        configuration.showsCursor = arguments[1] == "record"
        configuration.showMouseClicks = arguments[1] == "record"
        configuration.capturesAudio = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.ignoreGlobalClipSingleWindow = true
        configuration.includeChildWindows = false

        let outputURL = URL(fileURLWithPath: arguments[2])
        if arguments[1] == "screenshot" {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            let bitmap = NSBitmapImageRep(cgImage: image)
            guard let data = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
                throw NSError(domain: "capture", code: 2, userInfo: [NSLocalizedDescriptionKey: "截图编码失败"])
            }
            try data.write(to: outputURL)
            print(outputURL.path)
            return
        }

        let seconds = Double(arguments.count > 3 ? arguments[3] : "10") ?? 10
        let delegate = CaptureDelegate()
        let stream = SCStream(filter: filter, configuration: configuration, delegate: delegate)
        let recordingConfiguration = SCRecordingOutputConfiguration()
        recordingConfiguration.outputURL = outputURL
        recordingConfiguration.videoCodecType = .h264
        recordingConfiguration.outputFileType = .mov
        let recording = SCRecordingOutput(configuration: recordingConfiguration, delegate: delegate)
        try stream.addRecordingOutput(recording)
        try await stream.startCapture()
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        try await stream.stopCapture()
        for _ in 0..<100 where !delegate.finished {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        if let failure = delegate.failure { throw failure }
        guard delegate.finished else {
            throw NSError(domain: "capture", code: 3, userInfo: [NSLocalizedDescriptionKey: "录屏收尾超时"])
        }
        print("RECORDING_FINISHED \(outputURL.path)")
    }
}
