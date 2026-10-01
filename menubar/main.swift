import AppKit
import ServiceManagement

// Runs the otp CLI, which only talks to the keychain and oathtool, so it's quick enough to wait for
func otp(_ args: [String], input: String = "") -> (ok: Bool, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/otp")
    process.arguments = args
    // GUI apps don't get the shell PATH, and otp needs oathtool from Homebrew
    process.environment = ["HOME": NSHomeDirectory(), "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"]
    let inPipe = Pipe(), outPipe = Pipe()
    process.standardInput = inPipe
    process.standardOutput = outPipe
    do { try process.run() } catch { return (false, "") }
    inPipe.fileHandleForWriting.write(Data(input.utf8))
    try? inPipe.fileHandleForWriting.close()
    let output = String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    process.waitUntilExit()
    return (process.terminationStatus == 0, output.trimmingCharacters(in: .newlines))
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    func applicationDidFinishLaunching(_ notification: Notification) {
        setIcon("key.fill")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Menubar-only apps have no main menu, but ⌘X/⌘C/⌘V/⌘A in text fields are routed through its Edit menu
        let edit = NSMenu()
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem()
        editItem.submenu = edit
        NSApp.mainMenu = NSMenu()
        NSApp.mainMenu?.addItem(editItem)
    }

    // Rebuilt on every open so keys added from the terminal show up without a restart
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for name in otp([]).output.split(separator: "\n") {
            let item = NSMenuItem(title: String(name), action: #selector(copyCode), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let add = NSMenuItem(title: "Add key…", action: #selector(addKey), keyEquivalent: "")
        add.target = self
        add.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        menu.addItem(add)
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate), keyEquivalent: "q"))
    }

    @objc func copyCode(_ sender: NSMenuItem) {
        let result = otp([sender.title])
        if result.ok {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result.output, forType: .string)
        }
        flash(result.ok ? "checkmark" : "xmark")
    }

    @objc func addKey() {
        let name = NSTextField(frame: NSRect(x: 0, y: 32, width: 240, height: 24))
        name.placeholderString = "Name"
        let secret = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        secret.placeholderString = "Secret"
        name.nextKeyView = secret
        let fields = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 56))
        fields.addSubview(name)
        fields.addSubview(secret)

        let alert = NSAlert()
        alert.messageText = "Add key"
        alert.accessoryView = fields
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = name
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if otp(["add", name.stringValue], input: secret.stringValue).ok {
            flash("checkmark")
        } else {
            let error = NSAlert()
            error.messageText = "Couldn't add \"\(name.stringValue)\""
            error.informativeText = "Check that the secret is a valid base32 TOTP key."
            error.runModal()
        }
    }

    // Briefly swap the menubar icon to show the result
    func flash(_ symbol: String) {
        setIcon(symbol)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.setIcon("key.fill") }
    }

    @objc func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSApp.activate()
            NSAlert(error: error).runModal()
        }
    }

    func setIcon(_ symbol: String) {
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "OTP")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
