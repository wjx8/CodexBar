import AppKit

final class SegmentedBatteryBar: NSView {
    var remainingPercent: Double = 0 {
        didSet {
            needsDisplay = true
        }
    }

    var isDimmed: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    private let segmentCount = 10
    private let segmentSpacing: CGFloat = 2

    override var intrinsicContentSize: NSSize {
        NSSize(width: 180, height: 11)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let outerRect = bounds.insetBy(dx: 1, dy: 1)
        let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: outerRect.height / 2, yRadius: outerRect.height / 2)
        NSColor.separatorColor.withAlphaComponent(0.65).setStroke()
        outerPath.lineWidth = 1.3
        outerPath.stroke()

        let segmentBounds = outerRect.insetBy(dx: 5, dy: 3)
        let segmentWidth = (segmentBounds.width - CGFloat(segmentCount - 1) * segmentSpacing) / CGFloat(segmentCount)
        let filledSegments = Int(ceil(max(0, min(100, remainingPercent)) / 100 * Double(segmentCount)))

        for index in 0..<segmentCount {
            let x = segmentBounds.minX + CGFloat(index) * (segmentWidth + segmentSpacing)
            let rect = NSRect(x: x, y: segmentBounds.minY, width: segmentWidth, height: segmentBounds.height)
            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)

            if !isDimmed && index < filledSegments {
                fillColor.setFill()
            } else {
                NSColor.black.withAlphaComponent(0.22).setFill()
            }

            path.fill()
        }
    }

    private var fillColor: NSColor {
        if remainingPercent <= 20 {
            return .systemRed
        }
        if remainingPercent <= 45 {
            return .systemYellow
        }
        return NSColor(calibratedRed: 0.56, green: 1.0, blue: 0.12, alpha: 1.0)
    }
}
