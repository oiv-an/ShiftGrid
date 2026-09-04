import AppKit

enum OverlayGeometry {
    /// NSWindow's initializer with an explicit `screen` expects its origin to be
    /// relative to that screen, not in the global NSScreen coordinate space.
    static func screenRelativeContentRect(for screenFrame: CGRect) -> CGRect {
        CGRect(origin: .zero, size: screenFrame.size)
    }

    static func localZoneFrames(
        from globalFrames: [CGRect],
        screenFrame: CGRect
    ) -> [CGRect] {
        globalFrames.map { frame in
            frame.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
        }
    }

    static func localPoint(from globalPoint: CGPoint, screenFrame: CGRect) -> CGPoint {
        CGPoint(
            x: globalPoint.x - screenFrame.minX,
            y: globalPoint.y - screenFrame.minY
        )
    }
}

final class OverlayPanel: NSPanel {
    var acceptsKeyboardInput = false

    override var canBecomeKey: Bool { acceptsKeyboardInput }
    override var canBecomeMain: Bool { false }
}

final class ZoneOverlayView: NSView {
    var onSelect: ((ZoneSelection) -> Void)?
    var onCancel: (() -> Void)?
    var onPointerActivity: (() -> Void)?

    private let zoneFrames: [CGRect]
    private let hitFrames: [CGRect]
    private let selectionMethod: SelectionMethod
    private var mergeGestureTracker = ZoneMergeGestureTracker()
    private var currentSelection: ZoneSelection?
    private var trackingAreaReference: NSTrackingArea?

    init(
        frame: CGRect,
        zoneFrames: [CGRect],
        hitFrames: [CGRect],
        selectionMethod: SelectionMethod
    ) {
        self.zoneFrames = zoneFrames
        self.hitFrames = hitFrames
        self.selectionMethod = selectionMethod
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaReference = trackingArea
        super.updateTrackingAreas()
    }

    func updateSelection(at point: CGPoint) {
        let zoneIndex = zoneIndex(at: point)
        let newSelection: ZoneSelection?

        if selectionMethod == .holdShiftAndRelease {
            // Continue recognizing the upward stroke in the menu-bar strip.
            // This lets a gesture start even when the pointer is already near
            // the top edge of a window. A single-zone commit still requires the
            // pointer to be inside the actual zone.
            let gestureZoneIndex = zoneIndex ?? horizontallyProjectedZoneIndex(at: point)
            newSelection = mergeGestureTracker.update(point: point, zoneIndex: gestureZoneIndex)
        } else {
            newSelection = zoneIndex.map(ZoneSelection.init(singleIndex:))
        }

        guard newSelection != currentSelection else { return }
        currentSelection = newSelection
        needsDisplay = true
    }

    func zoneIndex(at point: CGPoint) -> Int? {
        hitFrames.firstIndex { $0.contains(point) }
    }

    private func horizontallyProjectedZoneIndex(at point: CGPoint) -> Int? {
        hitFrames.firstIndex { frame in
            point.x >= frame.minX && point.x < frame.maxX
        }
    }

    func selectionForCommit(at point: CGPoint) -> ZoneSelection? {
        updateSelection(at: point)
        guard let currentSelection else {
            return nil
        }

        if currentSelection.isMerged {
            return currentSelection
        }

        guard let zoneIndex = zoneIndex(at: point), currentSelection.contains(zoneIndex) else {
            return nil
        }

        return currentSelection
    }

    override func mouseEntered(with event: NSEvent) {
        updateSelection(at: convert(event.locationInWindow, from: nil))
        onPointerActivity?()
    }

    override func mouseMoved(with event: NSEvent) {
        updateSelection(at: convert(event.locationInWindow, from: nil))
        onPointerActivity?()
    }

    override func mouseExited(with event: NSEvent) {
        mergeGestureTracker.reset()
        currentSelection = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard selectionMethod == .click else {
            onCancel?()
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        guard let selectedIndex = zoneIndex(at: point) else {
            onCancel?()
            return
        }

        onSelect?(ZoneSelection(singleIndex: selectedIndex))
    }

    override func rightMouseDown(with event: NSEvent) {
        onCancel?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.20).setFill()
        bounds.fill()

        for (index, frame) in zoneFrames.enumerated() {
            guard currentSelection?.contains(index) != true else { continue }
            drawInactiveZone(number: index + 1, in: frame)
        }

        if let currentSelection,
           let selectionFrame = currentSelection.combinedFrame(in: zoneFrames) {
            drawActiveSelection(currentSelection, in: selectionFrame)
        }

        drawInstruction()
    }

    private func drawInactiveZone(number: Int, in frame: CGRect) {
        let path = NSBezierPath(rect: frame)
        NSColor.white.withAlphaComponent(0.14).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.50).setStroke()
        path.lineWidth = 1.5
        path.stroke()

