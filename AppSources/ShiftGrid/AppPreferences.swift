import AppKit

enum ColumnMode: String, CaseIterable {
    case automatic
    case two
    case three

    var title: String {
        switch self {
        case .automatic:
            return "Автоматически (2 или 3)"
        case .two:
            return "Всегда 2"
        case .three:
            return "Всегда 3"
        }
    }
}

enum SelectionMethod: String, CaseIterable {
    case holdShiftAndRelease
    case click

    var title: String {
        switch self {
        case .holdShiftAndRelease:
            return "Удерживать Shift и отпустить"
        case .click:
            return "Навести и щёлкнуть"
        }
    }
}

enum LayoutPolicy {
    static let automaticPixelThreshold = 3_000

    static func columnCount(mode: ColumnMode, displayPixelWidth: Int) -> Int {
        switch mode {
        case .automatic:
            return displayPixelWidth >= automaticPixelThreshold ? 3 : 2
        case .two:
            return 2
        case .three:
            return 3
        }
    }
}

extension Notification.Name {
    static let shiftGridPreferencesDidChange = Notification.Name("ShiftGridPreferencesDidChange")
}

final class AppPreferences {
    private enum Key {
        static let columnMode = "columnMode"
        static let spacing = "spacing"
        static let selectionMethod = "selectionMethod"
        static let layoutDefaultsRevision = "layoutDefaultsRevision"
    }

    private static let currentLayoutDefaultsRevision = 3

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.columnMode: ColumnMode.automatic.rawValue,
            Key.spacing: 2,
            Key.selectionMethod: SelectionMethod.holdShiftAndRelease.rawValue,
            Key.layoutDefaultsRevision: 0
        ])

        let layoutDefaultsRevision = defaults.integer(forKey: Key.layoutDefaultsRevision)
        if layoutDefaultsRevision < 2 {
            defaults.set(0, forKey: Key.spacing)
        }
        if layoutDefaultsRevision < 3, defaults.integer(forKey: Key.spacing) == 0 {
            defaults.set(2, forKey: Key.spacing)
        }
        if layoutDefaultsRevision < Self.currentLayoutDefaultsRevision {
            defaults.set(Self.currentLayoutDefaultsRevision, forKey: Key.layoutDefaultsRevision)
        }
    }

    var columnMode: ColumnMode {
        get {
            ColumnMode(rawValue: defaults.string(forKey: Key.columnMode) ?? "") ?? .automatic
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.columnMode)
            notifyChange()
        }
    }

    var spacing: CGFloat {
        get {
            CGFloat(max(0, min(30, defaults.integer(forKey: Key.spacing))))
        }
        set {
            defaults.set(Int(newValue.rounded()).clamped(to: 0 ... 30), forKey: Key.spacing)
            notifyChange()
        }
    }

    var selectionMethod: SelectionMethod {
        get {
            SelectionMethod(rawValue: defaults.string(forKey: Key.selectionMethod) ?? "")
                ?? .holdShiftAndRelease
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.selectionMethod)
            notifyChange()
        }
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .shiftGridPreferencesDidChange, object: self)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
