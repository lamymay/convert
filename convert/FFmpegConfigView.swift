import SwiftUI

struct FFmpegConfigView: View {
    @Binding var ffmpegPath: String
    @State private var testResult = ""
    @State private var testing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("配置 FFmpeg 路径")
                .font(.title2)
            TextField("FFmpeg 可执行文件路径", text: $ffmpegPath)
                .font(.system(size: 12, design: .monospaced))
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button(action: testFFmpeg) {
                if testing {
                    ProgressView()
                } else {
                    Text("测试 FFmpeg")
                }
            }
            .disabled(testing)

            ScrollView {
                Text(testResult)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(testResult.contains("版本") ? .green : .red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 120)
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)

            Spacer()
        }
        .padding()
        .frame(width: 450, height: 250)
    }

    func testFFmpeg() {
        testing = true
        testResult = ""

        DispatchQueue.global().async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegPath)
            process.arguments = ["-version"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "无法解析输出"
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        testResult = "测试成功！版本信息:\n" + output
                    } else {
                        testResult = "测试失败，ffmpeg 返回错误:\n" + output
                    }
                    testing = false
                }
            } catch {
                DispatchQueue.main.async {
                    testResult = "测试失败，无法执行 ffmpeg:\n\(error.localizedDescription)"
                    testing = false
                }
            }
        }
    }
}
