import AppKit
import ApplicationServices

struct WindowTarget {
    let element: AXUIElement
}

enum WindowMoveError: LocalizedError {
    case accessibilityRequired
    case noWindowUnderPointer
    case fullScreenWindow
    case fixedWindow
    case operationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired:
            return "Разрешите ShiftGrid управлять окнами в настройках macOS"
        case .noWindowUnderPointer:
            return "Под курсором нет окна, которое можно переместить"
        case .fullScreenWindow:
            return "Сначала выйдите из полноэкранного режима"
        case .fixedWindow:
            return "Это окно нельзя переместить или изменить"
        case .operationFailed:
            return "Приложение не позволило изменить размер окна"
        }
    }
}

enum WindowGeometryVerification {
    static let tolerance: CGFloat = 2

    static func matches(
        actualPosition: CGPoint,
        desiredPosition: CGPoint,
        tolerance: CGFloat = 2
    ) -> Bool {
        abs(actualPosition.x - desiredPosition.x) <= tolerance
            && abs(actualPosition.y - desiredPosition.y) <= tolerance
    }

    static func matches(
        actualSize: CGSize,
        desiredSize: CGSize,
        tolerance: CGFloat = 2
    ) -> Bool {
        abs(actualSize.width - desiredSize.width) <= tolerance
            && abs(actualSize.height - desiredSize.height) <= tolerance
    }

    static func matches(
        actualPosition: CGPoint,
        actualSize: CGSize,
        desiredPosition: CGPoint,
        desiredSize: CGSize,
        tolerance: CGFloat = 2
    ) -> Bool {
        matches(
            actualPosition: actualPosition,
            desiredPosition: desiredPosition,
            tolerance: tolerance
        ) && matches(
            actualSize: actualSize,
            desiredSize: desiredSize,
            tolerance: tolerance
        )
    }
}

enum WindowGeometryPlan {
    static func preparatorySize(current: CGSize, desired: CGSize) -> CGSize {
        CGSize(
            width: min(current.width, desired.width),
            height: min(current.height, desired.height)
        )
    }
}

private final class WindowMoveOperation {
    private static let maximumAttempts = 3
    private static let positionSettleDelay: TimeInterval = 0.04
    private static let geometrySettleDelay: TimeInterval = 0.06

    private let element: AXUIElement
    private let desiredPosition: CGPoint
    private let desiredSize: CGSize
    private let positionValue: AXValue
    private let sizeValue: AXValue
    private let originalPosition: CFTypeRef
    private let originalSize: CFTypeRef
    private let completion: (Result<Void, WindowMoveError>) -> Void

    private var isFinished = false

    init(
        element: AXUIElement,
        desiredPosition: CGPoint,
        desiredSize: CGSize,
        positionValue: AXValue,
        sizeValue: AXValue,
        originalPosition: CFTypeRef,
        originalSize: CFTypeRef,
        completion: @escaping (Result<Void, WindowMoveError>) -> Void
    ) {
        self.element = element
        self.desiredPosition = desiredPosition
        self.desiredSize = desiredSize
        self.positionValue = positionValue
        self.sizeValue = sizeValue
        self.originalPosition = originalPosition
        self.originalSize = originalSize
        self.completion = completion
    }

    func start() {
        attemptPositionThenResize(number: 1)
    }

    private func attemptPositionThenResize(number: Int) {
        guard !isFinished, AccessibilityPermission.isTrusted else {
            finishWithFailure()
            return
        }

        guard let currentSize = sizeAttribute(kAXSizeAttribute as CFString) else {
            retryOrFail(after: number)
            return
        }

        // Shrink only the dimensions that would otherwise keep macOS from
        // placing the window at the requested edge. Growing happens after the
        // new position has settled, so a right-to-left span cannot be clamped.
        var preparatorySize = WindowGeometryPlan.preparatorySize(
            current: currentSize,
            desired: desiredSize
        )
        guard let preparatorySizeValue = AXValueCreate(.cgSize, &preparatorySize),
              set(kAXSizeAttribute as CFString, to: preparatorySizeValue) else {
            retryOrFail(after: number)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.positionSettleDelay) { [self] in
            guard !isFinished else { return }

            guard let actualSize = sizeAttribute(kAXSizeAttribute as CFString),
                  WindowGeometryVerification.matches(
                    actualSize: actualSize,
                    desiredSize: preparatorySize
                  ),
                  set(kAXPositionAttribute as CFString, to: positionValue) else {
                retryOrFail(after: number)
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + Self.positionSettleDelay) { [self] in
                guard !isFinished,
                      let actualPosition = pointAttribute(kAXPositionAttribute as CFString),
                      WindowGeometryVerification.matches(
                        actualPosition: actualPosition,
                        desiredPosition: desiredPosition
                      ),
                      set(kAXSizeAttribute as CFString, to: sizeValue),
                      set(kAXPositionAttribute as CFString, to: positionValue) else {
                    retryOrFail(after: number)
                    return
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + Self.geometrySettleDelay) { [self] in
                    verifyOrRetry(after: number)
                }
            }
        }
    }

    private func verifyOrRetry(after attemptNumber: Int) {
        guard !isFinished,
              let actualPosition = pointAttribute(kAXPositionAttribute as CFString),
              let actualSize = sizeAttribute(kAXSizeAttribute as CFString) else {
            retryOrFail(after: attemptNumber)
            return
        }

        if WindowGeometryVerification.matches(
            actualPosition: actualPosition,
            actualSize: actualSize,
            desiredPosition: desiredPosition,
            desiredSize: desiredSize
        ) {
            isFinished = true
            AXUIElementPerformAction(element, kAXRaiseAction as CFString)
            completion(.success(()))
        } else {
            retryOrFail(after: attemptNumber)
        }
    }

