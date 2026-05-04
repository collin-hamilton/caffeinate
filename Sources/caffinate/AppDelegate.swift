import AppKit
import IOKit.pwr_mgt
import IOKit.ps
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sleepController = SleepController()
    private let batteryMonitor = BatteryMonitor()
    private var batteryPolicy = BatteryPolicy.load()
    private var timerOption = TimerOption.load()

    private var statusItem: NSStatusItem?
    private var toggleSwitch: CoffeeToggle?
    private var stateLabel: NSTextField?
    private var detailLabel: NSTextField?
    private var batteryLabel: NSTextField?
    private var timerControl: NSSegmentedControl?
    private var launchAtLoginButton: NSButton?
    private var disableOnBatteryButton: NSButton?
    private var autoDisableButton: NSButton?
    private var thresholdControl: NSSegmentedControl?

    private var expirationDate: Date?
    private var countdownTimer: Timer?
    private var batteryTimer: Timer?
    private var lastBatteryPowered: Bool?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        startBatteryMonitoring()
        updateMenuState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        countdownTimer?.invalidate()
        batteryTimer?.invalidate()
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
        menu.addItem(makeTimerControlItem())
        menu.addItem(makeLaunchAtLoginControlItem())
        menu.addItem(makeBatteryProtectionControlItem())

        menu.addItem(.separator())

        let about = NSMenuItem(
            title: "About caffinate...",
            action: #selector(showAboutPanel),
            keyEquivalent: ""
        )
        about.target = self
        menu.addItem(about)

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
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 275, height: 92))

        let title = NSTextField(labelWithString: "Keep awake")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let state = NSTextField(labelWithString: "Sleep allowed")
        state.font = .systemFont(ofSize: 12, weight: .medium)
        state.textColor = .secondaryLabelColor
        state.translatesAutoresizingMaskIntoConstraints = false
        stateLabel = state

        let detail = NSTextField(labelWithString: "Until turned off")
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .tertiaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        detail.translatesAutoresizingMaskIntoConstraints = false
        detailLabel = detail

        let battery = NSTextField(labelWithString: "Battery: checking...")
        battery.font = .systemFont(ofSize: 11)
        battery.textColor = .tertiaryLabelColor
        battery.lineBreakMode = .byTruncatingTail
        battery.translatesAutoresizingMaskIntoConstraints = false
        batteryLabel = battery

        let toggle = CoffeeToggle(frame: NSRect(x: 0, y: 0, width: 74, height: 34))
        toggle.target = self
        toggle.action = #selector(toggleSwitchChanged(_:))
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggleSwitch = toggle

        view.addSubview(title)
        view.addSubview(state)
        view.addSubview(detail)
        view.addSubview(battery)
        view.addSubview(toggle)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            title.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),

            state.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            state.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            state.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),

            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.topAnchor.constraint(equalTo: state.bottomAnchor, constant: 5),
            detail.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),

            battery.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            battery.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 4),
            battery.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),

            toggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            toggle.topAnchor.constraint(equalTo: view.topAnchor, constant: 17),
            toggle.widthAnchor.constraint(equalToConstant: 74),
            toggle.heightAnchor.constraint(equalToConstant: 34)
        ])

        return view
    }

    private func makeTimerControlItem() -> NSMenuItem {
        let item = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 275, height: 58))
        let label = makeSectionLabel("Timer")
        let control = NSSegmentedControl(labels: ["Off", "15m", "30m", "1h"], trackingMode: .selectOne, target: self, action: #selector(selectTimer(_:)))
        control.translatesAutoresizingMaskIntoConstraints = false
        timerControl = control

        view.addSubview(label)
        view.addSubview(control)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),

            control.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            control.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 7),
            control.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            control.heightAnchor.constraint(equalToConstant: 24)
        ])

        item.view = view
        return item
    }

    private func makeLaunchAtLoginControlItem() -> NSMenuItem {
        let item = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 275, height: 34))
        let checkbox = NSButton(checkboxWithTitle: "Launch at Login", target: self, action: #selector(toggleLaunchAtLogin(_:)))
        checkbox.font = .systemFont(ofSize: 13)
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        launchAtLoginButton = checkbox

        view.addSubview(checkbox)

        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            checkbox.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            checkbox.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -14)
        ])

        item.view = view
        return item
    }

    private func makeBatteryProtectionControlItem() -> NSMenuItem {
        let item = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 275, height: 112))
        let label = makeSectionLabel("Power Usage Settings")
        let unplugged = NSButton(checkboxWithTitle: "Turn off when unplugged", target: self, action: #selector(toggleDisableWhenUnplugged(_:)))
        let autoDisable = NSButton(checkboxWithTitle: "Auto-disable below", target: self, action: #selector(toggleAutoDisableBelowThreshold(_:)))
        let threshold = NSSegmentedControl(labels: ["10", "20", "30", "40", "50"], trackingMode: .selectOne, target: self, action: #selector(selectBatteryThreshold(_:)))

        for checkbox in [unplugged, autoDisable] {
            checkbox.font = .systemFont(ofSize: 13)
            checkbox.translatesAutoresizingMaskIntoConstraints = false
        }

        threshold.translatesAutoresizingMaskIntoConstraints = false
        disableOnBatteryButton = unplugged
        autoDisableButton = autoDisable
        thresholdControl = threshold

        view.addSubview(label)
        view.addSubview(unplugged)
        view.addSubview(autoDisable)
        view.addSubview(threshold)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),

            unplugged.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            unplugged.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 7),
            unplugged.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -14),

            autoDisable.leadingAnchor.constraint(equalTo: unplugged.leadingAnchor),
            autoDisable.topAnchor.constraint(equalTo: unplugged.bottomAnchor, constant: 7),
            autoDisable.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -14),

            threshold.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            threshold.topAnchor.constraint(equalTo: autoDisable.bottomAnchor, constant: 8),
            threshold.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            threshold.heightAnchor.constraint(equalToConstant: 24)
        ])

        item.view = view
        return item
    }

    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    @objc private func toggleSwitchChanged(_ sender: CoffeeToggle) {
        setKeepAwake(sender.isOn, reason: nil)
    }

    @objc private func selectTimer(_ sender: NSSegmentedControl) {
        let options = TimerOption.all
        guard sender.selectedSegment >= 0, sender.selectedSegment < options.count else { return }

        timerOption = options[sender.selectedSegment]
        timerOption.save()

        if sleepController.isEnabled {
            scheduleExpiration()
        }

        updateMenuState()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        do {
            if sender.state == .off {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showError(title: "Could not update launch at login", error: error)
        }

        updateMenuState()
    }

    @objc private func toggleDisableWhenUnplugged(_ sender: NSButton) {
        batteryPolicy.disableWhenUnplugged = sender.state == .on
        batteryPolicy.save()
        updateMenuState()
    }

    @objc private func toggleAutoDisableBelowThreshold(_ sender: NSButton) {
        batteryPolicy.autoDisableBelowThreshold = sender.state == .on
        batteryPolicy.save()
        evaluateBatteryPolicy(allowUnplugTransitionDisable: false)
        updateMenuState()
    }

    @objc private func selectBatteryThreshold(_ sender: NSSegmentedControl) {
        let thresholds = BatteryPolicy.thresholds
        guard sender.selectedSegment >= 0, sender.selectedSegment < thresholds.count else { return }

        batteryPolicy.thresholdPercent = thresholds[sender.selectedSegment]
        batteryPolicy.save()
        evaluateBatteryPolicy(allowUnplugTransitionDisable: false)
        updateMenuState()
    }

    private func setKeepAwake(_ shouldEnable: Bool, reason: String?) {
        do {
            if shouldEnable {
                try sleepController.enable()
                scheduleExpiration()
                evaluateBatteryPolicy(allowUnplugTransitionDisable: false)
            } else {
                clearExpiration()
                sleepController.disable()
            }
        } catch {
            showError(title: "Could not change sleep setting", error: error)
        }

        if let reason {
            showTransientStatus(reason)
        }

        updateMenuState()
    }

    private func scheduleExpiration() {
        countdownTimer?.invalidate()
        expirationDate = timerOption.expirationDate

        guard expirationDate != nil else {
            updateMenuState()
            return
        }

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.handleCountdownTick()
        }
    }

    private func clearExpiration() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        expirationDate = nil
    }

    private func handleCountdownTick() {
        guard let expirationDate else { return }

        if Date() >= expirationDate {
            setKeepAwake(false, reason: "Timer ended")
            return
        }

        updateMenuState()
    }

    private func startBatteryMonitoring() {
        let snapshot = batteryMonitor.snapshot()
        lastBatteryPowered = snapshot.isBatteryPowered

        batteryTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.evaluateBatteryPolicy(allowUnplugTransitionDisable: true)
            self?.updateMenuState()
        }
    }

    private func evaluateBatteryPolicy(allowUnplugTransitionDisable: Bool) {
        let snapshot = batteryMonitor.snapshot()
        let switchedToBattery = (lastBatteryPowered == false && snapshot.isBatteryPowered)
        lastBatteryPowered = snapshot.isBatteryPowered

        guard sleepController.isEnabled else { return }

        if allowUnplugTransitionDisable && batteryPolicy.disableWhenUnplugged && switchedToBattery {
            setKeepAwake(false, reason: "Turned off after switching to battery")
            return
        }

        if batteryPolicy.autoDisableBelowThreshold,
           snapshot.isBatteryPowered,
           let percentage = snapshot.percentage,
           percentage <= batteryPolicy.thresholdPercent {
            setKeepAwake(false, reason: "Turned off at \(percentage)% battery")
        }
    }

    @objc private func showAboutPanel() {
        let snapshot = batteryMonitor.snapshot()
        let alert = NSAlert()
        alert.messageText = "caffinate"
        alert.informativeText = [
            "Status: \(sleepController.isEnabled ? "Caffeinated" : "Sleep allowed")",
            "Timer: \(timerStatusText)",
            "Battery: \(snapshot.displayText)",
            "Launch at login: \(SMAppService.mainApp.status == .enabled ? "On" : "Off")",
            "",
            "caffinate uses Apple's public power assertion APIs to prevent idle sleep. macOS may still sleep for lid close, low battery, Apple menu sleep, and other non-idle sleep reasons."
        ].joined(separator: "\n")
        alert.alertStyle = .informational
        alert.accessoryView = makeAboutCreditView()
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quitApp() {
        sleepController.disable()
        NSApp.terminate(nil)
    }

    private func updateMenuState() {
        let enabled = sleepController.isEnabled
        let snapshot = batteryMonitor.snapshot()

        toggleSwitch?.setOn(enabled, animated: true)
        stateLabel?.stringValue = enabled ? "Caffeinated" : "Sleep allowed"
        stateLabel?.textColor = enabled ? NSColor.systemOrange : .secondaryLabelColor
        detailLabel?.stringValue = timerStatusText
        detailLabel?.textColor = enabled ? NSColor.systemOrange : .tertiaryLabelColor
        batteryLabel?.stringValue = "Battery: \(snapshot.displayText)"
        batteryLabel?.textColor = batteryWarningColor(for: snapshot)

        timerControl?.selectedSegment = TimerOption.all.firstIndex(of: timerOption) ?? 0
        launchAtLoginButton?.state = SMAppService.mainApp.status == .enabled ? .on : .off
        disableOnBatteryButton?.state = batteryPolicy.disableWhenUnplugged ? .on : .off
        autoDisableButton?.state = batteryPolicy.autoDisableBelowThreshold ? .on : .off
        thresholdControl?.selectedSegment = BatteryPolicy.thresholds.firstIndex(of: batteryPolicy.thresholdPercent) ?? 1

        updateStatusIcon(enabled: enabled)
    }

    private func updateStatusIcon(enabled: Bool) {
        guard let button = statusItem?.button else { return }

        let symbolName = enabled ? "cup.and.saucer.fill" : "cup.and.saucer"
        let fallbackName = enabled ? "sun.max.fill" : "moon.zzz.fill"
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: enabled ? "Keep Awake is on" : "Keep Awake is off"
        ) ?? NSImage(
            systemSymbolName: fallbackName,
            accessibilityDescription: enabled ? "Keep Awake is on" : "Keep Awake is off"
        )

        image?.isTemplate = true
        button.image = image
        button.contentTintColor = enabled ? .systemOrange : .secondaryLabelColor
        button.toolTip = enabled ? "caffinate: Keep awake is on" : "caffinate: Keep awake is off"
    }

    private var timerStatusText: String {
        guard sleepController.isEnabled else {
            return timerOption == .untilTurnedOff ? "Until turned off" : "Next: \(timerOption.title)"
        }

        guard let expirationDate else {
            return "Until turned off"
        }

        let remaining = max(0, Int(expirationDate.timeIntervalSinceNow.rounded()))
        let minutes = remaining / 60
        let seconds = remaining % 60

        if minutes >= 60 {
            return "Turns off in \(minutes / 60)h \(minutes % 60)m"
        }

        return String(format: "Turns off in %dm %02ds", minutes, seconds)
    }

    private func batteryWarningColor(for snapshot: BatterySnapshot) -> NSColor {
        guard snapshot.isBatteryPowered, let percentage = snapshot.percentage else {
            return .tertiaryLabelColor
        }

        return percentage <= batteryPolicy.thresholdPercent ? .systemRed : .secondaryLabelColor
    }

    private func showTransientStatus(_ text: String) {
        detailLabel?.stringValue = text
    }

    private func makeAboutCreditView() -> NSView {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        let text = "Created by Collin Hamilton"
        let linkRange = (text as NSString).range(of: "Collin Hamilton")
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        attributed.addAttributes(
            [
                .link: URL(string: "https://github.com/collin-hamilton")!,
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ],
            range: linkRange
        )

        textView.textStorage?.setAttributedString(attributed)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        return textView
    }

    private func showError(title: String, error: Error) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

