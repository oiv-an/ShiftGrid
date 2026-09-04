import Foundation

enum DoubleShiftEvent: Equatable {
    case none
    case secondPressBegan
    case secondPressEnded(holdDuration: TimeInterval)
    case cancelled
}

struct DoubleShiftDetector {
    static let leftShiftKeyCode: UInt16 = 56

    let maximumGap: TimeInterval
    let maximumHold: TimeInterval

    private var activeKeyCode: UInt16?
    private var activePressBeganAt: TimeInterval?
    private var previousTapEndedAt: TimeInterval?
    private var isCompletingSecondTap = false

    init(maximumGap: TimeInterval = 0.4, maximumHold: TimeInterval = 0.35) {
        self.maximumGap = maximumGap
        self.maximumHold = maximumHold
    }

    mutating func processShiftChange(
        keyCode: UInt16,
        isDown: Bool,
        hasConflictingModifiers: Bool,
        timestamp: TimeInterval
    ) -> DoubleShiftEvent {
        guard keyCode == Self.leftShiftKeyCode else {
            interrupt()
            return .cancelled
        }

        guard !hasConflictingModifiers else {
            interrupt()
            return .cancelled
        }

        if isDown {
            guard activeKeyCode == nil else {
                interrupt()
                return .cancelled
            }

            activeKeyCode = keyCode
            activePressBeganAt = timestamp

            if let previousTapEndedAt,
               timestamp - previousTapEndedAt <= maximumGap,
               timestamp >= previousTapEndedAt {
                isCompletingSecondTap = true
                return .secondPressBegan
            } else {
                previousTapEndedAt = nil
                isCompletingSecondTap = false
            }

            return .none
        }

        guard activeKeyCode == keyCode, let activePressBeganAt else {
            interrupt()
            return .cancelled
        }

        let holdDuration = timestamp - activePressBeganAt
        activeKeyCode = nil
        self.activePressBeganAt = nil

        guard holdDuration >= 0 else {
            interrupt()
            return .cancelled
        }

        if isCompletingSecondTap {
            interrupt()
            return .secondPressEnded(holdDuration: holdDuration)
        }

        guard holdDuration <= maximumHold else {
            interrupt()
            return .cancelled
        }

        previousTapEndedAt = timestamp
        return .none
    }

    mutating func interrupt() {
        activeKeyCode = nil
        activePressBeganAt = nil
        previousTapEndedAt = nil
        isCompletingSecondTap = false
    }
}
