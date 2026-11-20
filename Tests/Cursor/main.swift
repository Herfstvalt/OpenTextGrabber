import Cocoa

setbuf(stdout, nil)
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
DispatchQueue.main.async {
let previousApp = NSWorkspace.shared.frontmostApplication
var failures = 0
var cancellations = 0
func check(_ condition: Bool, _ message: String) {
    if !condition { print("FAIL: \(message)"); failures += 1 }
}
func settle(_ seconds: TimeInterval = 0.05) {
    let deadline = Date(timeIntervalSinceNow: seconds)
    while Date() < deadline {
        if let event = app.nextEvent(matching: .any, until: deadline, inMode: .default, dequeue: true) {
            app.sendEvent(event)
        }
        app.updateWindows()
    }
}
for iteration in 1...20 {
    ScreenCapture.beginSelection { image in
        check(image == nil, "cancellation must not capture a screen image")
        cancellations += 1
    }
    settle(iteration == 1 ? 0.5 : 0.12)
    // AppKit/WindowServer cursor changes finish asynchronously after activation.
    let cursorDeadline = Date(timeIntervalSinceNow: 0.25)
    while NSCursor.current != NSCursor.crosshair && Date() < cursorDeadline {
        settle(0.01)
    }
    check(NSCursor.current == NSCursor.crosshair, "crosshair on selection \(iteration)")
    check(app.keyWindow?.contentView is SelectionView, "selection owns the key window")
    ScreenCapture.beginSelection { _ in
        check(false, "duplicate selection must not replace the active callback")
    }
    if let window = app.keyWindow, let view = window.contentView {
        let event = NSEvent.mouseEvent(with: .mouseMoved,
            location: NSPoint(x: view.bounds.midX, y: view.bounds.midY),
            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0,
            clickCount: 0, pressure: 0)!
        NSCursor.arrow.set()
        window.sendEvent(event)
        check(NSCursor.current == NSCursor.crosshair, "mouse movement restores crosshair")
    }
    ScreenCapture.endSelection(rect: nil)
    settle(0.02)
    check(NSCursor.current == NSCursor.arrow, "arrow restored after cancellation \(iteration)")
    check(cancellations == iteration, "exactly one completion per selection")
}
// A pending main-queue cursor refresh must not resurrect the crosshair after cancel.
ScreenCapture.beginSelection { _ in cancellations += 1 }
ScreenCapture.endSelection(rect: nil)
settle()
check(NSCursor.current == NSCursor.arrow, "immediate cancellation clears deferred cursor updates")
check(cancellations == 21, "immediate cancellation completes once")
previousApp?.activate(options: [])
if failures == 0 { print("PASS: 20 selection/movement/cancel cycles and immediate cancellation") }
exit(failures == 0 ? 0 : 1)

}
app.run()