enum TimerOption: Int, CaseIterable, Equatable {
    case untilTurnedOff = 0
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60

    static let all: [TimerOption] = [.untilTurnedOff, .fifteenMinutes, .thirtyMinutes, .oneHour]

    var title: String {
        switch self {
        case .untilTurnedOff: return "Until Turned Off"
        case .fifteenMinutes: return "15 Minutes"
        case .thirtyMinutes: return "30 Minutes"
        case .oneHour: return "1 Hour"
        }
    }

    var expirationDate: Date? {
        guard rawValue > 0 else { return nil }
        return Date().addingTimeInterval(TimeInterval(rawValue * 60))
    }

    static func load() -> TimerOption {
        TimerOption(rawValue: UserDefaults.standard.integer(forKey: "timerOptionMinutes")) ?? .untilTurnedOff
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "timerOptionMinutes")
    }
}

struct BatteryPolicy {
    static let thresholds = [10, 20, 30, 40, 50]

    var disableWhenUnplugged: Bool
    var autoDisableBelowThreshold: Bool
    var thresholdPercent: Int

    static func load() -> BatteryPolicy {
        let defaults = UserDefaults.standard
        let savedThreshold = defaults.object(forKey: "batteryThresholdPercent") as? Int ?? 20
        let threshold = thresholds.contains(savedThreshold) ? savedThreshold : 20

        return BatteryPolicy(
            disableWhenUnplugged: defaults.bool(forKey: "disableWhenUnplugged"),
            autoDisableBelowThreshold: defaults.bool(forKey: "autoDisableBelowThreshold"),
            thresholdPercent: threshold
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(disableWhenUnplugged, forKey: "disableWhenUnplugged")
        defaults.set(autoDisableBelowThreshold, forKey: "autoDisableBelowThreshold")
        defaults.set(thresholdPercent, forKey: "batteryThresholdPercent")
    }
}

struct BatterySnapshot {
    let isBatteryPowered: Bool
    let percentage: Int?
    let hasBattery: Bool

