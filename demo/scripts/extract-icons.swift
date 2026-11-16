// Renders the real icons of the apps shown in the Dock scene to PNG, using the same
// NSWorkspace call the Flyby Dock itself uses. Run: swift scripts/extract-icons.swift
import AppKit

let out = URL(fileURLWithPath: "public/icons", isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].path
let apps: [(String, String)] = [
    ("terminal", "/System/Applications/Utilities/Terminal.app"),
    ("vscode", "/Applications/Visual Studio Code.app"),
    ("chrome", "/Applications/Google Chrome.app"),
    ("claude", "/Applications/Claude.app"),
    ("github", "/Applications/GitHub Desktop.app"),
    ("lightroom", "/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app"),
    ("photos", "/System/Applications/Photos.app"),
    ("preview", "/System/Applications/Preview.app"),
    ("notes", "/System/Applications/Notes.app"),
    ("freeform", "/System/Applications/Freeform.app"),
    ("spotify", "/Applications/Spotify.app"),
    ("music", "/System/Applications/Music.app"),
    ("podcasts", "/System/Applications/Podcasts.app"),
    ("tv", "/System/Applications/TV.app"),
    ("stremio", "/Applications/Stremio.app"),
    ("mail", "/System/Applications/Mail.app"),
    ("messages", "/System/Applications/Messages.app"),
    ("downloads", downloads),
]

func save(_ image: NSImage, as name: String) {
    let side = 256
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { return }
    rep.size = NSSize(width: side, height: side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try? rep.representation(using: .png, properties: [:])?.write(to: out.appendingPathComponent("\(name).png"))
    print("ok", name)
}

for (name, path) in apps {
    guard FileManager.default.fileExists(atPath: path) else { print("MISSING", name, path); continue }
    save(NSWorkspace.shared.icon(forFile: path), as: name)
}
if let trash = NSImage(named: NSImage.trashEmptyName) { save(trash, as: "trash") }
