import Foundation
import SwiftUI

class FileManagerHelper {
    static func scanFilesRecursively(_ url: URL) -> [URL] {
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

    static func countDirs(in files: [URL]) -> Int {
        files.filter {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: $0.path, isDirectory: &isDir)
            return isDir.boolValue
        }.count
    }

    static func guessDefaultOutputFolder(for url: URL) -> URL {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue ? url : url.deletingLastPathComponent()
    }

    static func pickFolder(completion: @escaping (URL?) -> Void) {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            if panel.runModal() == .OK {
                completion(panel.url)
            } else {
                completion(nil)
            }
        }
    }
}