    var displayText: String {
        guard hasBattery else { return "AC power" }

        if let percentage {
            return isBatteryPowered ? "\(percentage)% on battery" : "\(percentage)% charging"
        }

        return isBatteryPowered ? "On battery" : "AC power"
    }
}

final class BatteryMonitor {
    func snapshot() -> BatterySnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              !list.isEmpty else {
            return BatterySnapshot(isBatteryPowered: false, percentage: nil, hasBattery: false)
        }

        var foundBattery = false
        var percentage: Int?
        var isBatteryPowered = false

        for powerSource in list {
            guard let description = IOPSGetPowerSourceDescription(info, powerSource)?
                .takeUnretainedValue() as? [String: Any] else { continue }

            foundBattery = true

            if let state = description[kIOPSPowerSourceStateKey as String] as? String {
                isBatteryPowered = state == (kIOPSBatteryPowerValue as String)
            }

            if let current = description[kIOPSCurrentCapacityKey as String] as? Int,
               let max = description[kIOPSMaxCapacityKey as String] as? Int,
               max > 0 {
                percentage = Int((Double(current) / Double(max) * 100).rounded())
            }
        }

        return BatterySnapshot(
            isBatteryPowered: isBatteryPowered,
            percentage: percentage,
            hasBattery: foundBattery
        )
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

final class CoffeeToggle: NSControl {
    private let glowLayer = CALayer()
    private let trackLayer = CAGradientLayer()
    private let knobLayer = CALayer()
    private let indicatorLayer = CALayer()

