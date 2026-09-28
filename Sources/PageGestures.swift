import AppKit

struct MousePageDragState {
    enum Intent { case pending, page, rearrange }
    private(set) var source: Int?
    private(set) var intent: Intent = .pending
    private(set) var moved = false
    private var start: NSPoint?
    private var startedAt: TimeInterval = 0
    private var consumed = false
    var isActive: Bool { start != nil }

    mutating func begin(at point: NSPoint, source: Int?, time: TimeInterval) {
        self = MousePageDragState()
        start = point
        self.source = source
        startedAt = time
    }

    mutating func direction(at point: NSPoint, time: TimeInterval, layoutLocked: Bool) -> Int? {
        guard let start else { return nil }
        let dx = point.x - start.x, dy = point.y - start.y
        guard hypot(dx, dy) > 8 else { return nil }
        moved = true
        if intent == .pending {
            if source != nil && !layoutLocked && (time - startedAt >= 0.35 || abs(dy) > abs(dx) * 1.2) {
                intent = .rearrange
            } else if source == nil || layoutLocked || abs(dx) > abs(dy) * 1.2 {
                intent = .page
            }
        }
        guard intent == .page, !consumed, abs(dx) >= 64, abs(dx) > abs(dy) * 1.2 else { return nil }
        consumed = true
        return dx < 0 ? 1 : -1
    }
}

struct ThreeFingerSwipeState {
    static func nativeDirection(deltaX: CGFloat, deltaY: CGFloat) -> Int? {
        guard abs(deltaX) > abs(deltaY), abs(deltaX) > 0 else { return nil }
        // AppKit swipe deltaX is positive for a leftward swipe.
        return deltaX > 0 ? 1 : -1
    }
    private var origin: [AnyHashable: NSPoint] = [:]
    private var blocked = false
    private(set) var consumed = false
    var isTracking: Bool { !origin.isEmpty || blocked || consumed }

    mutating func consume() { consumed = true }
    mutating func reset() { self = ThreeFingerSwipeState() }

    mutating func direction(touches: [AnyHashable: NSPoint]) -> Int? {
        if touches.isEmpty { reset(); return nil }
        guard !blocked, !consumed else { return nil }
        if origin.isEmpty {
            if touches.count == 3 { origin = touches }
            else if touches.count > 3 { blocked = true }
            return nil
        }
        guard touches.count == 3, Set(touches.keys) == Set(origin.keys) else {
            blocked = true
            return nil
        }
        let deltas = touches.map { id, point in
            NSPoint(x: point.x - origin[id]!.x, y: point.y - origin[id]!.y)
        }
        let dx = deltas.reduce(0) { $0 + $1.x } / 3
        let dy = deltas.reduce(0) { $0 + $1.y } / 3
        guard abs(dx) >= 0.06, abs(dx) > abs(dy) * 1.5,
              deltas.allSatisfy({ $0.x * dx > 0 }) else { return nil }
        consumed = true
        return dx < 0 ? 1 : -1
    }
}
