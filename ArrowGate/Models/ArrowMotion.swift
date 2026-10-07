import Foundation

struct MotionPoint: Equatable {
    let x: Double
    let y: Double
    func advanced(dx: Double, dy: Double) -> MotionPoint { MotionPoint(x: x + dx, y: y + dy) }
}

/// A fixed-length ribbon sliding along its own body, then along the head's exit lane.
struct ArrowMotion {
    let vertices: [MotionPoint]
    let distances: [Double]
    let length: Double
    let direction: Direction
    init(_ arrow: ArrowDefinition) {
        direction = arrow.direction
        let cells = arrow.cells
        let tail = cells.last!
        let previous = cells.count > 1 ? cells[cells.count - 2] : tail.moved(arrow.direction)
        var points = [MotionPoint(x: Double(tail.x) + Double(tail.x - previous.x) * 0.30,
                                  y: Double(tail.y) + Double(tail.y - previous.y) * 0.30)]
        points += cells.reversed().map { MotionPoint(x: Double($0.x), y: Double($0.y)) }
        points.append(MotionPoint(x: Double(arrow.head.x) + Double(direction.dx) * 0.30,
                                  y: Double(arrow.head.y) + Double(direction.dy) * 0.30))
        // Keep only actual corners: redundant collinear joins leave tiny seams in SpriteKit strokes.
        var corners: [MotionPoint] = []
        for point in points {
            if corners.count >= 2 {
                let a = corners[corners.count - 2], b = corners[corners.count - 1]
                let cross = (b.x - a.x) * (point.y - b.y) - (b.y - a.y) * (point.x - b.x)
                if abs(cross) < 0.00001 { corners.removeLast() }
            }
            corners.append(point)
        }
        points = corners
        var sums = [0.0]
        for pair in zip(points, points.dropFirst()) {
            sums.append(sums.last! + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y))
        }
        vertices = points; distances = sums; length = sums.last!
    }
    func point(at distance: Double) -> MotionPoint {
        if distance >= length {
            return vertices.last!.advanced(dx: Double(direction.dx) * (distance - length),
                                           dy: Double(direction.dy) * (distance - length))
        }
        for index in 1..<vertices.count where distance <= distances[index] {
            let fraction = max(0, distance - distances[index - 1]) / (distances[index] - distances[index - 1])
            let a = vertices[index - 1], b = vertices[index]
            return a.advanced(dx: (b.x - a.x) * fraction, dy: (b.y - a.y) * fraction)
        }
        return vertices[0]
    }
    func points(travel: Double) -> [MotionPoint] {
        let start = max(0, travel), end = start + length
        var result = [point(at: start)]
        for index in vertices.indices where distances[index] > start && distances[index] < end {
            result.append(vertices[index])
        }
        result.append(point(at: end))
        return result
    }
    func firstIntersection(from origin: MotionPoint, direction: Direction) -> Double? {
        let dx = Double(direction.dx), dy = Double(direction.dy)
        var hits: [Double] = []
        for pair in zip(vertices, vertices.dropFirst()) {
            let a = pair.0, b = pair.1
            let alongA = (a.x - origin.x) * dx + (a.y - origin.y) * dy
            let alongB = (b.x - origin.x) * dx + (b.y - origin.y) * dy
            let sideA = -(a.x - origin.x) * dy + (a.y - origin.y) * dx
            let sideB = -(b.x - origin.x) * dy + (b.y - origin.y) * dx
            if abs(sideA) < 0.00001 && abs(sideB) < 0.00001 {
                if max(alongA, alongB) >= 0 { hits.append(max(0, min(alongA, alongB))) }
            } else if sideA * sideB <= 0 && abs(sideA - sideB) > 0.00001 {
                let t = sideA / (sideA - sideB)
                let along = alongA + (alongB - alongA) * t
                if along >= 0 { hits.append(along) }
            }
        }
        return hits.min()
    }
    /// Ease in gently and retain momentum through the portal (no stop at its mouth).
    static func slideProgress(_ t: Double) -> Double { t * t * (2 - t) }
}