    private(set) var isOn = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayers()
    }

    override var acceptsFirstResponder: Bool { true }

    override func layout() {
        super.layout()
        layoutLayers(animated: false)
    }

    override func mouseDown(with event: NSEvent) {
        setOn(!isOn, animated: true)
        sendAction(action, to: target)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 49 {
            setOn(!isOn, animated: true)
            sendAction(action, to: target)
            return
        }

        super.keyDown(with: event)
    }

    func setOn(_ newValue: Bool, animated: Bool) {
        guard isOn != newValue else {
            updateColors(animated: animated)
            return
        }

        isOn = newValue
        updateColors(animated: animated)
        layoutLayers(animated: animated)
    }

    private func configureLayers() {
        wantsLayer = true
        layer?.masksToBounds = false

        glowLayer.shadowRadius = 9
        glowLayer.shadowOffset = .zero
        glowLayer.shadowOpacity = 0

        trackLayer.startPoint = CGPoint(x: 0, y: 0.5)
        trackLayer.endPoint = CGPoint(x: 1, y: 0.5)
        trackLayer.shadowColor = NSColor.black.cgColor
        trackLayer.shadowOpacity = 0.15
        trackLayer.shadowRadius = 4
        trackLayer.shadowOffset = CGSize(width: 0, height: 1)

        knobLayer.backgroundColor = NSColor.white.cgColor
        knobLayer.shadowColor = NSColor.black.cgColor
        knobLayer.shadowOpacity = 0.24
        knobLayer.shadowRadius = 5
        knobLayer.shadowOffset = CGSize(width: 0, height: 2)

        indicatorLayer.backgroundColor = NSColor.systemGray.cgColor

        layer?.addSublayer(glowLayer)
        layer?.addSublayer(trackLayer)
        layer?.addSublayer(knobLayer)
        knobLayer.addSublayer(indicatorLayer)

        updateColors(animated: false)
        layoutLayers(animated: false)
        toolTip = "Toggle keep awake"
    }

