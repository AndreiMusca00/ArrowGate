import SpriteKit
import UIKit

final class GameScene: SKScene, UIGestureRecognizerDelegate {
    var onTap: ((Int) -> Void)?
    var inputEnabled = true
    private var level: LevelDefinition!
    private var arrowNodes: [Int: SKNode] = [:]
    private var travels: [Int: Double] = [:]
    private var motions: [Int: ArrowMotion] = [:]
    private var arrowHeadTextures: [String: SKTexture] = [:]
    private var tapRippleTextures: [String: SKTexture] = [:]
    private var guideDots: [Cell: SKShapeNode] = [:]
    private var targetColors: [Cell: ArrowColor]?
    private var exiting: Set<Int> = []
    private var warned: Set<Int> = []
    private let boardCamera = SKCameraNode()
    private var arrowLayer = SKNode()
    private var paintLayer = SKCropNode()
    private struct PaintedMark {
        let dot: SKShapeNode
        let color: UIColor
        let order: Int
    }
    private var paintedCells: [Cell: PaintedMark] = [:]
    private var paintSequence = 0
    private var fragmentLayer = SKNode()
    private var tapFeedbackLayer = SKNode()
    private var tutorial = SKNode()
    private var gestures: [UIGestureRecognizer] = []
    private var closestCameraScale: CGFloat = 1
    private var furthestCameraScale: CGFloat = 1
    private var initialCameraScale: CGFloat = 1
    private var pinchStartScale: CGFloat = 1
    private(set) var isIntroducing = false
    private var needsIntroduction = true
    private var skipsIntroduction: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-skip-board-intro")
        #else
        return false
        #endif
    }
    private var boardWidth: CGFloat { CGFloat(level.size) * GameStyle.cellSize }
    private var boardHeight: CGFloat { CGFloat(level.height) * GameStyle.cellSize }
    private var worldBounds: CGRect {
        CGRect(x: -GameStyle.worldMargin, y: -GameStyle.worldMargin,
               width: boardWidth + GameStyle.worldMargin * 2, height: boardHeight + GameStyle.worldMargin * 2)
    }
    var zoomFactor: CGFloat { furthestCameraScale / boardCamera.xScale }
    var accessibilitySummary: String {
        guard level != nil else { return "Puzzle board" }
        return "Level \(level.id); arrows \(arrowNodes.count - exiting.count); pending \(exiting.count); warnings \(warned.count); painted \(paintedCells.count); zoom \(String(format: "%.1f", Double(zoomFactor)))"
    }
    private func updateAccessibility() { view?.accessibilityValue = accessibilitySummary }

    func configure(level: LevelDefinition) {
        boardCamera.removeAllActions(); isIntroducing = false; needsIntroduction = true
        removeAllActions(); removeAllChildren()
        self.level = level; exiting = []; warned = []
        arrowNodes = [:]; motions = [:]; travels = [:]
        guideDots = [:]; paintedCells = [:]; paintSequence = 0
        targetColors = level.targetCells.map {
            Dictionary(uniqueKeysWithValues: $0.map { ($0.cell, $0.color) })
        }
        scaleMode = .resizeFill; backgroundColor = GameStyle.sceneBackground
        addChild(boardCamera); camera = boardCamera
        drawGrid()
        paintLayer = SKCropNode(); paintLayer.zPosition = 0
        let paintMask = SKShapeNode(rect: CGRect(x: 0, y: 0, width: boardWidth, height: boardHeight))
        paintMask.fillColor = .white; paintMask.strokeColor = .clear
        paintLayer.maskNode = paintMask; addChild(paintLayer)
        arrowLayer = SKNode(); arrowLayer.zPosition = 5; addChild(arrowLayer)
        fragmentLayer = SKNode(); fragmentLayer.zPosition = 7; addChild(fragmentLayer)
        tapFeedbackLayer = SKNode(); tapFeedbackLayer.zPosition = 12; addChild(tapFeedbackLayer)
        tutorial = SKNode(); tutorial.zPosition = 15; addChild(tutorial)
        for arrow in level.arrows { drawArrow(arrow) }
        resetViewport()
        if view != nil { introduceBoard() }
        updateAccessibility()
    }
    override func didMove(to view: SKView) {
        size = view.bounds.size
        view.isMultipleTouchEnabled = true
        view.isAccessibilityElement = true; view.accessibilityIdentifier = "board"
        view.accessibilityLabel = "Puzzle board"
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panBoard(_:)))
        pan.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(zoomBoard(_:)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapBoard(_:)))
        tap.require(toFail: pan); tap.require(toFail: pinch)
        gestures = [pan, pinch, tap]
        for gesture in gestures { gesture.delegate = self; view.addGestureRecognizer(gesture) }
        resetViewport(); needsIntroduction = true; introduceBoard(); updateAccessibility()
    }
    override func willMove(from view: SKView) {
        for gesture in gestures { view.removeGestureRecognizer(gesture) }
        gestures.removeAll()
    }
    override func didChangeSize(_ oldSize: CGSize) {
        if level != nil {
            let shouldIntroduce = needsIntroduction || isIntroducing
            resetViewport()
            if shouldIntroduce && !gestures.isEmpty {
                needsIntroduction = true; introduceBoard()
            }
        }
    }
    func resetViewport() {
        guard level != nil,
              size.width > GameStyle.cameraHorizontalInset,
              size.height > GameStyle.cameraHorizontalInset else { return }
        boardCamera.removeAction(forKey: "introduction"); isIntroducing = false
        let usableWidth = size.width - GameStyle.cameraHorizontalInset
        closestCameraScale = GameStyle.closestVisibleColumns * GameStyle.cellSize / usableWidth
        furthestCameraScale = GameStyle.furthestVisibleColumns * GameStyle.cellSize / usableWidth
        initialCameraScale = (closestCameraScale + furthestCameraScale) / 2
        boardCamera.setScale(furthestCameraScale)
        boardCamera.position = CGPoint(x: boardWidth / 2, y: boardHeight / 2)
        updateAccessibility()
    }
    private func introduceBoard() {
        guard needsIntroduction, view != nil else { return }
        needsIntroduction = false
        guard !skipsIntroduction, !UIAccessibility.isReduceMotionEnabled else {
            boardCamera.setScale(initialCameraScale)
            clampCamera()
            return
        }
        // Begin with the widest allowed overview, then settle halfway through the
        // 15–28-column zoom range while keeping the authored board centred.
        isIntroducing = true
        let zoom = SKAction.scale(to: initialCameraScale, duration: GameStyle.introDuration)
        zoom.timingMode = .easeInEaseOut
        boardCamera.run(.sequence([.wait(forDuration: 0.25), zoom, .run { [weak self] in
            self?.isIntroducing = false; self?.clampCamera()
        }]), withKey: "introduction")
    }
    private func interruptIntroduction() {
        boardCamera.removeAction(forKey: "introduction")
        isIntroducing = false
    }
    private func clampCamera() {
        let halfWidth = size.width * boardCamera.xScale / 2
        let halfHeight = size.height * boardCamera.yScale / 2
        let bounds = worldBounds
        boardCamera.position.x = bounds.width <= halfWidth * 2 ? bounds.midX : min(max(boardCamera.position.x, bounds.minX + halfWidth), bounds.maxX - halfWidth)
        boardCamera.position.y = bounds.height <= halfHeight * 2 ? bounds.midY : min(max(boardCamera.position.y, bounds.minY + halfHeight), bounds.maxY - halfHeight)
        updateAccessibility()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool { inputEnabled && !isPaused }
    @objc private func panBoard(_ gesture: UIPanGestureRecognizer) {
        guard inputEnabled, let view else { return }
        interruptIntroduction()
        let offset = gesture.translation(in: view)
        boardCamera.position.x -= offset.x * boardCamera.xScale
        boardCamera.position.y += offset.y * boardCamera.yScale
        gesture.setTranslation(.zero, in: view); clampCamera()
    }
    @objc private func zoomBoard(_ gesture: UIPinchGestureRecognizer) {
        guard inputEnabled, let view else { return }
        if gesture.state == .began { interruptIntroduction(); pinchStartScale = boardCamera.xScale }
        let location = gesture.location(in: view)
        let anchor = convertPoint(fromView: location)
        boardCamera.setScale(min(furthestCameraScale,
                                 max(closestCameraScale, pinchStartScale / gesture.scale)))
        let movedAnchor = convertPoint(fromView: location)
        boardCamera.position.x += anchor.x - movedAnchor.x
        boardCamera.position.y += anchor.y - movedAnchor.y
        clampCamera()
    }
    @objc private func tapBoard(_ gesture: UITapGestureRecognizer) {
        guard inputEnabled, let view, gesture.state == .ended else { return }
        interruptIntroduction()
        let location = convertPoint(fromView: gesture.location(in: view))
        let cell = Cell(x: Int(floor(location.x / GameStyle.cellSize)), y: Int(floor(location.y / GameStyle.cellSize)))
        let tappedArrow = level.contains(cell) ? level.arrows.first(where: {
            arrowNodes[$0.id] != nil && !exiting.contains($0.id) && $0.cells.contains(cell)
        }) : nil
        let feedbackColor = tappedArrow.map { GameStyle.uiColor($0.color) } ?? GameStyle.portalWell
        showTapFeedback(at: location, color: feedbackColor)
        guard level.contains(cell) else { return }
        if let tappedArrow { onTap?(tappedArrow.id) }
    }
    private func showTapFeedback(at point: CGPoint, color: UIColor) {
        let feedback = SKNode()
        feedback.position = point
        // Counter the camera zoom so the touch indicator keeps a stable size on screen.
        feedback.setScale(boardCamera.xScale)

        let wave = SKNode()
        wave.setScale(0.18)
        let wash = SKSpriteNode(texture: tapRippleTexture(color: color),
                                size: CGSize(width: 16, height: 16))
        wave.addChild(wash)
        let ring = SKShapeNode(circleOfRadius: 6.4)
        ring.fillColor = .clear
        ring.strokeColor = color.withAlphaComponent(0.42)
        ring.lineWidth = 1.15
        wave.addChild(ring)
        feedback.addChild(wave)

        let core = SKShapeNode(circleOfRadius: 1.45)
        core.fillColor = color.withAlphaComponent(0.58)
        core.strokeColor = .clear
        feedback.addChild(core)
        tapFeedbackLayer.addChild(feedback)

        if UIAccessibility.isReduceMotionEnabled {
            feedback.setScale(boardCamera.xScale)
            wave.setScale(0.72)
            feedback.run(.sequence([.fadeOut(withDuration: 0.20), .removeFromParent()]))
            return
        }

        let expand = SKAction.scale(to: 1.9, duration: 0.34)
        expand.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.27)
        fade.timingMode = .easeOut
        wave.run(.group([expand, .sequence([.wait(forDuration: 0.07), fade])]))
        core.run(.sequence([
            .scale(to: 1.14, duration: 0.07),
            .group([.scale(to: 0.72, duration: 0.16), .fadeOut(withDuration: 0.16)])
        ]))
        feedback.run(.sequence([.wait(forDuration: 0.36), .removeFromParent()]))
    }
    private func tapRippleTexture(color: UIColor) -> SKTexture {
        let key = color.description
        if let texture = tapRippleTextures[key] { return texture }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 6
        format.opaque = false
        let size = CGSize(width: 20, height: 20)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let cg = renderer.cgContext
            let colors = [
                color.withAlphaComponent(0.34).cgColor,
                color.withAlphaComponent(0.22).cgColor,
                color.withAlphaComponent(0.07).cgColor,
                color.withAlphaComponent(0).cgColor
            ] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors,
                                            locations: [0, 0.30, 0.72, 1]) else { return }
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            cg.drawRadialGradient(gradient, startCenter: centre, startRadius: 0,
                                  endCenter: centre, endRadius: size.width / 2,
                                  options: [.drawsAfterEndLocation])
        }
        let texture = SKTexture(cgImage: image.cgImage!)
        texture.filteringMode = .linear
        tapRippleTextures[key] = texture
        return texture
    }
    private func point(_ cell: Cell) -> CGPoint {
        CGPoint(x: (CGFloat(cell.x) + 0.5) * GameStyle.cellSize, y: (CGFloat(cell.y) + 0.5) * GameStyle.cellSize)
    }
    private func drawGrid() {
        let grid = SKNode()
        grid.name = "guideGrid"
        grid.zPosition = -1
        let origin = GameStyle.cellSize / 2
        for x in 0..<level.size {
            for y in 0..<level.height {
                let cell = Cell(x: x, y: y)
                guard level.contains(cell) else { continue }
                let centre = CGPoint(x: origin + CGFloat(x) * GameStyle.cellSize,
                                     y: origin + CGFloat(y) * GameStyle.cellSize)
                let dot = SKShapeNode(circleOfRadius: GameStyle.arrowWidth / 2)
                dot.position = centre
                dot.fillColor = GameStyle.guideDot
                dot.strokeColor = .clear
                grid.addChild(dot)
                guideDots[cell] = dot
            }
        }
        addChild(grid)
    }
    private struct ArrowPaths {
        let body: [CGPoint]
        let tip: CGPoint
        let direction: Direction
        let showsHead: Bool
    }
    private func arrowPaths(_ arrow: ArrowDefinition, travel: Double = 0,
                            clippingAt impact: CGPoint? = nil) -> ArrowPaths {
        let points = (motions[arrow.id] ?? ArrowMotion(arrow)).points(travel: travel)
        let local = points.map { CGPoint(x: ($0.x - Double(arrow.head.x)) * Double(GameStyle.cellSize),
                                         y: ($0.y - Double(arrow.head.y)) * Double(GameStyle.cellSize)) }
        let tip = local.last!, dx = CGFloat(arrow.direction.dx), dy = CGFloat(arrow.direction.dy)
        if let impact {
            let origin = point(arrow.head)
            let boundary = CGPoint(x: impact.x - origin.x, y: impact.y - origin.y)
            return ArrowPaths(body: clip(local, at: boundary, direction: arrow.direction),
                              tip: tip, direction: arrow.direction, showsHead: false)
        }
        let base = CGPoint(x: tip.x - dx * 7, y: tip.y - dy * 7)
        var body = Array(local.dropLast())
        // Preserve the final corner and append a dedicated shaft endpoint. Replacing
        // the last corner would connect the preceding turn diagonally to the head.
        // The shaft uses a flat leading cap and ends just inside the triangle base.
        // This hides the join without letting the segment project toward the tip.
        let shaftEnd = CGPoint(x: base.x + dx * 0.45, y: base.y + dy * 0.45)
        body.append(shaftEnd)
        return ArrowPaths(body: body, tip: tip, direction: arrow.direction, showsHead: true)
    }

    private func clip(_ points: [CGPoint], at boundary: CGPoint, direction: Direction) -> [CGPoint] {
        guard let first = points.first else { return [] }
        let dx = CGFloat(direction.dx), dy = CGFloat(direction.dy)
        func distance(_ point: CGPoint) -> CGFloat {
            (point.x - boundary.x) * dx + (point.y - boundary.y) * dy
        }
        guard distance(first) <= 0 else { return [] }
        var result = [first]
        for point in points.dropFirst() {
            let previous = result.last!
            let previousDistance = distance(previous)
            let currentDistance = distance(point)
            if currentDistance <= 0 {
                result.append(point)
            } else {
                let fraction = previousDistance / (previousDistance - currentDistance)
                result.append(CGPoint(x: previous.x + (point.x - previous.x) * fraction,
                                      y: previous.y + (point.y - previous.y) * fraction))
                break
            }
        }
        return result
    }

    private func render(_ arrow: ArrowDefinition, node: SKNode, travel: Double,
                        clippingAt impact: CGPoint? = nil) {
        travels[arrow.id] = travel
        let paths = arrowPaths(arrow, travel: travel, clippingAt: impact)
        for name in ["body", "hint", "warning"] {
            guard let ink = node.childNode(withName: name) else { continue }
            if name != "body", ink.isHidden { continue }
            layoutArrowInk(ink, paths: paths)
        }
    }
    private func arrowInk(name: String, paths: ArrowPaths, color: UIColor,
                          width: CGFloat) -> SKNode {
        let ink = SKNode(); ink.name = name
        ink.userData = ["width": width, "color": color]
        let line = SKSpriteNode(); line.name = "line"; ink.addChild(line)
        let head = SKSpriteNode(texture: arrowHeadTexture(color: color),
                                size: CGSize(width: 7, height: 9))
        head.name = "head"; head.zPosition = 1
        head.zRotation = CGFloat(paths.direction.rawValue) * .pi / 2
        ink.addChild(head)
        layoutArrowInk(ink, paths: paths)
        return ink
    }
    private func arrowHeadTexture(color: UIColor) -> SKTexture {
        let key = color.description
        if let texture = arrowHeadTextures[key] { return texture }
        let format = UIGraphicsImageRendererFormat()
        // Covers the maximum board zoom on a Retina display without magnifying the
        // low-resolution texture SpriteKit creates internally for SKShapeNode.
        format.scale = 12; format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: 7, height: 9), format: format).image { context in
            context.cgContext.setAllowsAntialiasing(true)
            context.cgContext.setShouldAntialias(true)
            let vertices = [CGPoint(x: 7, y: 4.5), CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 9)]
            let cornerInset: CGFloat = 1.2
            func insetPoint(from vertex: CGPoint, toward target: CGPoint) -> CGPoint {
                let dx = target.x - vertex.x, dy = target.y - vertex.y
                let length = max(0.0001, hypot(dx, dy))
                return CGPoint(x: vertex.x + dx / length * cornerInset,
                               y: vertex.y + dy / length * cornerInset)
            }
            let triangle = UIBezierPath()
            triangle.move(to: insetPoint(from: vertices[0], toward: vertices[2]))
            for index in vertices.indices {
                let vertex = vertices[index]
                let previous = vertices[(index + vertices.count - 1) % vertices.count]
                let next = vertices[(index + 1) % vertices.count]
                triangle.addLine(to: insetPoint(from: vertex, toward: previous))
                triangle.addQuadCurve(to: insetPoint(from: vertex, toward: next), controlPoint: vertex)
            }
            triangle.close()
            color.setFill(); triangle.fill()
        }
        let texture = SKTexture(cgImage: image.cgImage!); texture.filteringMode = .linear
        arrowHeadTextures[key] = texture
        return texture
    }
    private func layoutArrowInk(_ ink: SKNode, paths: ArrowPaths) {
        guard let line = ink.childNode(withName: "line") as? SKSpriteNode,
              let width = ink.userData?["width"] as? CGFloat,
              let color = ink.userData?["color"] as? UIColor else { return }
        ink.childNode(withName: "head")?.isHidden = !paths.showsHead
        guard paths.body.count >= 2, let first = paths.body.first else {
            line.isHidden = true
            return
        }
        line.isHidden = false
        let centreline = CGMutablePath()
        centreline.move(to: first)
        for point in paths.body.dropFirst() { centreline.addLine(to: point) }
        // Rasterize the complete vector stroke at high resolution. Updating an
        // SKShapeNode path in-place can briefly retain its previous antialiased
        // geometry, which looks like a white line while an arrow is moving.
        let padding = width / 2 + 0.5
        let bounds = centreline.boundingBoxOfPath.insetBy(dx: -padding, dy: -padding)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 12; format.opaque = false
        let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
            let cg = context.cgContext
            cg.setAllowsAntialiasing(true); cg.setShouldAntialias(true)
            cg.translateBy(x: -bounds.minX, y: bounds.maxY)
            cg.scaleBy(x: 1, y: -1)
            cg.addPath(centreline)
            cg.setLineWidth(width); cg.setLineCap(.butt); cg.setLineJoin(.round)
            cg.setStrokeColor(color.cgColor); cg.strokePath()
            // The tail stays rounded, while the shaft's leading edge remains flat
            // beneath the filled head instead of projecting through its tip.
            cg.setFillColor(color.cgColor)
            cg.fillEllipse(in: CGRect(x: first.x - width / 2, y: first.y - width / 2,
                                      width: width, height: width))
        }
        let texture = SKTexture(cgImage: image.cgImage!); texture.filteringMode = .linear
        line.texture = texture; line.size = bounds.size
        line.position = CGPoint(x: bounds.midX, y: bounds.midY)
        let dx = CGFloat(paths.direction.dx), dy = CGFloat(paths.direction.dy)
        let head = ink.childNode(withName: "head")
        head?.position = CGPoint(x: paths.tip.x - dx * 3.5,
                                 y: paths.tip.y - dy * 3.5)
    }
    private func drawArrow(_ arrow: ArrowDefinition) {
        let node = SKNode(); node.name = "arrow.\(arrow.id)"; node.position = point(arrow.head)
        motions[arrow.id] = ArrowMotion(arrow)
        let paths = arrowPaths(arrow)
        let warning = arrowInk(name: "warning", paths: paths,
                               color: UIColor(red: 0.98, green: 0.16, blue: 0.22, alpha: 1),
                               width: GameStyle.arrowWidth)
        warning.zPosition = 4; warning.alpha = 0; warning.isHidden = true; node.addChild(warning)
        let glow = arrowInk(name: "hint", paths: paths,
                            color: GameStyle.uiColor(arrow.color).withAlphaComponent(0.22),
                            width: 5)
        glow.zPosition = 2; glow.isHidden = true; node.addChild(glow)
        // The shaft overlaps the filled head, so SpriteKit never exposes their join.
        let body = arrowInk(name: "body", paths: paths, color: GameStyle.uiColor(arrow.color),
                            width: GameStyle.arrowWidth)
        body.zPosition = 3; node.addChild(body)
        arrowLayer.addChild(node); arrowNodes[arrow.id] = node
    }
    func markBlocked(_ ids: Set<Int>) {
        let previouslyWarned = warned
        warned = ids
        for (id, node) in arrowNodes {
            let isWarned = ids.contains(id)
            guard let warning = node.childNode(withName: "warning") else { continue }
            if isWarned {
                warning.isHidden = false
                if !previouslyWarned.contains(id) {
                    warning.removeAction(forKey: "warningState")
                    warning.setScale(1)
                    warning.alpha = 0
                    let fade = SKAction.fadeAlpha(to: 1, duration: 0.22)
                    fade.timingMode = .easeInEaseOut
                    warning.run(fade, withKey: "warningState")
                } else {
                    warning.removeAction(forKey: "warningState")
                    warning.setScale(1)
                    warning.alpha = 1
                }
            } else if previouslyWarned.contains(id), !warning.isHidden {
                warning.removeAction(forKey: "warningState")
                warning.setScale(1)
                let fade = SKAction.fadeOut(withDuration: 0.14)
                fade.timingMode = .easeInEaseOut
                warning.run(.sequence([fade, .run { [weak warning] in
                    warning?.isHidden = true
                    warning?.alpha = 0
                }]), withKey: "warningState")
            } else {
                warning.removeAction(forKey: "warningState")
                warning.setScale(1)
                warning.isHidden = true
                warning.alpha = 0
            }
            if isWarned, let arrow = level.arrows.first(where: { $0.id == id }) {
                render(arrow, node: node, travel: travels[id] ?? 0)
            }
        }
        updateAccessibility()
    }
    private func clearHint() {
        tutorial.removeAllActions(); tutorial.removeAllChildren()
        for (id, node) in arrowNodes where !exiting.contains(id) {
            node.removeAction(forKey: "hint"); node.setScale(1)
            node.childNode(withName: "hint")?.isHidden = true
        }
    }
    func highlight(_ id: Int, tutorial: Bool = false) {
        clearHint()
        guard let node = arrowNodes[id] else { return }
        node.childNode(withName: "hint")?.isHidden = false
        node.run(.repeatForever(.sequence([.scale(to: 1.06, duration: 0.45), .scale(to: 1, duration: 0.45)])), withKey: "hint")
        if tutorial, let arrow = level.arrows.first(where: { $0.id == id }) {
            let finger = SKLabelNode(text: "☝︎"); finger.fontSize = 12; finger.fontColor = GameStyle.portalWell
            finger.position = point(arrow.head); finger.position.y -= 13
            finger.run(.repeatForever(.sequence([.moveBy(x: 0, y: 2, duration: 0.45), .moveBy(x: 0, y: -2, duration: 0.45)])))
            self.tutorial.addChild(finger)
        }
    }
    func remove(_ arrow: ArrowDefinition, completion: @escaping () -> Void) {
        clearHint()
        guard let node = arrowNodes[arrow.id] else { completion(); return }
        exiting.insert(arrow.id); updateAccessibility()
        node.removeAction(forKey: "reject"); node.setScale(1)
        let direction = arrow.direction
        let start = travels[arrow.id] ?? 0
        let paintEvents = paintEvents(for: arrow)
        var nextPaintEvent = paintEvents.firstIndex(where: { $0.distance >= start }) ?? paintEvents.count
        let impact = puzzleExit(for: arrow)
        let contact = max(start, impact.travel)
        let ribbonLength = motions[arrow.id]?.length ?? Double(max(1, arrow.cells.count))
        let shatterEnd = contact + ribbonLength
        // Painting and shattering now share the puzzle's logical boundary, so the
        // effect stays correct while the camera is zoomed or moving.
        let paintingEnd = (paintEvents.last?.distance ?? contact) + 0.08
        // The head leaves the puzzle first. Keep advancing by the complete ribbon
        // length so every remaining segment visibly breaks at that same boundary.
        let travel = max(shatterEnd + 0.45, paintingEnd)
        let duration = max(GameStyle.exitDuration, 0.16 + (travel - start) * 0.038)
        var nextShatter = contact
        let slide = SKAction.customAction(withDuration: duration) { [weak self] node, elapsed in
            guard let self else { return }
            let distance = start + ArrowMotion.takeoffProgress(min(1, Double(elapsed) / duration)) * (travel - start)
            self.render(arrow, node: node, travel: distance,
                        clippingAt: distance >= contact ? impact.point : nil)
            while nextPaintEvent < paintEvents.count, distance >= paintEvents[nextPaintEvent].distance {
                self.paint(paintEvents[nextPaintEvent].cell, color: arrow.color)
                nextPaintEvent += 1
            }
            // A stream of small bursts consumes the shaft as it crosses the board
            // boundary. No artificial wall is drawn at the exit point.
            while distance >= nextShatter, nextShatter <= shatterEnd {
                self.boundaryShatter(at: impact.point, direction: direction, color: arrow.color,
                                     particleCount: nextShatter == contact ? GameStyle.confettiCount : 3)
                nextShatter += 0.70
            }
            node.alpha = 1
        }
        node.run(.sequence([slide, .wait(forDuration: GameStyle.confettiDuration), .run { [weak self, weak node] in
            guard let self else { return }
            node?.removeFromParent()
            self.arrowNodes.removeValue(forKey: arrow.id); self.exiting.remove(arrow.id); self.warned.remove(arrow.id)
            self.updateAccessibility(); completion()
        }]), withKey: "exit")
    }
    private struct PaintEvent {
        let distance: Double
        let cell: Cell
    }
    private func paintEvents(for arrow: ArrowDefinition) -> [PaintEvent] {
        var events = arrow.cells.reversed().enumerated().map {
            PaintEvent(distance: 0.30 + Double($0.offset), cell: $0.element)
        }
        var cell = arrow.head.moved(arrow.direction)
        var distance = 0.30 + Double(max(0, arrow.cells.count - 1)) + 1
        while level.contains(cell) {
            events.append(PaintEvent(distance: distance, cell: cell))
            cell = cell.moved(arrow.direction); distance += 1
        }
        return events
    }
    private func puzzleExit(for arrow: ArrowDefinition) -> (travel: Double, point: CGPoint) {
        // Follow the same active-cell geometry used by the puzzle rules. This also
        // supports triangular and otherwise irregular boards.
        var lastCell = arrow.head
        var nextCell = lastCell.moved(arrow.direction)
        while level.contains(nextCell) {
            lastCell = nextCell
            nextCell = nextCell.moved(arrow.direction)
        }

        let origin = point(arrow.head)
        let initialTip = CGPoint(x: origin.x + CGFloat(arrow.direction.dx) * GameStyle.cellSize * 0.30,
                                 y: origin.y + CGFloat(arrow.direction.dy) * GameStyle.cellSize * 0.30)
        let lastCentre = point(lastCell)
        let boundary = CGPoint(
            x: lastCentre.x + CGFloat(arrow.direction.dx) * GameStyle.cellSize / 2,
            y: lastCentre.y + CGFloat(arrow.direction.dy) * GameStyle.cellSize / 2
        )
        let along = arrow.direction.dx == 0
            ? (boundary.y - initialTip.y) * CGFloat(arrow.direction.dy)
            : (boundary.x - initialTip.x) * CGFloat(arrow.direction.dx)
        let travel = max(0, Double(along / GameStyle.cellSize))
        return (travel, boundary)
    }
    private func paint(_ cell: Cell, color: ArrowColor) {
        guard level.contains(cell), let dot = guideDots[cell] else { return }
        // Authored paintings are revealed only by the intended colour. A different
        // arrow may cross this cell without changing either the guide or a colour
        // that was already revealed here.
        if let targetColors, targetColors[cell] != color { return }
        let targetColor = GameStyle.uiColor(color)
        paintSequence += 1
        let startColor = dot.fillColor

        // Animate the original guide circle itself. Keeping one vector node for
        // the entire lifetime avoids the uneven edge produced by a tiny overlay
        // texture when the camera sits between pixel boundaries.
        dot.removeAllActions()
        dot.alpha = 1
        dot.setScale(1)
        paintedCells[cell] = PaintedMark(dot: dot, color: targetColor, order: paintSequence)

        let colorTransition = SKAction.customAction(withDuration: 0.14) { node, elapsed in
            guard let shape = node as? SKShapeNode else { return }
            let progress = min(1, CGFloat(elapsed / 0.14))
            shape.fillColor = Self.interpolate(startColor, targetColor, progress: progress)
        }

        let firstPulse = SKAction.scale(to: 2.15, duration: 0.10); firstPulse.timingMode = .easeOut
        let firstSettle = SKAction.scale(to: 1, duration: 0.17); firstSettle.timingMode = .easeInEaseOut
        let secondPulse = SKAction.scale(to: 1.32, duration: 0.08); secondPulse.timingMode = .easeOut
        let secondSettle = SKAction.scale(to: 1, duration: 0.14); secondSettle.timingMode = .easeInEaseOut
        dot.run(.group([
            colorTransition,
            .sequence([firstPulse, firstSettle, secondPulse, secondSettle])
        ]), withKey: "paintPulse")
        updateAccessibility()
    }
    private static func interpolate(_ from: UIColor, _ to: UIColor, progress: CGFloat) -> UIColor {
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        from.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        to.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        return UIColor(red: fr + (tr - fr) * progress,
                       green: fg + (tg - fg) * progress,
                       blue: fb + (tb - fb) * progress,
                       alpha: fa + (ta - fa) * progress)
    }
    func revealPainting(completion: @escaping () -> Void) {
        inputEnabled = false; interruptIntroduction(); boardCamera.removeAllActions()
        let centre = CGPoint(x: boardWidth / 2, y: boardHeight / 2)
        let zoomDuration: TimeInterval = 0.46
        let fillStart = zoomDuration + 0.10
        var finalDelay: TimeInterval = 0
        var tiles: [SKSpriteNode] = []

        tutorial.run(.fadeOut(withDuration: 0.20))
        for (cell, dot) in guideDots where paintedCells[cell] == nil {
            dot.run(.sequence([.wait(forDuration: fillStart), .fadeOut(withDuration: 0.22)]))
        }

        for (cell, mark) in paintedCells {
            let distance = hypot(CGFloat(cell.x) - CGFloat(level.size - 1) / 2,
                                 CGFloat(cell.y) - CGFloat(level.height - 1) / 2)
            let waveDelay = min(0.28, Double(distance) * 0.035)
            let delay = fillStart + waveDelay
            finalDelay = max(finalDelay, delay)

            mark.dot.removeAllActions()
            let dotLift = SKAction.scale(to: 1.55, duration: 0.09); dotLift.timingMode = .easeOut
            mark.dot.run(.sequence([.wait(forDuration: delay), dotLift,
                                    .fadeOut(withDuration: 0.18), .removeFromParent()]))

            let tile = SKSpriteNode(color: mark.color,
                                    size: CGSize(width: GameStyle.cellSize + 0.15,
                                                 height: GameStyle.cellSize + 0.15))
            tile.position = point(cell); tile.zPosition = CGFloat(mark.order) * 0.001
            tile.alpha = 0; tile.setScale(1.2 / GameStyle.cellSize)
            paintLayer.addChild(tile)
            tiles.append(tile)
            let startScale = 1.2 / GameStyle.cellSize
            let transform = SKAction.customAction(withDuration: 0.30) { node, elapsed in
                let t = min(1, CGFloat(elapsed / 0.30))
                let shifted = t - 1
                let progress = 1 + 2.10 * shifted * shifted * shifted + 1.10 * shifted * shifted
                node.setScale(startScale + (1 - startScale) * progress)
                node.alpha = min(1, t * 4)
            }
            tile.run(.sequence([.wait(forDuration: delay), transform,
                                .scale(to: 1, duration: 0.08)]), withKey: "finalFill")
        }
        let zoomOut = SKAction.group([
            .scale(to: furthestCameraScale, duration: zoomDuration),
            .move(to: centre, duration: zoomDuration)
        ])
        zoomOut.timingMode = .easeInEaseOut
        let revealEnd = finalDelay + 0.38
        let completionDelay: TimeInterval
        if level.completionArtwork != nil || level.rewardEmoji != nil {
            let morphStart = revealEnd + 0.28
            let wipeDuration: TimeInterval = 0.92
            let artworkSize = min(boardWidth, boardHeight) * 0.94
            let artwork: SKNode
            if let artworkName = level.completionArtwork {
                let sprite = SKSpriteNode(imageNamed: artworkName)
                sprite.size = CGSize(width: artworkSize, height: artworkSize)
                artwork = sprite
            } else {
                let emoji = SKLabelNode(fontNamed: "AppleColorEmoji")
                emoji.text = level.rewardEmoji
                emoji.fontSize = artworkSize * 0.72
                emoji.horizontalAlignmentMode = .center
                emoji.verticalAlignmentMode = .center
                artwork = emoji
            }
            artwork.position = .zero

            // Reveal the polished artwork behind a left-to-right mask. This makes
            // the final transformation read as one continuous sweep instead of a
            // cross-fade between two unrelated images.
            let artworkReveal = SKCropNode()
            artworkReveal.position = centre
            artworkReveal.zPosition = 20
            artworkReveal.setScale(0.985)
            let revealMask = SKSpriteNode(color: .white,
                                          size: CGSize(width: artworkSize, height: artworkSize))
            revealMask.anchorPoint = CGPoint(x: 0, y: 0.5)
            revealMask.position = CGPoint(x: -artworkSize / 2, y: 0)
            revealMask.xScale = 0.001
            artworkReveal.maskNode = revealMask
            artworkReveal.addChild(artwork)
            paintLayer.addChild(artworkReveal)

            for tile in tiles {
                let progress = min(1, max(0, (tile.position.x - (centre.x - artworkSize / 2)) / artworkSize))
                let tileDelay = morphStart + Double(progress) * wipeDuration
                let towardCentre = CGPoint(
                    x: tile.position.x + (centre.x - tile.position.x) * 0.035,
                    y: tile.position.y + (centre.y - tile.position.y) * 0.035
                )
                let gather = SKAction.group([
                    .move(to: towardCentre, duration: 0.18),
                    .scale(to: 0.72, duration: 0.18),
                    .fadeOut(withDuration: 0.16)
                ])
                gather.timingMode = .easeInEaseOut
                tile.run(.sequence([.wait(forDuration: tileDelay), gather,
                                    .removeFromParent()]), withKey: "artworkMorph")
            }

            let uncover = SKAction.scaleX(to: 1, duration: wipeDuration)
            uncover.timingMode = .easeInEaseOut
            revealMask.run(.sequence([.wait(forDuration: morphStart), uncover]),
                           withKey: "artworkWipe")
            let breathe = SKAction.scale(to: 1.015, duration: wipeDuration)
            breathe.timingMode = .easeInEaseOut
            let settle = SKAction.scale(to: 1, duration: 0.18)
            settle.timingMode = .easeInEaseOut
            artworkReveal.run(.sequence([.wait(forDuration: morphStart), breathe, settle]),
                              withKey: "polishedArtwork")

            // A thin warm highlight marks the wipe edge, like a ruler gliding
            // over the mosaic. It is decorative and disappears before the hold.
            let sweep = SKNode()
            sweep.position = CGPoint(x: centre.x - artworkSize / 2, y: centre.y)
            sweep.zPosition = 22
            let glow = SKShapeNode(rectOf: CGSize(width: 6, height: artworkSize * 1.04),
                                   cornerRadius: 3)
            glow.fillColor = UIColor(red: 1, green: 0.73, blue: 0.18, alpha: 0.18)
            glow.strokeColor = .clear
            let edge = SKShapeNode(rectOf: CGSize(width: 1.4, height: artworkSize),
                                   cornerRadius: 0.7)
            edge.fillColor = UIColor(red: 1, green: 0.88, blue: 0.50, alpha: 0.92)
            edge.strokeColor = .clear
            sweep.addChild(glow); sweep.addChild(edge); sweep.alpha = 0
            paintLayer.addChild(sweep)
            let glide = SKAction.moveTo(x: centre.x + artworkSize / 2, duration: wipeDuration)
            glide.timingMode = .easeInEaseOut
            let shimmer = SKAction.sequence([
                .fadeIn(withDuration: 0.08),
                .wait(forDuration: wipeDuration - 0.16),
                .fadeOut(withDuration: 0.08)
            ])
            sweep.run(.sequence([
                .wait(forDuration: morphStart),
                .group([glide, shimmer]),
                .removeFromParent()
            ]), withKey: "artworkSweep")
            // Let the player enjoy the finished collectible before the result card.
            completionDelay = morphStart + wipeDuration + 1.05
        } else {
            completionDelay = revealEnd + 0.80
        }
        boardCamera.run(.sequence([zoomOut,
                                   .wait(forDuration: max(0, completionDelay - zoomDuration)),
                                   .run(completion)]),
                        withKey: "paintingReveal")
    }
    /// Fragments continue through the puzzle boundary, making the arrow look as if
    /// it breaks apart naturally while leaving the authored board shape.
    private func boundaryShatter(at point: CGPoint, direction: Direction, color: ArrowColor,
                                 particleCount: Int = GameStyle.confettiCount) {
        let color = GameStyle.uiColor(color)
        for index in 0..<particleCount {
            let path = CGMutablePath()
            if index.isMultiple(of: 2) {
                path.move(to: CGPoint(x: -1, y: -1)); path.addLine(to: CGPoint(x: 1.5, y: -0.5)); path.addLine(to: CGPoint(x: 0, y: 2)); path.closeSubpath()
            } else { path.addRoundedRect(in: CGRect(x: -0.75, y: -1.5, width: 1.5, height: 3), cornerWidth: 0.3, cornerHeight: 0.3) }
            let shard = SKShapeNode(path: path); shard.fillColor = color; shard.strokeColor = .clear
            let start = CGFloat.random(in: -0.8...0.8)
            shard.position = CGPoint(x: point.x + CGFloat(direction.dx) * start,
                                     y: point.y + CGFloat(direction.dy) * start)
            fragmentLayer.addChild(shard)
            let outward = CGFloat.random(in: 5...13), side = CGFloat.random(in: -9...9)
            let drift = SKAction.moveBy(x: CGFloat(direction.dx) * outward - CGFloat(direction.dy) * side,
                                       y: CGFloat(direction.dy) * outward + CGFloat(direction.dx) * side,
                                       duration: GameStyle.confettiDuration)
            drift.timingMode = .easeOut
            shard.run(.sequence([.group([drift, .rotate(byAngle: CGFloat.random(in: -4...4), duration: GameStyle.confettiDuration),
                .sequence([.wait(forDuration: 0.035), .group([.fadeOut(withDuration: GameStyle.confettiDuration - 0.035), .scale(to: 0.25, duration: GameStyle.confettiDuration - 0.035)])])]),
                .removeFromParent()]))
        }
    }
    func reject(_ arrow: ArrowDefinition, remaining: [ArrowDefinition], onImpact: @escaping () -> Void, completion: @escaping () -> Void) {
        clearHint()
        guard let node = arrowNodes[arrow.id], node.action(forKey: "reject") == nil else { return }
        node.setScale(1)
        render(arrow, node: node, travel: 0)
        let block = PuzzleRules.blockingCell(arrow, remaining: remaining, level: level)
        var target = block.map(point) ?? puzzleExit(for: arrow).point
        var steps = Double((target.x - node.position.x) * CGFloat(arrow.direction.dx) +
                           (target.y - node.position.y) * CGFloat(arrow.direction.dy)) / Double(GameStyle.cellSize)
        if let block, let obstacle = remaining.first(where: { $0.id != arrow.id && $0.cells.contains(block) }),
           let intersection = motions[obstacle.id]?.firstIntersection(from: MotionPoint(x: Double(arrow.head.x), y: Double(arrow.head.y)), direction: arrow.direction) {
            steps = intersection
            target = CGPoint(x: node.position.x + CGFloat(arrow.direction.dx) * CGFloat(steps) * GameStyle.cellSize,
                             y: node.position.y + CGFloat(arrow.direction.dy) * CGFloat(steps) * GameStyle.cellSize)
        }
        let contact = max(0, steps - (block == nil ? 0.30 : 0.34))
        let forwardTime = min(0.30, 0.12 + contact * 0.025)
        let backwardTime = min(0.28, 0.12 + contact * 0.02)
        let forward = SKAction.customAction(withDuration: forwardTime) { [weak self] node, elapsed in
            let t = min(1, Double(elapsed) / forwardTime)
            self?.render(arrow, node: node, travel: ArrowMotion.slideProgress(t) * contact)
        }
        let backward = SKAction.customAction(withDuration: backwardTime) { [weak self] node, elapsed in
            let t = min(1, Double(elapsed) / backwardTime)
            let eased = t * t * (3 - 2 * t)
            self?.render(arrow, node: node, travel: (1 - eased) * contact)
        }
        let impact = SKAction.run { [weak self] in
            guard let self else { return }
            onImpact()
            let flash = SKShapeNode(circleOfRadius: 2.5); flash.position = target
            flash.fillColor = UIColor(red: 1, green: 0.25, blue: 0.30, alpha: 0.7); flash.strokeColor = .clear
            self.fragmentLayer.addChild(flash)
            flash.run(.sequence([.group([.scale(to: 1.5, duration: 0.10), .fadeOut(withDuration: 0.10)]), .removeFromParent()]))
        }
        node.run(.sequence([forward, impact, .wait(forDuration: 0.035), backward,
            .run { [weak self, weak node] in if let node { self?.render(arrow, node: node, travel: 0) }; completion() }]), withKey: "reject")
    }
}
