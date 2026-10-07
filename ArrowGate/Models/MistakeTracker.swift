import Foundation

/// One penalty per arrow, per attempt. Board changes never charge a marked arrow again.
struct MistakeTracker {
    private(set) var penalized: Set<Int> = []
    mutating func register(arrowID: Int) -> Bool { penalized.insert(arrowID).inserted }
    mutating func reset() { penalized.removeAll() }
}
