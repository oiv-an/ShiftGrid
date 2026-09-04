import AppKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let preferences: AppPreferences
    private let onRequestAccessibility: () -> Void

    private let introLabel = NSTextField(wrappingLabelWithString: "")
    private let selectionPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let modePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let spacingSlider = NSSlider(value: 2, minValue: 0, maxValue: 30, target: nil, action: nil)
    private let spacingValueLabel = NSTextField(labelWithString: "2")
    private let permissionLabel = NSTextField(labelWithString: "")

    init(preferences: AppPreferences, onRequestAccessibility: @escaping () -> Void) {
        self.preferences = preferences
        self.onRequestAccessibility = onRequestAccessibility

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Настройки ShiftGrid"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
        buildContent()
        refreshControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        refreshControls()
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(sender)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        refreshPermissionStatus()
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }

        let title = NSTextField(labelWithString: "Разделение экрана")
        title.font = .systemFont(ofSize: 22, weight: .semibold)

        introLabel.textColor = .secondaryLabelColor

        selectionPopup.addItems(withTitles: SelectionMethod.allCases.map(\.title))
        selectionPopup.target = self
        selectionPopup.action = #selector(selectionMethodChanged)

        modePopup.addItems(withTitles: ColumnMode.allCases.map(\.title))
        modePopup.target = self
        modePopup.action = #selector(modeChanged)

        spacingSlider.numberOfTickMarks = 31
        spacingSlider.allowsTickMarkValuesOnly = true
        spacingSlider.target = self
        spacingSlider.action = #selector(spacingChanged)

        spacingValueLabel.alignment = .right
        spacingValueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)

        let spacingRow = NSStackView(views: [spacingSlider, spacingValueLabel])
        spacingRow.orientation = .horizontal
        spacingRow.spacing = 12
        spacingSlider.widthAnchor.constraint(equalToConstant: 190).isActive = true
        spacingValueLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true

        let selectionLabel = NSTextField(labelWithString: "Выбор области:")
        let modeLabel = NSTextField(labelWithString: "Количество колонок:")
        let spacingLabel = NSTextField(labelWithString: "Отступы и промежутки:")
        let grid = NSGridView(views: [
            [selectionLabel, selectionPopup],
            [modeLabel, modePopup],
            [spacingLabel, spacingRow]
        ])
        grid.columnSpacing = 18
        grid.rowSpacing = 16
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading

        let autoExplanation = NSTextField(wrappingLabelWithString:
            "В автоматическом режиме экран от 3000 пикселей по ширине делится на 3 части, меньший — на 2. Размеры окон задаются в координатах macOS."
        )
        autoExplanation.textColor = .tertiaryLabelColor
        autoExplanation.font = .systemFont(ofSize: 12)

        let permissionButton = NSButton(
            title: "Открыть Универсальный доступ…",
            target: self,
            action: #selector(requestAccessibility)
        )
        permissionButton.bezelStyle = .rounded

        let permissionRow = NSStackView(views: [permissionLabel, permissionButton])
        permissionRow.orientation = .horizontal
        permissionRow.alignment = .centerY
        permissionRow.spacing = 12

        let stack = NSStackView(views: [title, introLabel, grid, autoExplanation, permissionRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 26),
            introLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            autoExplanation.widthAnchor.constraint(equalTo: stack.widthAnchor),
            permissionRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        permissionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        permissionButton.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func refreshControls() {
        if let index = SelectionMethod.allCases.firstIndex(of: preferences.selectionMethod) {
            selectionPopup.selectItem(at: index)
        }
        if let index = ColumnMode.allCases.firstIndex(of: preferences.columnMode) {
            modePopup.selectItem(at: index)
        }
        spacingSlider.doubleValue = Double(preferences.spacing)
        spacingValueLabel.stringValue = "\(Int(preferences.spacing)) px"
        refreshIntro()
        refreshPermissionStatus()
    }

    private func refreshIntro() {
        switch preferences.selectionMethod {
        case .holdShiftAndRelease:
            introLabel.stringValue = "Наведите курсор на окно. Быстро нажмите левый Shift один раз, затем нажмите его второй раз и удерживайте. Для двух областей проведите вверх, затем влево или вправо. Отпустите Shift для переноса."
        case .click:
            introLabel.stringValue = "Наведите курсор на окно, дважды нажмите левый Shift, затем наведите курсор на нужную область и щёлкните."
        }
    }

    private func refreshPermissionStatus() {
        permissionLabel.stringValue = AccessibilityPermission.isTrusted
            ? "Управление окнами: разрешено"
            : "Управление окнами: требуется разрешение"
        permissionLabel.textColor = AccessibilityPermission.isTrusted ? .systemGreen : .systemOrange
    }

    @objc private func modeChanged() {
        let index = max(0, modePopup.indexOfSelectedItem)
        preferences.columnMode = ColumnMode.allCases[index]
    }

    @objc private func selectionMethodChanged() {
        let index = max(0, selectionPopup.indexOfSelectedItem)
        preferences.selectionMethod = SelectionMethod.allCases[index]
        refreshIntro()
    }

    @objc private func spacingChanged() {
        preferences.spacing = CGFloat(spacingSlider.doubleValue)
        spacingValueLabel.stringValue = "\(Int(preferences.spacing)) px"
    }

    @objc private func requestAccessibility() {
        onRequestAccessibility()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refreshPermissionStatus()
        }
    }
}
