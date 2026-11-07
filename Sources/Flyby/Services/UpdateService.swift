import AppKit
import CryptoKit
import Foundation

/// Checks GitHub Releases for a newer Flyby, and installs it in place when the user asks.
///
/// - Checks automatically every `checkInterval` (5 h) while the app runs, and on launch when
///   the last check is older than that. It never installs by itself.
/// - Installing downloads the release zip, verifies it against `SHA256SUMS`, then hands over to a
///   small shell helper that waits for Flyby to quit, swaps the bundle and relaunches it.
@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case downloading
        case installing
        case failed(Failure)
    }

    /// Kept as data, not text, so the message follows the language when it changes.
    enum Failure: Equatable {
        case check
        case notInstalled
        case noPermission(folder: String)
        case install(UpdateError)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastCheck: Date?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    var updateAvailable: Bool {
        if case .available = state { return true }
        return false
    }

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    private struct Release {
        let version: String
        let zipURL: URL
        let checksumsURL: URL?
    }

    private static let repository = "femitz/flyby"
    private static let assetName = "Flyby-macos-arm64.zip"
    private static let checkInterval: TimeInterval = 5 * 60 * 60
    private static let lastCheckKey = "updateLastCheck"

    private var pending: Release?
    private var timer: Timer?

    private init() {
        lastCheck = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
    }

    /// Starts the background schedule. The timer ticks often and compares against the stored
    /// timestamp, so the 5 h cadence survives sleep and relaunches.
    func startAutomaticChecks() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)   // let the app settle first
            self?.checkIfDue()
        }
    }

    private func checkIfDue() {
        guard !isBusy, !updateAvailable else { return }
        if let lastCheck, Date().timeIntervalSince(lastCheck) < Self.checkInterval { return }
        Task { await check() }
    }

    // MARK: - Check

    func check() async {
        guard !isBusy else { return }
        state = .checking
        do {
            let release = try await fetchLatestRelease()
            lastCheck = Date()
            UserDefaults.standard.set(lastCheck, forKey: Self.lastCheckKey)
            if Self.isNewer(release.version, than: currentVersion) {
                pending = release
                state = .available(version: release.version)
            } else {
                pending = nil
                state = .upToDate
            }
        } catch {
            state = .failed(.check)
        }
    }

    private func fetchLatestRelease() async throws -> Release {
        let url = URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest")!
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Flyby/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.badResponse }

        struct Payload: Decodable {
            struct Asset: Decodable { let name: String; let browser_download_url: URL }
            let tag_name: String
            let assets: [Asset]
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let zip = payload.assets.first(where: { $0.name == Self.assetName }) else {
            throw UpdateError.missingAsset
        }
        let sums = payload.assets.first(where: { $0.name == "SHA256SUMS" })
        let version = payload.tag_name.hasPrefix("v") ? String(payload.tag_name.dropFirst()) : payload.tag_name
        return Release(version: version, zipURL: zip.browser_download_url, checksumsURL: sums?.browser_download_url)
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ s: String) -> [Int] { s.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 } }
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: - Install

    func install() async {
        guard case .available = state, let release = pending else { return }

        let appURL = Bundle.main.bundleURL
        guard appURL.pathExtension == "app" else {
            state = .failed(.notInstalled)
            return
        }
        guard FileManager.default.isWritableFile(atPath: appURL.deletingLastPathComponent().path) else {
            state = .failed(.noPermission(folder: appURL.deletingLastPathComponent().path))
            return
        }

        state = .downloading
        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent("flyby-update-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

            let (zipTemp, _) = try await URLSession.shared.download(from: release.zipURL)
            let zipFile = workDir.appendingPathComponent(Self.assetName)
            try FileManager.default.moveItem(at: zipTemp, to: zipFile)

            try await verifyChecksum(of: zipFile, release: release)

            state = .installing
            let extractDir = workDir.appendingPathComponent("extracted")
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
            try Self.run("/usr/bin/ditto", ["-x", "-k", zipFile.path, extractDir.path])

            let newApp = extractDir.appendingPathComponent("Flyby.app")
            guard FileManager.default.fileExists(atPath: newApp.path) else { throw UpdateError.badArchive }
            try Self.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newApp.path])

            try launchReplacement(newApp: newApp, target: appURL, workDir: workDir)
            NSApp.terminate(nil)
        } catch {
            try? FileManager.default.removeItem(at: workDir)
            state = .failed(.install((error as? UpdateError) ?? .other(error.localizedDescription)))
        }
    }

    private func verifyChecksum(of file: URL, release: Release) async throws {
        guard let sumsURL = release.checksumsURL else { return }   // older releases may lack it
        let (data, _) = try await URLSession.shared.data(from: sumsURL)
        let text = String(decoding: data, as: UTF8.self)
        guard let line = text.split(separator: "\n").first(where: { $0.hasSuffix(Self.assetName) }),
              let expected = line.split(separator: " ").first
        else { throw UpdateError.checksumMismatch }

        let digest = SHA256.hash(data: try Data(contentsOf: file, options: .mappedIfSafe))
        let actual = digest.map { String(format: "%02x", $0) }.joined()
        guard actual == expected.lowercased() else { throw UpdateError.checksumMismatch }
    }

    /// Detached helper: wait for this process to exit, swap the bundle, relaunch, clean up.
    private func launchReplacement(newApp: URL, target: URL, workDir: URL) throws {
        let script = workDir.appendingPathComponent("replace.sh")
        let contents = """
        #!/bin/bash
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        rm -rf "$3.old"
        mv "$3" "$3.old" || exit 1
        if ditto "$2" "$3"; then
          rm -rf "$3.old"
        else
          rm -rf "$3"; mv "$3.old" "$3"
        fi
        xattr -dr com.apple.quarantine "$3" 2>/dev/null
        open "$3"
        rm -rf "$4"
        """
        try contents.write(to: script, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path, String(ProcessInfo.processInfo.processIdentifier), newApp.path, target.path, workDir.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    @discardableResult
    private static func run(_ path: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.commandFailed(tool: URL(fileURLWithPath: path).lastPathComponent) }
        return process.terminationStatus
    }

    /// Why an install failed. Worded by `L10n`; `other` carries the system's own message.
    enum UpdateError: Error, Equatable {
        case badResponse, missingAsset, badArchive, checksumMismatch, commandFailed(tool: String), other(String)
    }
}