        drawLabel(String(number), in: frame, isActive: false)
    }

    private func drawActiveSelection(_ selection: ZoneSelection, in frame: CGRect) {
        let path = NSBezierPath(rect: frame)
        NSColor.systemBlue.withAlphaComponent(0.55).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.95).setStroke()
        path.lineWidth = 3
        path.stroke()

        let label = selection.isMerged
            ? "\(selection.lowerIndex + 1) + \(selection.upperIndex + 1)"
            : String(selection.lowerIndex + 1)
        drawLabel(label, in: frame, isActive: true)
    }

    private func drawLabel(_ label: String, in frame: CGRect, isActive: Bool) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 42, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(isActive ? 1 : 0.68)
        ]
        let string = NSAttributedString(string: label, attributes: attributes)
        let size = string.size()
        string.draw(at: CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2))
    }

    private func drawInstruction() {
        let text: String
        if selectionMethod == .click {
            text = "Наведите курсор и щёлкните  •  Esc — отмена"
        } else if let currentSelection, currentSelection.isMerged {
            text = "Две области объединены  •  Отпустите Shift"
        } else {
            text = "Для двух областей: вверх, затем влево или вправо  •  Отпустите Shift"
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        let backgroundRect = CGRect(
            x: bounds.midX - size.width / 2 - 18,
            y: bounds.maxY - size.height - 26,
            width: size.width + 36,
            height: size.height + 12
        )

        NSColor.black.withAlphaComponent(0.62).setFill()
        NSBezierPath(roundedRect: backgroundRect, xRadius: 10, yRadius: 10).fill()
        string.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: backgroundRect.minY + 6))
    }
}

final class OverlayController {
    private(set) var isVisible = false

    private var panel: OverlayPanel?
    private var overlayView: ZoneOverlayView?
    private var screenFrame: CGRect?
    private var timeoutTimer: Timer?
    private var onSelect: ((ZoneSelection) -> Void)?
    private var onCancel: (() -> Void)?

    func present(
        on screen: NSScreen,
        globalZoneFrames: [CGRect],
        globalHitFrames: [CGRect],
        selectionMethod: SelectionMethod,
        onSelect: @escaping (ZoneSelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        dismiss(notifyCancellation: false)

        // Cover the entire display so the selector reads as a screen mode rather
        // than a floating window. The selectable zones themselves still use the
        // safe visibleFrame supplied by AppDelegate.
        let screenFrame = screen.frame
        let panelContentRect = OverlayGeometry.screenRelativeContentRect(for: screenFrame)
        let localFrames = OverlayGeometry.localZoneFrames(
            from: globalZoneFrames,
            screenFrame: screenFrame
        )
        let localHitFrames = OverlayGeometry.localZoneFrames(
            from: globalHitFrames,
            screenFrame: screenFrame
        )

        let panel = OverlayPanel(
            contentRect: panelContentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.acceptsKeyboardInput = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let overlayView = ZoneOverlayView(
            frame: panelContentRect,
            zoneFrames: localFrames,
            hitFrames: localHitFrames,
            selectionMethod: selectionMethod
        )
        overlayView.autoresizingMask = [.width, .height]
        overlayView.onSelect = { [weak self] selection in
            self?.select(selection)
        }
        overlayView.onCancel = { [weak self] in
            self?.dismiss(notifyCancellation: true)
        }
        overlayView.onPointerActivity = { [weak self] in
            if selectionMethod == .click {
                self?.restartTimeout()
            }
        }

        panel.contentView = overlayView
        self.panel = panel
        self.overlayView = overlayView
        self.screenFrame = screenFrame
        self.onSelect = onSelect
        self.onCancel = onCancel
        isVisible = true

        panel.orderFrontRegardless()
        panel.makeKey()

        let mouse = NSEvent.mouseLocation
        overlayView.updateSelection(
            at: OverlayGeometry.localPoint(from: mouse, screenFrame: screenFrame)
        )
        if selectionMethod == .click {
            restartTimeout()
        }
    }

    func commitSelectionAtCurrentPointer() {
        guard let overlayView, let screenFrame else { return }

        let mouse = NSEvent.mouseLocation
        let localPoint = OverlayGeometry.localPoint(from: mouse, screenFrame: screenFrame)
        guard let selection = overlayView.selectionForCommit(at: localPoint) else {
            dismiss(notifyCancellation: true)
            return
        }

        select(selection)
    }

    func dismiss(notifyCancellation: Bool = true) {
        guard isVisible || panel != nil else { return }

        let cancellation = onCancel
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        panel?.orderOut(nil)
        panel = nil
        overlayView = nil
        screenFrame = nil
        onSelect = nil
        onCancel = nil
        isVisible = false

        if notifyCancellation {
            cancellation?()
        }
    }

    private func select(_ selection: ZoneSelection) {
        guard isVisible else { return }
        let callback = onSelect
        dismiss(notifyCancellation: false)
        callback?(selection)
    }

    private func restartTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            self?.dismiss(notifyCancellation: true)
        }
    }
}

final class ToastPresenter {
    private var panel: OverlayPanel?
    private var closeWorkItem: DispatchWorkItem?

    func show(_ message: String, on screen: NSScreen?) {
        closeWorkItem?.cancel()
        panel?.orderOut(nil)

        guard let screen = screen ?? NSScreen.main ?? NSScreen.screens.first else {
            NSSound.beep()
            return
        }

        let label = NSTextField(wrappingLabelWithString: message)
        label.alignment = .center
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.maximumNumberOfLines = 2

        let width: CGFloat = 380
        let height: CGFloat = 72
        let frame = CGRect(
            x: screen.visibleFrame.midX - width / 2,
            y: screen.visibleFrame.maxY - height - 44,
            width: width,
            height: height
        )
        let panel = OverlayPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.82)
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let content = NSView(frame: CGRect(origin: .zero, size: frame.size))
        label.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: content.centerYAnchor)
        ])
        panel.contentView = content

        self.panel = panel
        panel.orderFrontRegardless()

        let closeWorkItem = DispatchWorkItem { [weak self, weak panel] in
            panel?.orderOut(nil)
            if self?.panel === panel {
                self?.panel = nil
            }
        }
        self.closeWorkItem = closeWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: closeWorkItem)
    }
}
