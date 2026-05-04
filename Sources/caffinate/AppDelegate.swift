import AppKit
import IOKit.pwr_mgt

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sleepController = SleepController()
    private var statusItem: NSStatusItem?
    private var toggleSwitch: NSSwitch?
    private var stateLabel: NSTextField?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        updateMenuState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        sleepController.disable()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        item.button?.imagePosition = .imageOnly
        item.button?.imageScaling = .scaleProportionallyDown

        let menu = NSMenu()

        let toggle = NSMenuItem()
        toggle.view = makeToggleView()
        menu.addItem(toggle)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit caffinate",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
    }

    private func makeToggleView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 230, height: 58))

        let title = NSTextField(labelWithString: "Keep awake")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let state = NSTextField(labelWithString: "Off")
        state.font = .systemFont(ofSize: 11)
        state.textColor = .secondaryLabelColor
        state.translatesAutoresizingMaskIntoConstraints = false
        stateLabel = state

        let toggle = NSSwitch()
        toggle.target = self
        toggle.action = #selector(toggleSwitchChanged(_:))
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggleSwitch = toggle

        view.addSubview(title)
        view.addSubview(state)
        view.addSubview(toggle)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            title.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),

            state.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            state.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 3),
            state.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),

            toggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        return view
    }

    @objc private func toggleSwitchChanged(_ sender: NSSwitch) {
        setKeepAwake(sender.state == .on)
    }

    private func setKeepAwake(_ shouldEnable: Bool) {
        do {
            if shouldEnable {
                try sleepController.enable()
            } else {
                sleepController.disable()
            }
        } catch {
            showAssertionError(error)
        }

        updateMenuState()
    }

    @objc private func quitApp() {
        sleepController.disable()
        NSApp.terminate(nil)
    }

    private func updateMenuState() {
        let enabled = sleepController.isEnabled

        toggleSwitch?.state = enabled ? .on : .off
        stateLabel?.stringValue = enabled ? "On" : "Off"

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: enabled ? "sun.max.fill" : "moon.zzz.fill",
                accessibilityDescription: enabled ? "Keep Awake is on" : "Keep Awake is off"
            )
            button.toolTip = enabled ? "caffinate: Keep awake is on" : "caffinate: Keep awake is off"
        }
    }

    private func showAssertionError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not change sleep setting"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

final class SleepController {
    private(set) var isEnabled = false
    private var systemSleepAssertion = IOPMAssertionID(0)
    private var displaySleepAssertion = IOPMAssertionID(0)

    func enable() throws {
        guard !isEnabled else { return }

        do {
            systemSleepAssertion = try createAssertion(
                type: kIOPMAssertPreventUserIdleSystemSleep as CFString,
                reason: "caffinate is keeping the Mac awake."
            )
            displaySleepAssertion = try createAssertion(
                type: kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                reason: "caffinate is keeping the display awake."
            )
            isEnabled = true
        } catch {
            releaseAssertions()
            throw error
        }
    }

    func disable() {
        guard isEnabled || systemSleepAssertion != 0 || displaySleepAssertion != 0 else { return }
        releaseAssertions()
        isEnabled = false
    }

    private func createAssertion(type: CFString, reason: String) throws -> IOPMAssertionID {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            throw SleepAssertionError.creationFailed(code: result)
        }

        return assertionID
    }

    private func releaseAssertions() {
        if systemSleepAssertion != 0 {
            IOPMAssertionRelease(systemSleepAssertion)
            systemSleepAssertion = 0
        }

        if displaySleepAssertion != 0 {
            IOPMAssertionRelease(displaySleepAssertion)
            displaySleepAssertion = 0
        }
    }
}

enum SleepAssertionError: LocalizedError {
    case creationFailed(code: IOReturn)

    var errorDescription: String? {
        switch self {
        case .creationFailed(let code):
            return "macOS rejected the power assertion with IOReturn code \(code)."
        }
    }
}
