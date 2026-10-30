import AppKit
import SwiftUI

/// Hand-drawn pixel silhouettes. The menu uses system-tinted templates for
/// contrast on every wallpaper; the larger UI icons take the café palette.
struct PixelIcon: View {
    enum Kind { case keyboard, coffee, headphones, microphone, pause, pencil, door, dial }
    var kind: Kind
    var color: Color = .primary

    var body: some View {
        Canvas { context, size in
            let rows = PixelArt.rows(for: kind)
            let columns = rows.map(\.count).max() ?? 1
            let unit = max(1, floor(min(size.width / CGFloat(columns), size.height / CGFloat(rows.count))))
            let origin = CGPoint(x: floor((size.width - CGFloat(columns) * unit) / 2),
                                 y: floor((size.height - CGFloat(rows.count) * unit) / 2))
            for (y, row) in rows.enumerated() {
                for (x, pixel) in row.enumerated() where pixel != "." {
                    let rect = CGRect(x: origin.x + CGFloat(x) * unit, y: origin.y + CGFloat(y) * unit,
                                      width: unit, height: unit)
                    context.fill(Path(rect), with: .color(color.opacity(pixel == "+" ? 0.42 : 1)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

enum PixelArt {
    static func rows(for kind: PixelIcon.Kind) -> [String] {
        switch kind {
        case .keyboard:
            return [
                "........................",
                "...................###..",
                "..#####################.",
                ".#+++++++++++++++++++++#",
                ".#+####+####+####++###+#",
                ".#+#..#+#..#+#..#+#...##",
                ".#+#..#+#..#+#..#+#.#.##",
                ".#+####+####+####++###+#",
                ".#+++++++++++++++++++++#",
                ".#+++++++++++++++++++++#",
                ".#+++##++++++++++##++++#",
                ".#+++##++++++++++##++++#",
                ".#+++++++#+##+#++++++++#",
                ".#++++++++####+++++++++#",
                "..#####################.",
                "...###............###...",
                "...##..............##...",
                "........................"
            ]
        case .coffee:
            return [
                "....#...#.......",
                "...#...#........",
                "....#...#.......",
                "................",
                ".###########....",
                ".#+++++++++####.",
                ".#+++++++++#..#.",
                ".#+++++++++#..#.",
                ".#+++++++++#..#.",
                ".#+++++++++###..",
                "..#+++++++#.....",
                "..#+++++++#.....",
                "...#######......",
                "................",
                ".############...",
                "................"
            ]
        case .headphones:
            return [
                "................",
                ".....######.....",
                "...##########...",
                "..###......###..",
                ".##..........##.",
                ".##..........##.",
                ".##..........##.",
                ".####......####.",
                ".#++#......#++#.",
                ".#++#......#++#.",
                ".#++#......#++#.",
                ".#++#......#++#.",
                ".#++#......#++#.",
                "..###......###..",
                "................",
                "................"
            ]
        case .microphone:
            return [
                "......####......",
                ".....#++++#.....",
                ".....#++++#.....",
                ".....######.....",
                ".....#++++#.....",
                ".....######.....",
                "..#..#++++#..#..",
                "..#..#++++#..#..",
                "..#...####...#..",
                "...#........#...",
                "....#......#....",
                ".....######.....",
                ".......##.......",
                ".......##.......",
                ".....######.....",
                "................"
            ]
        case .pause:
            return ["................", "................", "...###....###...", "...###....###...", "...###....###...", "...###....###...", "...###....###...", "...###....###...", "...###....###...", "...###....###...", "...###....###...", "...###....###...", "...###....###...", "................", "................", "................"]
        case .pencil:
            return ["................", "..........##....", ".........#++#...", "........#++++#..", ".......#++###...", "......#++#.#....", ".....#++#.#.....", "....#++#.#......", "...#++#.#.......", "..#++#.#........", "..#.#.#.........", "..#..#..........", "..###...........", "................", "................", "................"]
        case .door:
            return ["................", "...##########...", "...#........#...", "...#........#...", "...#........#...", "...#........#...", "...#........#...", "...#.....##.#...", "...#.....##.#...", "...#........#...", "...#........#...", "...#........#...", "...#........#...", "...##########...", "................", "................"]
        case .dial:
            return [".....######.....", "...##..##..##...", "..#....##....#..", ".#.....##.....#.", ".#............#.", "#..............#", "#..............#", "#..............#", "#..............#", "#..............#", ".#............#.", ".#............#.", "..#..........#..", "...##......##...", ".....######.....", "................"]
        }
    }

    static func menuImage(for profile: Profile, paused: Bool = false) -> NSImage {
        let kind: PixelIcon.Kind
        switch profile {
        case .coding: kind = .coffee
        case .music: kind = .headphones
        case .calls: kind = .microphone
        }
        return templateImage(kind: kind, size: NSSize(width: 20, height: 18),
                             description: "\(profile.title) profile\(paused ? ", paused" : "")", paused: paused)
    }

    // Compatibility for previews that still ask for the app mascot.
    static func menuImage() -> NSImage {
        templateImage(kind: .keyboard, size: NSSize(width: 26, height: 20), description: "Keypad Companion")
    }

    private static func templateImage(kind: PixelIcon.Kind, size: NSSize,
                                      description: String, paused: Bool = false) -> NSImage {
        let pixels = rows(for: kind)
        let width = pixels.map(\.count).max() ?? 0
        let left = floor((size.width - CGFloat(width)) / 2)
        let top = floor((size.height - CGFloat(pixels.count)) / 2)
        let image = NSImage(size: size, flipped: true) { _ in
            NSGraphicsContext.current?.shouldAntialias = false
            for (y, row) in pixels.enumerated() {
                for (x, pixel) in row.enumerated() where pixel != "." {
                    let alpha = (pixel == "+" ? 0.25 : 1.0) * (paused ? 0.48 : 1.0)
                    NSColor.black.withAlphaComponent(alpha).setFill()
                    NSRect(x: left + CGFloat(x), y: top + CGFloat(y), width: 1, height: 1).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = description
        return image
    }
}
