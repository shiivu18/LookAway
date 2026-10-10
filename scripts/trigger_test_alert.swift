import Foundation

let arg = CommandLine.arguments.count > 1 ? CommandLine.arguments[1].lowercased() : "break"

let notificationName: String
switch arg {
case "distance", "dist", "screendistance":
    notificationName = "com.eyebreak.triggerDistanceAlert"
    print("==> Triggering Screen Distance Alert...")
case "notch", "live", "hud":
    notificationName = "com.eyebreak.toggleNotchDistance"
    print("==> Toggling Notch Live Distance...")
case "settings":
    notificationName = "com.eyebreak.openSettings"
    print("==> Opening LookAway Settings...")
default:
    notificationName = "com.eyebreak.triggerTestAlert"
    print("==> Triggering 20-20-20 Eye Break Alert...")
}

DistributedNotificationCenter.default().postNotificationName(
    NSNotification.Name(notificationName),
    object: nil,
    userInfo: nil,
    deliverImmediately: true
)
print("Notification [\(notificationName)] dispatched successfully.")