    private func updateColors(animated: Bool) {
        let trackColors: [CGColor] = isOn
            ? [NSColor.systemYellow.cgColor, NSColor.systemOrange.cgColor]
            : [NSColor(calibratedWhite: 0.46, alpha: 1).cgColor, NSColor(calibratedWhite: 0.28, alpha: 1).cgColor]
        let indicatorColor = isOn ? NSColor.systemOrange.cgColor : NSColor.systemGray.cgColor
        let glowColor = isOn ? NSColor.systemOrange.cgColor : NSColor.clear.cgColor

        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? 0.18 : 0)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        trackLayer.colors = trackColors
        indicatorLayer.backgroundColor = indicatorColor
        glowLayer.shadowColor = glowColor
        glowLayer.shadowOpacity = isOn ? 0.45 : 0
        CATransaction.commit()
    }

    private func layoutLayers(animated: Bool) {
        let trackFrame = bounds.insetBy(dx: 1, dy: 1)
        let knobDiameter = bounds.height - 8
        let knobX = isOn ? bounds.width - knobDiameter - 5 : 5
        let knobFrame = CGRect(x: knobX, y: 4, width: knobDiameter, height: knobDiameter)
        let indicatorSize: CGFloat = 8

        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? 0.2 : 0)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        glowLayer.frame = bounds.insetBy(dx: 4, dy: 4)
        glowLayer.cornerRadius = glowLayer.bounds.height / 2

        trackLayer.frame = trackFrame
        trackLayer.cornerRadius = trackFrame.height / 2

        knobLayer.frame = knobFrame
        knobLayer.cornerRadius = knobDiameter / 2

        indicatorLayer.frame = CGRect(
            x: (knobDiameter - indicatorSize) / 2,
            y: (knobDiameter - indicatorSize) / 2,
            width: indicatorSize,
            height: indicatorSize
        )
        indicatorLayer.cornerRadius = indicatorSize / 2

        CATransaction.commit()
    }
}
