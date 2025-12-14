import SwiftUI

class ConversionManager: ObservableObject {
  @Published var isConverting = false
  @Published var successCount = 0
  @Published var failureCount = 0
  @Published var elapsedTime: TimeInterval = 0
  @Published var outputArguments: [String] = [
    "-c:a", "alac", "-map", "0:a", "-map_metadata", "0", "-movflags", "faststart",
  ]

  var currentProcess: Process?
  var ffmpegPath: String
  var logCallback: ((String) -> Void)?

  private var startTime: Date?

  init(ffmpegPath: String) {
    self.ffmpegPath = ffmpegPath
  }

  func startConvert(files: [URL], outputFolder: URL?, completion: @escaping () -> Void) {
    guard !files.isEmpty else {
      logCallback?("⚠️ 请选择要转换的文件")
      completion()
      return
    }
    isConverting = true
    successCount = 0
    failureCount = 0
    elapsedTime = 0
    startTime = Date()

    logCallback?("开始转换 \(files.count) 个文件，输出目录: \(outputFolder?.path ?? "默认文件夹")")

    DispatchQueue.global(qos: .userInitiated).async {
      for file in files {
        if !self.isConverting { break }
        let success = self.convertFile(file, outputFolder: outputFolder)
        DispatchQueue.main.async {
          if success {
            self.successCount += 1
          } else {
            self.failureCount += 1
          }
        }
      }
      DispatchQueue.main.async {
        self.isConverting = false
        if let start = self.startTime {
          self.elapsedTime = Date().timeIntervalSince(start)
        }
        self.logCallback?("✅ 所有转换任务结束")
        completion()
      }
    }
  }

  func stopConvert() {
    currentProcess?.terminate()
    isConverting = false
    logCallback?("⚠️ 用户手动停止了转换")
  }

private func convertFile(_ file: URL, outputFolder: URL?) -> Bool {
    let targetFolder = outputFolder ?? file.deletingLastPathComponent()
    let targetBase = file.deletingPathExtension().lastPathComponent

    // === 根据 outputArguments 推断扩展名 ===
    let ext: String
    if let lastArg = outputArguments.last {
        // 尝试根据最后一个参数推断
        if lastArg.contains(".m4a") || outputArguments.contains("alac") || outputArguments.contains("aac") {
            ext = "m4a"
        } else if outputArguments.contains("pcm_s16le") {
            ext = "wav"
        } else if outputArguments.contains("libmp3lame") {
            ext = "mp3"
        } else {
            // 默认 fallback
            ext = "m4a"
        }
    } else {
        ext = "m4a"
    }

    var targetName = "\(targetBase).\(ext)"
    var finalURL = targetFolder.appendingPathComponent(targetName)
    var counter = 1
    while FileManager.default.fileExists(atPath: finalURL.path) {
        targetName = "\(targetBase)_\(counter).\(ext)"
        finalURL = targetFolder.appendingPathComponent(targetName)
        counter += 1
    }

    logCallback?("转换中: \(file.lastPathComponent) → \(finalURL.path)")

    let arguments = ["-i", file.path] + outputArguments + [finalURL.path]

    let process = Process()
    currentProcess = process
    process.executableURL = URL(fileURLWithPath: ffmpegPath)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    let handle = pipe.fileHandleForReading
    handle.readabilityHandler = { fileHandle in
        if let output = String(data: fileHandle.availableData, encoding: .utf8),
           !output.isEmpty
        {
            self.logCallback?(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    var success = false
    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            logCallback?("✅ 转换完成: \(finalURL.lastPathComponent)")
            success = true
        } else {
            logCallback?("❌ 转换失败，退出码: \(process.terminationStatus)")
        }
    } catch {
        logCallback?("❌ 转换失败: \(error.localizedDescription)")
    }

    handle.readabilityHandler = nil
    currentProcess = nil
    return success
}


}

// MARK: - 安全数组下标扩展
extension Array {
  subscript(safe index: Index) -> Element? {
    (startIndex..<endIndex).contains(index) ? self[index] : nil
  }
}
