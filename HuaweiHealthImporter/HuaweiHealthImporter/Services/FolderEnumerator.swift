import Foundation

/// Walks a user-picked folder tree and classifies JSON files by parent-folder name.
enum FolderEnumerator {

    enum FileKind {
        case healthDetail       // "Health detail data & description"
        case sportPerMinute     // "Sport per minute merged data & description"
        case motionPath         // "Motion path detail data & description" — seam for v2 (GPS/workouts)
        case unknown
    }

    struct ClassifiedFile {
        let url: URL
        let kind: FileKind
    }

    /// Recursively enumerates all `.json` files under `folder`, classifying each
    /// by the name of its immediate parent folder.
    static func enumerate(folder: URL) -> [ClassifiedFile] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [ClassifiedFile] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "json" else { continue }
            let parentName = fileURL.deletingLastPathComponent().lastPathComponent.lowercased()
            let kind = classify(parentFolderName: parentName)
            results.append(ClassifiedFile(url: fileURL, kind: kind))
        }

        // Process health-detail files before sport files for better progress ordering
        return results.sorted { a, b in
            kindOrder(a.kind) < kindOrder(b.kind)
        }
    }

    private static func classify(parentFolderName name: String) -> FileKind {
        if name.contains("health detail") { return .healthDetail }
        if name.contains("sport per minute") { return .sportPerMinute }
        if name.contains("motion path") { return .motionPath }
        return .unknown
    }

    private static func kindOrder(_ kind: FileKind) -> Int {
        switch kind {
        case .healthDetail:   return 0
        case .sportPerMinute: return 1
        case .motionPath:     return 2
        case .unknown:        return 3
        }
    }
}
