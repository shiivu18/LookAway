import AppKit

/// Represents the geometric metrics and notch characteristics of a target display.
public struct NotchMetrics {
    public let screen: NSScreen
    public let hasPhysicalNotch: Bool
    
    /// The physical notch bounding box (or simulated pill area for notchless screens) in screen coordinates.
    public let notchRect: NSRect
    
    /// The width of the notch (or base pill width).
    public let notchWidth: CGFloat
    
    /// The height of the notch (or top bezel height).
    public let notchHeight: CGFloat
    
    /// Width of the expanded alert window.
    public let expandedWidth: CGFloat
    
    /// Height of the expanded alert window.
    public let expandedHeight: CGFloat
    
    /// Panel frame in screen coordinates when collapsed (anchored at notch/top).
    public var collapsedFrame: NSRect {
        let x = notchRect.midX - (notchWidth / 2.0)
        let y = screen.frame.maxY - notchHeight
        return NSRect(x: x, y: y, width: notchWidth, height: notchHeight)
    }
    
    /// Panel frame in screen coordinates when fully expanded downward.
    public var expandedFrame: NSRect {
        let x = notchRect.midX - (expandedWidth / 2.0)
        let y = screen.frame.maxY - expandedHeight
        return NSRect(x: x, y: y, width: expandedWidth, height: expandedHeight)
    }
}

public enum ScreenNotchDetector {
    /// Identifies the screen currently containing the mouse cursor,
    /// falling back to the main screen or the primary display.
    public static func targetScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        if let screenUnderMouse = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return screenUnderMouse
        }
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }
    
    /// Computes accurate notch and window metrics for the given screen.
    ///
    /// Notch positioning logic:
    /// 1. macOS 12+ exposes `safeAreaInsets.top` on `NSScreen`. On MacBook Pros/Airs with a notch,
    ///    `safeAreaInsets.top` is positive (typically 32 to 38 pt).
    /// 2. `auxiliaryTopLeftArea` and `auxiliaryTopRightArea` mark the usable menu bar areas
    ///    to the left and right of the physical camera cutout.
    /// 3. The exact notch rect is located between `auxiliaryTopLeftArea.maxX` and `auxiliaryTopRightArea.minX`,
    ///    resting directly against the top boundary of the display: `screen.frame.maxY - notchHeight`.
    /// 4. For notchless displays (external monitors, iMacs, older MacBooks), `safeAreaInsets.top` is 0.
    ///    We gracefully fall back to a sleek top-centered "Dynamic Island" pill.
    public static func metrics(for screen: NSScreen = targetScreen()) -> NotchMetrics {
        let screenFrame = screen.frame
        let safeTop = screen.safeAreaInsets.top
        
        let hasNotch: Bool
        let notchRect: NSRect
        let notchWidth: CGFloat
        let notchHeight: CGFloat
        
        if safeTop > 0,
           let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea,
           rightArea.minX > leftArea.maxX {
            // Physical notch detected (MacBook with camera/microphone cutout)
            hasNotch = true
            notchWidth = rightArea.minX - leftArea.maxX
            notchHeight = safeTop
            let notchX = leftArea.maxX
            let notchY = screenFrame.maxY - notchHeight
            notchRect = NSRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
        } else {
            // No physical notch (external display or notchless Mac)
            hasNotch = false
            // Standard simulated Dynamic Island pill size
            notchWidth = 190.0
            notchHeight = 34.0
            let notchX = screenFrame.midX - (notchWidth / 2.0)
            let notchY = screenFrame.maxY - notchHeight
            notchRect = NSRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
        }
        
        // Expanded alert dimensions:
        // We ensure the expanded alert is wider than the notch (minimum 500pt)
        // and expands downward with full clearance below the physical camera/microphone cutout.
        let expandedWidth = max(notchWidth + 280.0, 500.0)
        let visibleContentHeight: CGFloat = 74.0
        let expandedHeight = (hasNotch ? notchHeight : 8.0) + visibleContentHeight
        
        return NotchMetrics(
            screen: screen,
            hasPhysicalNotch: hasNotch,
            notchRect: notchRect,
            notchWidth: notchWidth,
            notchHeight: notchHeight,
            expandedWidth: expandedWidth,
            expandedHeight: expandedHeight
        )
    }
}
