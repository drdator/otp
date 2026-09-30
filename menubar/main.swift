import AppKit
import ServiceManagement

let otpPath = "/usr/local/bin/otp"
let keysPath = NSHomeDirectory() + "/.otpkeys"

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    func applicationDidFinishLaunching(_ notification: Notification) {
        setIcon("key.fill")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // Rebuilt on every open so edits to ~/.otpkeys show up without a restart
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let contents = (try? String(contentsOfFile: keysPath, encoding: .utf8)) ?? ""
        for line in contents.split(separator: "\n") {
            guard let eq = line.firstIndex(of: "=") else { continue }
            let item = NSMenuItem(title: String(line[..<eq]), action: #selector(copyCode), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let edit = NSMenuItem(title: "Edit keys", action: #selector(editKeys), keyEquivalent: "")
        edit.target = self
        edit.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: nil)
        menu.addItem(edit)
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate), keyEquivalent: "q"))
    }

    @objc func copyCode(_ sender: NSMenuItem) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: otpPath)
        process.arguments = [sender.title]
        // GUI apps don't get the shell PATH, and otp needs oathtool from Homebrew
        process.environment = ["HOME": NSHomeDirectory(), "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"]
        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                self.setIcon("checkmark")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.setIcon("key.fill") }
            }
        }
        try? process.run()
    }

    // -t: the file has no extension, so ask for the default text editor explicitly
    @objc func editKeys() {
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/open"), arguments: ["-t", keysPath])
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
