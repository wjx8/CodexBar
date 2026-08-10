import AppKit

/// Presents a Touch Bar independently of the frontmost application's responder chain.
///
/// AppKit does not expose this behavior as public API, so every selector is resolved
/// at runtime and safely becomes a no-op on systems where it is unavailable.
enum SystemModalTouchBar {
    private static let presentSelector = NSSelectorFromString(
        "presentSystemModalTouchBar:systemTrayItemIdentifier:"
    )
    private static let dismissSelector = NSSelectorFromString("dismissSystemModalTouchBar:")

    static var isSupported: Bool {
        (NSTouchBar.self as AnyObject).responds(to: presentSelector)
    }

    static func present(_ touchBar: NSTouchBar) -> Bool {
        let touchBarClass = NSTouchBar.self as AnyObject
        guard touchBarClass.responds(to: presentSelector) else {
            return false
        }

        _ = touchBarClass.perform(presentSelector, with: touchBar, with: nil)
        return true
    }

    static func dismiss(_ touchBar: NSTouchBar) {
        let touchBarClass = NSTouchBar.self as AnyObject
        guard touchBarClass.responds(to: dismissSelector) else {
            return
        }

        _ = touchBarClass.perform(dismissSelector, with: touchBar)
    }
}
