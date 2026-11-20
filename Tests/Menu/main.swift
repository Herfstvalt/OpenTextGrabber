import Cocoa

let app = NSApplication.shared
let defaults = UserDefaults.standard
let keys = ["scanQRCodes", "joinCapturedLines"]
let saved = keys.map { defaults.object(forKey: $0) }
defer {
    for (key, value) in zip(keys, saved) {
        if let value = value { defaults.set(value, forKey: key) }
        else { defaults.removeObject(forKey: key) }
    }
}
func check(_ condition: Bool, _ message: String) {
    if !condition { fatalError(message) }
}
func menuItem(_ menu: NSMenu, _ title: String) -> NSMenuItem {
    guard let item = menu.items.first(where: { $0.title == title }) else {
        fatalError("Missing menu item: \(title)")
    }
    return item
}
defaults.set(true, forKey: keys[0])
defaults.set(true, forKey: keys[1])
let delegate = AppDelegate()
let menu = NSMenu()
delegate.menuNeedsUpdate(menu)
for (index, title) in ["Read QR Codes", "Copy Text as Single Line"].enumerated() {
    let item = menuItem(menu, title)
    check(item.state == .on, "toggle must initially be checked")
    check(app.sendAction(item.action!, to: item.target, from: item), "menu action must be connected")
    check(!defaults.bool(forKey: keys[index]), "menu action must store the disabled preference")
    delegate.menuNeedsUpdate(menu)
    check(menuItem(menu, title).state == .off, "menu must reflect saved disabled preference")
    let offItem = menuItem(menu, title)
    check(app.sendAction(offItem.action!, to: offItem.target, from: offItem), "toggle must turn back on")
    check(defaults.bool(forKey: keys[index]), "enabled preference must be saved")
    check(defaults.bool(forKey: keys[1-index]), "the other preference must remain enabled")
    delegate.menuNeedsUpdate(menu)
}
check(defaults.synchronize(), "preferences must persist")
let recreatedMenu = NSMenu()
AppDelegate().menuNeedsUpdate(recreatedMenu)
check(menuItem(recreatedMenu, "Read QR Codes").state == .on, "new delegate reads QR preference")
check(menuItem(recreatedMenu, "Copy Text as Single Line").state == .on, "new delegate reads text preference")
print("PASS: both menu toggles, independent settings, saved preferences, and rebuilt menus")