    private func retryOrFail(after attemptNumber: Int) {
        guard !isFinished else { return }

        if attemptNumber < Self.maximumAttempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.positionSettleDelay) { [self] in
                attemptPositionThenResize(number: attemptNumber + 1)
            }
        } else {
            finishWithFailure()
        }
    }

    private func finishWithFailure() {
        guard !isFinished else { return }
        isFinished = true

        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, originalPosition)
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, originalSize)
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, originalPosition)
        completion(.failure(.operationFailed))
    }

    private func set(_ attribute: CFString, to value: CFTypeRef) -> Bool {
        AXUIElementSetAttributeValue(element, attribute, value) == .success
    }

    private func pointAttribute(_ attribute: CFString) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgPoint else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
    }

    private func sizeAttribute(_ attribute: CFString) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgSize else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
    }

}

enum WindowMover {

    static func captureWindow(at appKitPoint: CGPoint) -> Result<WindowTarget, WindowMoveError> {
        guard AccessibilityPermission.isTrusted else {
            return .failure(.accessibilityRequired)
        }

        let menuBarScreen = NSScreen.screens.first { $0.frame.origin == .zero }
            ?? NSScreen.screens.first
        guard let menuBarScreen else {
            return .failure(.noWindowUnderPointer)
        }

        let accessibilityPoint = AccessibilityCoordinateSpace.topLeftPoint(
            for: appKitPoint,
            menuBarScreenTop: menuBarScreen.frame.maxY
        )
        let systemWideElement = AXUIElementCreateSystemWide()
        var hitElement: AXUIElement?

        let hitTestResult = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(accessibilityPoint.x),
            Float(accessibilityPoint.y),
            &hitElement
        )

        guard hitTestResult == .success,
              let hitElement,
              let window = containingWindow(for: hitElement) else {
            return .failure(.noWindowUnderPointer)
        }

        var processIdentifier: pid_t = 0
        guard AXUIElementGetPid(window, &processIdentifier) == .success,
              processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return .failure(.noWindowUnderPointer)
        }

        if booleanAttribute("AXFullScreen" as CFString, of: window) == true {
            return .failure(.fullScreenWindow)
        }

        var positionIsSettable = DarwinBoolean(false)
        var sizeIsSettable = DarwinBoolean(false)
        let positionResult = AXUIElementIsAttributeSettable(
            window,
            kAXPositionAttribute as CFString,
            &positionIsSettable
        )
        let sizeResult = AXUIElementIsAttributeSettable(
            window,
            kAXSizeAttribute as CFString,
            &sizeIsSettable
        )

        guard positionResult == .success,
              sizeResult == .success,
              positionIsSettable.boolValue,
              sizeIsSettable.boolValue else {
            return .failure(.fixedWindow)
        }

        return .success(WindowTarget(element: window))
    }

    private static func containingWindow(for element: AXUIElement) -> AXUIElement? {
        if stringAttribute(kAXRoleAttribute as CFString, of: element) == kAXWindowRole as String {
            return element
        }

        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXWindowAttribute as CFString,
            &windowValue
        ) == .success,
        let windowValue,
        CFGetTypeID(windowValue) == AXUIElementGetTypeID() else {
            return nil
        }

        let window = windowValue as! AXUIElement
        guard stringAttribute(kAXRoleAttribute as CFString, of: window) == kAXWindowRole as String else {
            return nil
        }

        return window
    }

    static func move(
        _ target: WindowTarget,
        to appKitFrame: CGRect,
        completion: @escaping (Result<Void, WindowMoveError>) -> Void
    ) {
        guard AccessibilityPermission.isTrusted else {
            completion(.failure(.accessibilityRequired))
            return
        }

        let menuBarScreen = NSScreen.screens.first { $0.frame.origin == .zero }
            ?? NSScreen.screens.first
        guard let menuBarScreen else {
            completion(.failure(.operationFailed))
            return
        }

        var position = AccessibilityCoordinateSpace.topLeftPosition(
            for: appKitFrame,
            menuBarScreenTop: menuBarScreen.frame.maxY
        )
        var size = appKitFrame.size

        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            completion(.failure(.operationFailed))
            return
        }

        var originalPosition: CFTypeRef?
        var originalSize: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            target.element,
            kAXPositionAttribute as CFString,
            &originalPosition
        ) == .success,
        AXUIElementCopyAttributeValue(
            target.element,
            kAXSizeAttribute as CFString,
            &originalSize
        ) == .success,
        let originalPosition,
        let originalSize else {
            completion(.failure(.operationFailed))
            return
        }

        let operation = WindowMoveOperation(
            element: target.element,
            desiredPosition: position,
            desiredSize: size,
            positionValue: positionValue,
            sizeValue: sizeValue,
            originalPosition: originalPosition,
            originalSize: originalSize,
            completion: completion
        )
        operation.start()
    }

    private static func booleanAttribute(_ attribute: CFString, of element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let number = value as? NSNumber else {
            return nil
        }

        return number.boolValue
    }

    private static func stringAttribute(_ attribute: CFString, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value = value as? String else {
            return nil
        }

        return value
    }
}
