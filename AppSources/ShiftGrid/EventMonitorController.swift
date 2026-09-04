import AppKit

enum SelectionGesturePolicy {
    static let minimumHoldToCommit: TimeInterval = 0.12

    static func shouldCommitHold(duration: TimeInterval) -> Bool {
        duration >= minimumHoldToCommit
    }

    static func shouldOpenClickSelector(duration: TimeInterval, maximumTap: TimeInterval) -> Bool {
        duration >= 0 && duration <= maximumTap
    }
}

final class EventMonitorController {
    var selectionMethod: (() -> SelectionMethod)?
    var onClickSelectionRequested: (() -> Void)?
    var onHoldSelectionBegan: (() -> Void)?
    var onHoldSelectionEnded: (() -> Void)?
    var onCancelOverlay: (() -> Void)?
    var isOverlayVisible: (() -> Bool)?

    private var detector = DoubleShiftDetector()
    private var activeSelectionMethod: SelectionMethod?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() {
        stop()

        let mask: NSEvent.EventTypeMask = [
            .flagsChanged,
            .keyDown,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .scrollWheel
        ]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event, isLocal: false)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else { return event }
            return self.handle(event, isLocal: true) ? nil : event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        resetGesture()
    }

    func resetGesture() {
        detector.interrupt()
        activeSelectionMethod = nil
    }

    deinit {
        stop()
    }

    @discardableResult
    private func handle(_ event: NSEvent, isLocal: Bool) -> Bool {
        switch event.type {
        case .flagsChanged:
            let relevantFlags = event.modifierFlags.intersection([.command, .control, .option, .function])
            // Use the flags stored on this event instead of querying the current
            // keyboard state. Global events are asynchronous, so the physical key
            // may already be up by the time the handler runs.
            let isDown = event.modifierFlags.contains(.shift)
            let shiftEvent = detector.processShiftChange(
                keyCode: event.keyCode,
                isDown: isDown,
                hasConflictingModifiers: !relevantFlags.isEmpty,
                timestamp: event.timestamp
            )

            switch shiftEvent {
            case .none:
                break

            case .secondPressBegan:
                let method = selectionMethod?() ?? .holdShiftAndRelease
                activeSelectionMethod = method
                if method == .holdShiftAndRelease {
                    onHoldSelectionBegan?()
                }

            case let .secondPressEnded(holdDuration):
                let method = activeSelectionMethod
                activeSelectionMethod = nil

                switch method {
                case .holdShiftAndRelease:
                    if SelectionGesturePolicy.shouldCommitHold(duration: holdDuration) {
                        onHoldSelectionEnded?()
                    } else {
                        onCancelOverlay?()
                    }
                case .click:
                    if SelectionGesturePolicy.shouldOpenClickSelector(
                        duration: holdDuration,
                        maximumTap: detector.maximumHold
                    ) {
                        onClickSelectionRequested?()
                    }
                case nil:
                    break
                }

            case .cancelled:
                let hadActiveHoldGesture = activeSelectionMethod == .holdShiftAndRelease
                activeSelectionMethod = nil
                if hadActiveHoldGesture, isOverlayVisible?() == true {
                    onCancelOverlay?()
                }
            }

        case .keyDown:
            resetGesture()
            if isOverlayVisible?() == true {
                onCancelOverlay?()
                return isLocal
            }

        case .leftMouseDown:
            resetGesture()
            if !isLocal, isOverlayVisible?() == true {
                onCancelOverlay?()
            }

        case .rightMouseDown, .otherMouseDown:
            resetGesture()
            if isOverlayVisible?() == true {
                onCancelOverlay?()
                return isLocal
            }

        case .scrollWheel:
            resetGesture()
            if isOverlayVisible?() == true {
                onCancelOverlay?()
            }

        default:
            break
        }

        return false
    }
}
