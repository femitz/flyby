import Foundation
import Testing
@testable import Flyby

@Suite struct DockProfileTests {
    private func item(_ id: String) -> DockItem { DockItem(bundleID: id, path: "/Applications/\(id).app") }

    private func profile(_ ids: String...) -> DockProfile {
        DockProfile(id: UUID(), name: "Test", items: ids.map(item))
    }

    private func ids(_ profile: DockProfile) -> [String] { profile.items.map(\.bundleID) }

    // MARK: Switching

    @Test(arguments: [
        (0, 1, 3, 1),
        (2, 1, 3, 0),     // past the end wraps to the first
        (0, -1, 3, 2),    // before the start wraps to the last
        (1, 4, 3, 2),     // more steps than profiles
        (1, -7, 3, 0),
        (2, 0, 3, 2),
    ])
    func profileIndexWraps(current: Int, offset: Int, count: Int, expected: Int) {
        #expect(DockService.profileIndex(from: current, by: offset, count: count) == expected)
    }

    // MARK: Adding

    @Test func appendSkipsFixedAppsAndDuplicates() {
        var p = profile("a", "b")
        p.append([item("b"), item("finder"), item("c"), item("c")], excluding: ["finder"])
        #expect(ids(p) == ["a", "b", "c"])
    }

    // MARK: Reordering

    @Test func moveForwardTakesTheTargetsPlace() {
        var p = profile("a", "b", "c", "d")
        p.move("a", to: "c")
        #expect(ids(p) == ["b", "c", "a", "d"])
    }

    @Test func moveBackwardTakesTheTargetsPlace() {
        var p = profile("a", "b", "c", "d")
        p.move("d", to: "b")
        #expect(ids(p) == ["a", "d", "b", "c"])
    }

    @Test func moveIgnoresUnknownAppsAndItself() {
        var p = profile("a", "b", "c")
        p.move("x", to: "b")
        p.move("a", to: "x")
        p.move("b", to: "b")
        #expect(ids(p) == ["a", "b", "c"])
    }

    // MARK: Placing (drag into the dock)

    @Test func placeMovesAnAppAlreadyInTheProfile() {
        var p = profile("a", "b", "c")
        p.place(item("a"), at: 2)
        #expect(ids(p) == ["b", "c", "a"])
    }

    @Test func placeKeepsTheStoredPathOfAMovedApp() {
        var p = DockProfile(id: UUID(), name: "Test", items: [DockItem(bundleID: "a", path: "/old/a.app"), item("b")])
        p.place(DockItem(bundleID: "a", path: "/new/a.app"), at: 1)
        #expect(p.items.last == DockItem(bundleID: "a", path: "/old/a.app"))
    }

    @Test func placePinsANewApp() {
        var p = profile("a", "b")
        p.place(item("x"), at: 1)
        #expect(ids(p) == ["a", "x", "b"])
    }

    @Test(arguments: [(-3, ["x", "a", "b"]), (99, ["a", "b", "x"])])
    func placeClampsTheIndex(index: Int, expected: [String]) {
        var p = profile("a", "b")
        p.place(item("x"), at: index)
        #expect(ids(p) == expected)
    }
}
