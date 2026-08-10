import AppKit

struct HUDAppearance: Equatable {
    enum ColorChoice: String, CaseIterable {
        case black
        case graphite
        case blue
        case green
        case purple

        var title: String {
            switch self {
            case .black:
                return "深黑"
            case .graphite:
                return "石墨"
            case .blue:
                return "深蓝"
            case .green:
                return "深绿"
            case .purple:
                return "紫色"
            }
        }

        var color: NSColor {
            switch self {
            case .black:
                return NSColor(calibratedWhite: 0.04, alpha: 1)
            case .graphite:
                return NSColor(calibratedWhite: 0.18, alpha: 1)
            case .blue:
                return NSColor(calibratedRed: 0.04, green: 0.10, blue: 0.22, alpha: 1)
            case .green:
                return NSColor(calibratedRed: 0.04, green: 0.16, blue: 0.10, alpha: 1)
            case .purple:
                return NSColor(calibratedRed: 0.15, green: 0.08, blue: 0.22, alpha: 1)
            }
        }
    }

    static let opacityChoices: [Double] = [
        0.10,
        0.20,
        0.30,
        0.40,
        0.50,
        0.60,
        0.75,
        0.86,
        1.0
    ]

    private enum DefaultsKey {
        static let color = "hud.color"
        static let backgroundOpacity = "hud.backgroundOpacity"
        static let contentOpacity = "hud.contentOpacity"
        static let legacyOpacity = "hud.opacity"
    }

    var colorChoice: ColorChoice
    var backgroundOpacity: Double
    var contentOpacity: Double

    var backgroundColor: NSColor {
        colorChoice.color.withAlphaComponent(backgroundOpacity)
    }

    static func load() -> HUDAppearance {
        let defaults = UserDefaults.standard
        let colorName = defaults.string(forKey: DefaultsKey.color) ?? ColorChoice.black.rawValue
        let color = ColorChoice(rawValue: colorName) ?? .black
        let legacyOpacity = defaults.object(forKey: DefaultsKey.legacyOpacity) as? Double ?? 0.86
        let backgroundOpacity = defaults.object(forKey: DefaultsKey.backgroundOpacity) as? Double ?? legacyOpacity
        let contentOpacity = defaults.object(forKey: DefaultsKey.contentOpacity) as? Double ?? legacyOpacity

        return HUDAppearance(
            colorChoice: color,
            backgroundOpacity: clamped(backgroundOpacity),
            contentOpacity: clamped(contentOpacity)
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(colorChoice.rawValue, forKey: DefaultsKey.color)
        defaults.set(backgroundOpacity, forKey: DefaultsKey.backgroundOpacity)
        defaults.set(contentOpacity, forKey: DefaultsKey.contentOpacity)
        defaults.set(backgroundOpacity, forKey: DefaultsKey.legacyOpacity)
    }

    private static func clamped(_ opacity: Double) -> Double {
        max(0.10, min(1.0, opacity))
    }
}
