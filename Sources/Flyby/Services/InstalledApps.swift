import Foundation

/// An app found in the standard Applications folders.
struct InstalledApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let url: URL
    var id: String { bundleID }
}

/// Lists the apps a user would expect to pick from: /Applications (one folder level deep,
/// for suites like "Microsoft Office"), the system apps and ~/Applications.
enum InstalledApps {
    static func scan() async -> [InstalledApp] {
        await Task.detached(priority: .userInitiated) { scanNow() }.value
    }

    private static func scanNow() -> [InstalledApp] {
        let fm = FileManager.default
        let roots = [
            "/Applications", "/Applications/Utilities",
            "/System/Applications", "/System/Applications/Utilities",
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path,
        ].map { URL(fileURLWithPath: $0) }

        var urls: [URL] = []
        for root in roots {
            guard let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else { continue }
            for child in children {
                if child.pathExtension == "app" {
                    urls.append(child)
                } else if root.path == "/Applications", (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                          child.lastPathComponent != "Utilities" {
                    let nested = (try? fm.contentsOfDirectory(at: child, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
                    urls.append(contentsOf: nested.filter { $0.pathExtension == "app" })
                }
            }
        }

        var seen = Set<String>()
        return urls.compactMap { url -> InstalledApp? in
            guard let bundleID = Bundle(url: url)?.bundleIdentifier, seen.insert(bundleID).inserted else { return nil }
            let name = fm.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            return InstalledApp(bundleID: bundleID, name: name, url: url)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
