import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @State private var droppedFiles: [URL] = []
  @State private var filteredFiles: [URL] = []
  @State private var logText: String = ""
  @State private var outputFolder: URL? = nil

  @AppStorage("ffmpegPath") private var ffmpegPath: String = "/opt/homebrew/bin/ffmpeg"
  @State private var showConfigFFmpeg = false

  @State private var selectedFormats: Set<String> = [
    "flac", "ogg", "ape", "dff", "dsf", "dts",
  ]

  let formats = [
    "flac", "ogg", "ape", "dff", "dsf", "dts", "wma", "m4a", "aac", "aiff", "alac", "wav", "mp3",
  ]

  @StateObject private var conversionManager = ConversionManager(
    ffmpegPath: "/opt/homebrew/bin/ffmpeg")

  @State private var showSummaryAlert = false

  @State private var selectedPreset: String = "ALAC"

  var body: some View {
    HStack(alignment: .top, spacing: 16) {

      // === 功能块 1 选择文件 ===
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
          Text(
            "文件列表 (共\(FileManagerHelper.countDirs(in: droppedFiles))个文件夹 \(droppedFiles.count)个文件)"
          ).font(.subheadline).padding(.top, 4)

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

      // === 功能块 2 过滤格式 ===
      VStack(alignment: .leading, spacing: 8) {
        Text("② 过滤格式").bold()
        ScrollView {
          LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
            ForEach(formats, id: \.self) { format in
              Button(action: { toggleFormat(format) }) {
                Text(format)
                  .frame(maxWidth: .infinity)
                  .padding(6)
                  .background(
                    selectedFormats.contains(format) ? Color.blue : Color.gray.opacity(0.2)
                  )
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
          Text(
            "过滤后文件 (共\(FileManagerHelper.countDirs(in: filteredFiles))个文件夹 \(filteredFiles.count)个文件)"
          ).font(.subheadline).padding(.top, 4)

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

      // === 功能块 3 转换及日志 ===
      VStack(alignment: .leading, spacing: 8) {
        Text("③ 格式转换到ALAC（Apple Lossless）").bold()

        Button("选择输出目录") {
          pickOutputFolder()
        }

        TextField(
          "输出目录",
          text: Binding(
            get: {
              if let folder = outputFolder {
                return folder.path
              } else if let first = droppedFiles.first {
                return FileManagerHelper.guessDefaultOutputFolder(for: first).path
              } else {
                return ""
              }
            },
            set: { newValue in
              outputFolder = URL(fileURLWithPath: newValue)
            }
          )
        ).font(.system(size: 12, design: .monospaced))

        VStack(alignment: .leading, spacing: 4) {
          Text("输出参数 (FFmpeg)").bold()
          HStack {

            Button("ALAC") {
              conversionManager.outputArguments = [
                "-map", "0:a",
                "-c:a", "alac",
                "-map", "0:v?",
                "-c:v", "copy",
                "-map_metadata", "0",
                "-movflags", "faststart",
              ]
              selectedPreset = "ALAC"
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedPreset == "ALAC" ? .blue : .gray)

            Button("AAC") {
              conversionManager.outputArguments = [
                "-map", "0:a",
                "-c:a", "aac",
                "-b:a", "192k",
                "-map", "0:v?",
                "-c:v", "mjpeg",
                "-map_metadata", "0",
                "-movflags", "faststart",
              ]
              selectedPreset = "AAC"
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedPreset == "AAC" ? .blue : .gray)

            Button("WAV") {
              conversionManager.outputArguments = [
                "-map", "0:a",
                "-c:a", "pcm_s16le",
                "-map_metadata", "0",
                // 不要拷贝视频封面，否则wav容器挂掉
              ]
              selectedPreset = "WAV"
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedPreset == "WAV" ? .blue : .gray)

            Button("MP3") {
              conversionManager.outputArguments = [
                "-c:a", "libmp3lame", "-b:a", "192k", "-map_metadata", "0",
              ]
              selectedPreset = "MP3"

            }
            .buttonStyle(.borderedProminent)
            .tint(selectedPreset == "MP3" ? .blue : .gray)

          }
          .font(.subheadline)
          .buttonStyle(.bordered)

          TextEditor(
            text: Binding(
              get: { conversionManager.outputArguments.joined(separator: " ") },
              set: { newValue in
                conversionManager.outputArguments =
                  newValue
                  .split(separator: " ")
                  .map { String($0) }
              }
            )
          )
          .font(.system(size: 11, design: .monospaced))
          .frame(height: 60)
          .border(Color.gray.opacity(0.5))
        }
        .padding(.bottom, 8)
        HStack(spacing: 12) {
          Button("配置&测试 FFmpeg ") {
            showConfigFFmpeg = true
          }
          Button("开始转换") {
            conversionManager.ffmpegPath = ffmpegPath
            conversionManager.startConvert(files: filteredFiles, outputFolder: outputFolder) {
              showSummaryAlert = true
            }
          }
          .buttonStyle(.borderedProminent)
          .disabled(conversionManager.isConverting)

          Button("停止转换") {
            conversionManager.stopConvert()
          }
          .buttonStyle(.bordered)
          .disabled(!conversionManager.isConverting)

        }
        .padding(.top, 12)

        HStack {
          Text("耗时: \(String(format: "%.2f", conversionManager.elapsedTime)) 秒")
          Spacer()
          Text("成功: \(conversionManager.successCount)")
          Spacer()
          Text("失败: \(conversionManager.failureCount)")
        }
        .font(.subheadline)
        .padding(.vertical, 6)

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
    .alert("转换完成", isPresented: $showSummaryAlert) {
      Button("确定") {}
    } message: {
      Text(
        """
        转换完成
        总耗时: \(String(format: "%.2f", conversionManager.elapsedTime)) 秒
        成功: \(conversionManager.successCount)
        失败: \(conversionManager.failureCount)
        """)
    }
    .onChange(of: droppedFiles) { _, _ in
      applyFilter()
    }
    .onChange(of: selectedFormats) { _, _ in
      applyFilter()
    }
    .onAppear {
      conversionManager.logCallback = { log in
        DispatchQueue.main.async {
          logText += log + "\n"
        }
      }
    }
  }

  // MARK: - 逻辑

  func toggleFormat(_ format: String) {
    if selectedFormats.contains(format) {
      selectedFormats.remove(format)
    } else {
      selectedFormats.insert(format)
    }
  }

  func applyFilter() {
    if selectedFormats.isEmpty {
      filteredFiles = droppedFiles
    } else {
      filteredFiles = droppedFiles.filter {
        selectedFormats.contains($0.pathExtension.lowercased())
      }
    }
  }

  func handleDrop(providers: [NSItemProvider]) -> Bool {
    for provider in providers {
      provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
        if let data = item as? Data,
          let url = URL(dataRepresentation: data, relativeTo: nil)
        {
          DispatchQueue.main.async {
            droppedFiles.removeAll()
            filteredFiles.removeAll()
            logText = ""
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            if isDir.boolValue {
              appendLog("扫描文件夹: \(url.lastPathComponent)")
              let files = FileManagerHelper.scanFilesRecursively(url)
              droppedFiles.append(contentsOf: files)
              appendLog("共扫描到 \(files.count) 个文件")
            } else {
              droppedFiles.append(url)
              appendLog("检测到文件: \(url.lastPathComponent)")
            }
            outputFolder = FileManagerHelper.guessDefaultOutputFolder(for: url)
            applyFilter()
          }
        }
      }
    }
    return true
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
    panel.allowedContentTypes = [.folder]
    if panel.runModal() == .OK {
      outputFolder = panel.url
    }
  }
}
