import CoreGraphics

struct ZoneSelection: Equatable {
    let lowerIndex: Int
    let upperIndex: Int

    init(singleIndex: Int) {
        lowerIndex = singleIndex
        upperIndex = singleIndex
    }

    init?(joining firstIndex: Int, _ secondIndex: Int) {
        guard abs(firstIndex - secondIndex) == 1 else { return nil }
        lowerIndex = min(firstIndex, secondIndex)
        upperIndex = max(firstIndex, secondIndex)
    }

    var isMerged: Bool {
        lowerIndex != upperIndex
    }

    func contains(_ index: Int) -> Bool {
        lowerIndex ... upperIndex ~= index
    }

    func combinedFrame(in zoneFrames: [CGRect]) -> CGRect? {
        guard zoneFrames.indices.contains(lowerIndex),
              zoneFrames.indices.contains(upperIndex) else {
            return nil
        }

        return (lowerIndex ... upperIndex)
            .dropFirst()
            .reduce(zoneFrames[lowerIndex]) { frame, index in
                frame.union(zoneFrames[index])
            }
    }
}

struct ZoneMergeGestureTracker {
    private enum Phase {
        case idle
        case tracking(zoneIndex: Int, origin: CGPoint)
        case armed(zoneIndex: Int, turnPoint: CGPoint)
        case merged(ZoneSelection)
    }

    let requiredUpwardDistance: CGFloat
    let requiredHorizontalDistance: CGFloat
    let verticalStrokeHorizontalTolerance: CGFloat
    let horizontalStrokeVerticalTolerance: CGFloat

    private var phase: Phase = .idle
    private(set) var selection: ZoneSelection?

    init(
        requiredUpwardDistance: CGFloat = 48,
        requiredHorizontalDistance: CGFloat = 72,
        verticalStrokeHorizontalTolerance: CGFloat = 44,
        horizontalStrokeVerticalTolerance: CGFloat = 80
    ) {
        self.requiredUpwardDistance = requiredUpwardDistance
        self.requiredHorizontalDistance = requiredHorizontalDistance
        self.verticalStrokeHorizontalTolerance = verticalStrokeHorizontalTolerance
        self.horizontalStrokeVerticalTolerance = horizontalStrokeVerticalTolerance
    }

    @discardableResult
    mutating func update(point: CGPoint, zoneIndex: Int?) -> ZoneSelection? {
        switch phase {
        case .idle:
            guard let zoneIndex else {
                selection = nil
                return nil
            }
            return beginTracking(zoneIndex: zoneIndex, at: point)

        case let .tracking(trackedZoneIndex, origin):
            guard let zoneIndex else {
                phase = .idle
                selection = nil
                return nil
            }

            guard zoneIndex == trackedZoneIndex else {
                return beginTracking(zoneIndex: zoneIndex, at: point)
            }

            let horizontalMovement = point.x - origin.x
            let upwardMovement = point.y - origin.y
            let singleSelection = ZoneSelection(singleIndex: zoneIndex)
            selection = singleSelection

            if upwardMovement >= requiredUpwardDistance,
               abs(horizontalMovement) <= verticalStrokeHorizontalTolerance {
                phase = .armed(zoneIndex: zoneIndex, turnPoint: point)
            } else if upwardMovement < 0
                || abs(horizontalMovement) > verticalStrokeHorizontalTolerance {
                // Follow ordinary pointer movement until a clear upward stroke
                // begins inside one zone. This prevents diagonal travel across
                // the grid from accidentally joining zones.
                phase = .tracking(zoneIndex: zoneIndex, origin: point)
            }

            return singleSelection

        case let .armed(anchorIndex, turnPoint):
            guard let zoneIndex else {
                if abs(point.y - turnPoint.y) <= horizontalStrokeVerticalTolerance {
                    selection = ZoneSelection(singleIndex: anchorIndex)
                    return selection
                }

                phase = .idle
                selection = nil
                return nil
            }

            if zoneIndex == anchorIndex {
                if point.y > turnPoint.y {
                    phase = .armed(zoneIndex: anchorIndex, turnPoint: point)
                } else if point.y < turnPoint.y - horizontalStrokeVerticalTolerance {
                    return beginTracking(zoneIndex: anchorIndex, at: point)
                }

                selection = ZoneSelection(singleIndex: zoneIndex)
                return selection
            }

            let horizontalMovement = point.x - turnPoint.x
            let movesTowardAdjacentZone = zoneIndex > anchorIndex
                ? horizontalMovement >= requiredHorizontalDistance
                : horizontalMovement <= -requiredHorizontalDistance

            if abs(zoneIndex - anchorIndex) == 1,
               abs(point.y - turnPoint.y) <= horizontalStrokeVerticalTolerance {
                if movesTowardAdjacentZone,
                   let mergedSelection = ZoneSelection(joining: anchorIndex, zoneIndex) {
                    phase = .merged(mergedSelection)
                    selection = mergedSelection
                    return mergedSelection
                }

                // The cursor may cross a nearby boundary before the horizontal
                // leg is long enough. Keep the armed corner until it travels the
                // required distance inside the adjacent zone.
                selection = ZoneSelection(singleIndex: zoneIndex)
                return selection
            }

            return beginTracking(zoneIndex: zoneIndex, at: point)

        case let .merged(mergedSelection):
            // Once the deliberate L gesture is complete, keep the two-zone
            // result stable until Shift is released or the overlay is cancelled.
            selection = mergedSelection
            return mergedSelection
        }
    }

    mutating func reset() {
        phase = .idle
        selection = nil
    }

    @discardableResult
    private mutating func beginTracking(zoneIndex: Int, at point: CGPoint) -> ZoneSelection {
        let singleSelection = ZoneSelection(singleIndex: zoneIndex)
        phase = .tracking(zoneIndex: zoneIndex, origin: point)
        selection = singleSelection
        return singleSelection
    }
}
