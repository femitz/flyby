import Foundation
import Testing
@testable import Flyby

/// The updater decides what to install from these, so a mistake here ships the wrong build.
@Suite struct UpdateServiceTests {
    @Test(arguments: [
        ("1.0.1", "1.0.0"),
        ("1.1.0", "1.0.9"),
        ("2.0.0", "1.99.99"),
        ("1.10.0", "1.9.0"),    // numeric, not alphabetical
        ("1.0.0.1", "1.0.0"),   // an extra part beats a missing one
        ("1.2", "1.1.9"),
    ])
    func newerVersionIsDetected(candidate: String, current: String) {
        #expect(UpdateService.isNewer(candidate, than: current))
        #expect(!UpdateService.isNewer(current, than: candidate))
    }

    @Test(arguments: [
        ("1.0.0", "1.0.0"),
        ("1.0", "1.0.0"),       // missing parts count as 0
        ("1.2.3-beta", "1.2.3"), // suffix after the digits is ignored
    ])
    func equalVersionsAreNotNewer(a: String, b: String) {
        #expect(!UpdateService.isNewer(a, than: b))
        #expect(!UpdateService.isNewer(b, than: a))
    }

    @Test func fallbackVersionOfAnUnpackagedBuildIsOlderThanAnyRelease() {
        // `swift run` has no Info.plist version, so `currentVersion` reads "0.0.0".
        #expect(UpdateService.isNewer("0.0.1", than: "0.0.0"))
    }

    @Test func tagPrefixIsDropped() {
        #expect(UpdateService.version(fromTag: "v1.4.2") == "1.4.2")
        #expect(UpdateService.version(fromTag: "1.4.2") == "1.4.2")
    }

    @Test func checksumIsFoundForTheAsset() {
        let sums = """
        AAAA1111  Flyby-macos-arm64.dmg
        BBBB2222  Flyby-macos-arm64.zip

        """
        #expect(UpdateService.expectedChecksum(of: "Flyby-macos-arm64.zip", in: sums) == "bbbb2222")
        #expect(UpdateService.expectedChecksum(of: "Flyby-macos-arm64.dmg", in: sums) == "aaaa1111")
    }

    @Test func checksumHandlesBinaryModeMarkerAndCRLF() {
        // `shasum -b` writes "<hash> *<name>"; files edited on Windows end lines with \r\n.
        let sums = "cccc3333 *Flyby-macos-arm64.zip\r\n"
        #expect(UpdateService.expectedChecksum(of: "Flyby-macos-arm64.zip", in: sums) == "cccc3333")
    }

    @Test func missingAssetHasNoChecksum() {
        #expect(UpdateService.expectedChecksum(of: "Flyby-macos-arm64.zip", in: "dddd4444  Other.zip") == nil)
        #expect(UpdateService.expectedChecksum(of: "Flyby-macos-arm64.zip", in: "") == nil)
    }

    @Test func sha256MatchesTheKnownVector() {
        #expect(UpdateService.sha256Hex(Data("abc".utf8))
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
