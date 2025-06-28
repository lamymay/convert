import SwiftUI

struct ContentView: View {
    @State private var droppedFiles: [URL] = []
    @State private var filteredFiles: [URL] = []
    @State private var logText: String = ""
    @State private var outputFolder: URL? = nil

    @AppStorage("ffmpegPath") private var ffmpegPath: String = "/opt/homebrew/bin/ffmpeg"
    @State private var showConfigFFmpeg = false

    @State private var currentProcess: Process? = nil
    @State private var isConverting = false

    let formats = [
        "flac", "ogg", "ape", "dff", "dsf", "dts", "wma", "m4a", "aac", "aiff", "alac", "wav", "mp3",
    ]
    @State private var selectedFormats: Set<String> = [
        "wma", "flac", "ogg", "ape", "dff", "dsf", "dts",
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // === 功能块 1
            VStack(alignment: .leading, spacing: 8) {
                Text("① 选择文件/文件夹").bold()
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundColor(.gray)
                        .background(Color.gray.opacity(0.1))
                        .frame(height: 100)
                    Text("拖拽文件或文件夹到这里")
                }
                .onDrop(of: ["public.file-url"], isTargeted: nil, perform: handleDrop(providers:))

                if !droppedFiles.isEmpty {
                    Text("文件列表 (共\(countDirs(in: droppedFiles))个文件夹 \(droppedFiles.count)个文件)")
                        .font(.subheadline)
                        .padding(.top, 4)
                    ScrollView([.vertical, .horizontal]) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(droppedFiles, id: \.self) { url in
                                Text(url.path)
                                    .font(.system(size: 11, design: .monospaced))
                            }
                        }
                    }
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(4)
                }
                Spacer()
            }
            .frame(width: 300)

            // === 功能块 2
            VStack(alignment: .leading, spacing: 8) {
                Text("② 过滤格式").bold()
                ScrollView {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
                        ForEach(formats, id: \.self) { format in
                            Button(action: { toggleFormat(format) }) {
                                Text(format)
                                    .frame(maxWidth: .infinity)
                                    .padding(6)
                                    .background(selectedFormats.contains(format) ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedFormats.contains(format) ? .white : .black)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(8)
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .frame(height: 200)

                if !filteredFiles.isEmpty {
                    Text("过滤后文件 (共\(countDirs(in: filteredFiles))个文件夹 \(filteredFiles.count)个文件)")
                        .font(.subheadline)
                        .padding(.top, 4)
                    ScrollView([.vertical, .horizontal]) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(filteredFiles, id: \.self) { url in
                                Text(url.path)
                                    .font(.system(size: 11, design: .monospaced))
                            }
                        }
                    }
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(4)
                }
                Spacer()
            }
            .frame(width: 300)

            // === 功能块 3
            VStack(alignment: .leading, spacing: 8) {
                Text("③ 执行转换").bold()

                Button("选择输出目录") {
                    pickOutputFolder()
                }

                TextField("输出目录", text: Binding(
                    get: {
                        if let folder = outputFolder {
                            return folder.path
                        } else if let first = droppedFiles.first {
                            return guessDefaultOutputFolder(for: first).path
                        } else {
                            return ""
                        }
                    },
                    set: { newValue in
                        outputFolder = URL(fileURLWithPath: newValue)
                    }
                ))
                .font(.system(size: 12, design: .monospaced))

                Button("配置 FFmpeg 路径") {
                    showConfigFFmpeg = true
                }
                .padding(.top, 6)

                Button("开始转换") {
                    startConvert()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConverting)
                .padding(.top, 12)

                Button("停止转换") {
                    currentProcess?.terminate()
                    appendLog("⚠️ 用户手动停止了转换")
                    isConverting = false
                }
                .buttonStyle(.bordered)
                .disabled(!isConverting)

                ScrollView {
                    TextEditor(text: $logText)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                }
                .frame(height: 250)
                .background(Color.black.opacity(0.05))
                .cornerRadius(4)

                Spacer()
            }
            .frame(width: 400)
        }
        .padding()
        .frame(minWidth: 1100, minHeight: 650)
        .sheet(isPresented: $showConfigFFmpeg) {
            FFmpegConfigView(ffmpegPath: $ffmpegPath)
        }
    }

    // MARK: - 逻辑

    func toggleFormat(_ format: String) {
        if selectedFormats.contains(format) {
            selectedFormats.remove(format)
        } else {
            selectedFormats.insert(format)
        }
        applyFilter()
    }

    func applyFilter() {
        if selectedFormats.isEmpty {
            filteredFiles = droppedFiles
        } else {
            filteredFiles = droppedFiles.filter { selectedFormats.contains($0.pathExtension.lowercased()) }
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        droppedFiles.removeAll()
                        filteredFiles.removeAll()
                        logText = ""
                        var isDir: ObjCBool = false
                        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                        if isDir.boolValue {
                            appendLog("扫描文件夹: \(url.lastPathComponent)")
                            let files = scanFilesRecursively(url)
                            droppedFiles.append(contentsOf: files)
                            appendLog("共扫描到 \(files.count) 个文件")
                        } else {
                            droppedFiles.append(url)
                            appendLog("检测到文件: \(url.lastPathComponent)")
                        }
                        outputFolder = guessDefaultOutputFolder(for: url)
                        applyFilter()
                    }
                }
            }
        }
        return true
    }

    func scanFilesRecursively(_ url: URL) -> [URL] {
        var collected: [URL] = []
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
                   !isDir.boolValue {
                    collected.append(fileURL)
                }
            }
        }
        return collected
    }

    func appendLog(_ text: String) {
        DispatchQueue.main.async {
            logText += text + "\n"
        }
    }

    func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            outputFolder = panel.url
        }
    }

    func countDirs(in files: [URL]) -> Int {
        files.filter {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: $0.path, isDirectory: &isDir)
            return isDir.boolValue
        }.count
    }

    func guessDefaultOutputFolder(for url: URL) -> URL {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue ? url : url.deletingLastPathComponent()
    }

    func startConvert() {
        guard !filteredFiles.isEmpty else {
            appendLog("⚠️ 请选择要转换的文件")
            return
        }
        appendLog("开始转换 \(filteredFiles.count) 个文件，输出目录: \(outputFolder?.path ?? "默认文件夹")")

        isConverting = true

        DispatchQueue.global(qos: .userInitiated).async {
            for file in filteredFiles {
                if !isConverting { break }
                convertFile(file)
            }
            isConverting = false
            appendLog("✅ 所有转换任务结束")
        }
    }

    func convertFile(_ file: URL) {
        let targetFolder = outputFolder ?? file.deletingLastPathComponent()
        let targetBase = file.deletingPathExtension().lastPathComponent
        var targetName = "\(targetBase).m4a"
        let ext = "m4a"

        var finalURL = targetFolder.appendingPathComponent(targetName)
        var counter = 1
        while FileManager.default.fileExists(atPath: finalURL.path) {
            targetName = "\(targetBase)_\(counter).\(ext)"
            finalURL = targetFolder.appendingPathComponent(targetName)
            counter += 1
        }

        appendLog("转换中: \(file.lastPathComponent) → \(finalURL.path)")

        let arguments = [
            "-i", file.path,
            "-c:a", "alac",
            "-map", "0:a",
            "-map_metadata", "0",
            "-movflags", "faststart",
            finalURL.path
        ]

        let process = Process()
        currentProcess = process
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fileHandle in
            if let output = String(data: fileHandle.availableData, encoding: .utf8), !output.isEmpty {
                appendLog(output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                appendLog("✅ 转换完成: \(finalURL.lastPathComponent)")
            } else {
                appendLog("❌ 转换失败，退出码: \(process.terminationStatus)")
            }
        } catch {
            appendLog("❌ 转换失败: \(error.localizedDescription)")
        }

        handle.readabilityHandler = nil
        currentProcess = nil
    }
}
