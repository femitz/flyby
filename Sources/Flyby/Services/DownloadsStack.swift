import AppKit

struct RecentDownload: Identifiable, Hashable {
    let url: URL
    let added: Date
    var id: URL { url }
}

/// The Downloads folder for the Flyby Dock and its latest files.
///
/// Reading the folder asks for the Downloads permission the first time (macOS protects it);
/// if it is denied, `recent()` returns nil and the popover says so.
enum DownloadsStack {
    static let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")

    private static let limit = 12

    /// Newest first, by the date each item landed in Downloads.
    static func recent() -> [RecentDownload]? {
        let keys: [URLResourceKey] = [.addedToDirectoryDateKey, .creationDateKey]
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ) else { return nil }

        func added(_ url: URL) -> Date {
            let values = try? url.resourceValues(forKeys: Set(keys))
            return values?.addedToDirectoryDate ?? values?.creationDate ?? .distantPast
        }
        return items
            .filter { !["download", "crdownload", "part"].contains($0.pathExtension) }   // still downloading
            .map { RecentDownload(url: $0, added: added($0)) }
            .sorted { $0.added > $1.added }
            .prefix(limit)
            .map { $0 }
    }
}
