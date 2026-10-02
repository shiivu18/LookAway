import AppKit
import CoreGraphics

print("==> Checking system displays and notch area:")
for (i, screen) in NSScreen.screens.enumerated() {
    print("Screen \(i): frame=\(screen.frame), visible=\(screen.visibleFrame)")
    print("  safeAreaTop=\(screen.safeAreaInsets.top)")
    if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
        print("  Physical Notch detected! Width: \(right.minX - left.maxX), Height: \(screen.safeAreaInsets.top)")
    } else {
        print("  Notchless display detected. EyeBreak will render a sleek top-centered Dynamic Island pill.")
    }
}

print("\n==> Checking active windows for 'EyeBreak':")
let onScreenWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let eyeVisible = onScreenWindows.filter { ($0[kCGWindowOwnerName as String] as? String) == "EyeBreak" }

print("Visible on-screen EyeBreak windows count: \(eyeVisible.count)")
for (idx, w) in eyeVisible.enumerated() {
    let name = w[kCGWindowName as String] ?? "(unnamed)"
    let layer = w[kCGWindowLayer as String] ?? 0
    let boundsDict = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let x = boundsDict["X"] ?? 0
    let y = boundsDict["Y"] ?? 0
    let width = boundsDict["Width"] ?? 0
    let height = boundsDict["Height"] ?? 0
    print("  [\(idx)] Visible Window: '\(name)', Layer: \(layer), Rect: (x: \(x), y: \(y), w: \(width), h: \(height))")
}
