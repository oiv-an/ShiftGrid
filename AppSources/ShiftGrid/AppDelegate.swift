import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let preferences = AppPreferences()
    private let eventMonitor = EventMonitorController()
    private let overlayController = OverlayController()
    private let toastPresenter = ToastPresenter()

    private var statusItem: NSStatusItem?
    private var instructionItem: NSMenuItem?
    private var statusSummaryItem: NSMenuItem?
    private var permissionItem: NSMenuItem?
    private var settingsWindowController: SettingsWindowController?
    private var accessibilityRefreshTimer: Timer?
    private var lastAccessibilityTrustState = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        lastAccessibilityTrustState = AccessibilityPermission.isTrusted
        buildStatusItem()
        configureEventMonitoring()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesChanged),
            name: .shiftGridPreferencesDidChange,
            object: nil
        )
        if !lastAccessibilityTrustState {
            DispatchQueue.main.async { [weak self] in
                self?.showSettings()
            }
        }
        startAccessibilityRefreshTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor.stop()
        accessibilityRefreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func menuWillOpen(_ menu: NSMenu) {
        let screen = ScreenMetrics.screenContainingMouse()
        let pixelWidth = screen.map(ScreenMetrics.displayPixelWidth) ?? 0
        let columns = LayoutPolicy.columnCount(
            mode: preferences.columnMode,
            displayPixelWidth: pixelWidth
        )
        statusSummaryItem?.title = "\(preferences.columnMode.title) · сейчас \(columns)"
        instructionItem?.title = preferences.selectionMethod == .holdShiftAndRelease
            ? "Shift, затем удерживать Shift → отпустить над зоной"
            : "Двойной Shift → навести и щёлкнуть"

        permissionItem?.title = AccessibilityPermission.isTrusted
            ? "Универсальный доступ: разрешён"
            : "Разрешить управление окнами…"
        permissionItem?.isEnabled = !AccessibilityPermission.isTrusted
    }

    private func buildStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = MenuBarIcon.make()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = "ShiftGrid — окно под курсором"
        }

        let menu = NSMenu()
        menu.delegate = self

        let instruction = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        instruction.isEnabled = false
        menu.addItem(instruction)
        instructionItem = instruction

        let statusSummaryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusSummaryItem.isEnabled = false
        menu.addItem(statusSummaryItem)
        self.statusSummaryItem = statusSummaryItem

        menu.addItem(.separator())
        let settingsItem = menu.addItem(
            withTitle: "Настройки…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self

        let permissionItem = NSMenuItem(
            title: "Разрешить управление окнами…",
            action: #selector(requestAccessibilityFromMenu),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)
        self.permissionItem = permissionItem

        menu.addItem(.separator())
        let quitItem = menu.addItem(
            withTitle: "Выйти из ShiftGrid",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self

        statusItem.menu = menu
        statusItem.isVisible = true
        self.statusItem = statusItem
    }

    private func configureEventMonitoring() {
        eventMonitor.selectionMethod = { [weak self] in
            self?.preferences.selectionMethod ?? .holdShiftAndRelease
        }
        eventMonitor.isOverlayVisible = { [weak self] in
            self?.overlayController.isVisible ?? false
        }
        eventMonitor.onCancelOverlay = { [weak self] in
            self?.overlayController.dismiss()
        }
        eventMonitor.onClickSelectionRequested = { [weak self] in
            self?.beginSelection(using: .click)
        }
        eventMonitor.onHoldSelectionBegan = { [weak self] in
            self?.beginSelection(using: .holdShiftAndRelease)
        }
        eventMonitor.onHoldSelectionEnded = { [weak self] in
            self?.overlayController.commitSelectionAtCurrentPointer()
        }
        eventMonitor.start()
    }

    private func startAccessibilityRefreshTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let isTrusted = AccessibilityPermission.isTrusted
            guard isTrusted != self.lastAccessibilityTrustState else { return }

            self.lastAccessibilityTrustState = isTrusted
            // A global keyboard monitor created before Accessibility approval can
            // remain silent. Recreate it as soon as macOS reports the new state.
            self.eventMonitor.start()

            if isTrusted {
                let readyMessage = self.preferences.selectionMethod == .holdShiftAndRelease
                    ? "ShiftGrid готов — нажмите Shift, затем удерживайте его"
                    : "ShiftGrid готов — дважды нажмите левый Shift"
                self.toastPresenter.show(
                    readyMessage,
                    on: ScreenMetrics.screenContainingMouse()
                )
            }
        }
        timer.tolerance = 0.2
        accessibilityRefreshTimer = timer
    }

    private func beginSelection(using selectionMethod: SelectionMethod) {
        if overlayController.isVisible {
            overlayController.dismiss()
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = ScreenMetrics.screenContainingMouse(mouseLocation) else {
            return
        }

        let targetResult = WindowMover.captureWindow(at: mouseLocation)
        guard case let .success(target) = targetResult else {
            if case let .failure(error) = targetResult {
                toastPresenter.show(error.localizedDescription, on: screen)
            }
            return
        }

        let pixelWidth = ScreenMetrics.displayPixelWidth(for: screen)
        let columnCount = LayoutPolicy.columnCount(
            mode: preferences.columnMode,
            displayPixelWidth: pixelWidth
        )
        let usableFrame = ScreenMetrics.usableFrame(for: screen)
        let spacingInPoints = ScreenMetrics.points(
            forPhysicalPixels: preferences.spacing,
            backingScaleFactor: screen.backingScaleFactor
        )
        let zoneFrames = ZoneLayout.frames(
            in: usableFrame,
            columnCount: columnCount,
            outerInset: spacingInPoints,
            gap: spacingInPoints,
            backingScaleFactor: screen.backingScaleFactor
        )
        let hitFrames = ZoneLayout.frames(
            in: usableFrame,
            columnCount: columnCount,
            outerInset: 0,
            gap: 0,
            backingScaleFactor: screen.backingScaleFactor
        )

        guard !zoneFrames.isEmpty, hitFrames.count == zoneFrames.count else {
            toastPresenter.show("Недостаточно места для выбранных промежутков", on: screen)
            return
        }

        overlayController.present(
            on: screen,
            globalZoneFrames: zoneFrames,
            globalHitFrames: hitFrames,
            selectionMethod: selectionMethod,
            onSelect: { [weak self] selection in
                guard let self,
                      let destinationFrame = selection.combinedFrame(in: zoneFrames) else {
                    return
                }
                WindowMover.move(target, to: destinationFrame) { [weak self] result in
                    if case let .failure(error) = result {
                        self?.toastPresenter.show(error.localizedDescription, on: screen)
                    }
                }
            },
            onCancel: { [weak self] in
                self?.eventMonitor.resetGesture()
            }
        )
    }

    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                preferences: preferences,
                onRequestAccessibility: { [weak self] in
                    self?.requestAccessibilityAndOpenSettings()
                }
            )
        }
        settingsWindowController?.showWindow(nil)
    }

    @objc private func requestAccessibilityFromMenu() {
        requestAccessibilityAndOpenSettings()
    }

    private func requestAccessibilityAndOpenSettings() {
        if !AccessibilityPermission.requestFromUserAction() {
            AccessibilityPermission.openSystemSettings()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func screenConfigurationChanged() {
        overlayController.dismiss()
    }

    @objc private func preferencesChanged() {
        eventMonitor.resetGesture()
        overlayController.dismiss()
    }
}
