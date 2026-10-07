import SpriteKit
import UIKit

final class GameScene: SKScene, UIGestureRecognizerDelegate {
    var onTap: ((Int) -> Void)?
    var inputEnabled = true
    private var level: LevelDefinition!
    private var arrowNodes: [Int: SKNode] = [:]
    private var gateNodes: [GateKey: SKNode] = [:]
    private var travels: [Int: Double] = [:]
    private var motions: [Int: ArrowMotion] = [:]
    private var exiting: Set<Int> = []
    private var warned: Set<Int> = []
    private var successfulMoves = 0
    private let boardCamera = SKCameraNode()
    private var arrowLayer = SKCropNode()
    private var fragmentLayer = SKNode()
    private var gatesLayer = SKNode()
    private var tutorial = SKNode()
    private var gestures: [UIGestureRecognizer] = []
    private var fitScale: CGFloat = 1
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
    var zoomFactor: CGFloat { fitScale / boardCamera.xScale }
    var accessibilitySummary: String {
        guard level != nil else { return "Puzzle board" }
        let frozen = level.gates.filter { $0.thawAfterMoves > successfulMoves }.count
        return "Level \(level.id); arrows \(arrowNodes.count - exiting.count); pending \(exiting.count); warnings \(warned.count); moves \(successfulMoves); frozen \(frozen); zoom \(String(format: "%.1f", Double(zoomFactor)))"
    }
    private func updateAccessibility() { view?.accessibilityValue = accessibilitySummary }

    func configure(level: LevelDefinition) {
        boardCamera.removeAllActions(); isIntroducing = false; needsIntroduction = true
        removeAllActions(); removeAllChildren()
        self.level = level; exiting = []; warned = []; successfulMoves = 0
        arrowNodes = [:]; gateNodes = [:]; motions = [:]; travels = [:]
        scaleMode = .resizeFill; backgroundColor = GameStyle.sceneBackground
        addChild(boardCamera); camera = boardCamera
        drawGrid()
        // Only arrow ink is clipped to the board. Exiting tails disappear through its edge.
        arrowLayer = SKCropNode(); arrowLayer.zPosition = 5
        let mask = SKShapeNode(rect: CGRect(x: 0, y: 0, width: boardWidth, height: boardHeight))
        mask.fillColor = .white; mask.strokeColor = .clear; arrowLayer.maskNode = mask; addChild(arrowLayer)
        fragmentLayer = SKNode(); fragmentLayer.zPosition = 7; addChild(fragmentLayer)
        gatesLayer = SKNode(); gatesLayer.zPosition = 10; addChild(gatesLayer)
        tutorial = SKNode(); tutorial.zPosition = 15; addChild(tutorial)
        for gate in level.gates { drawGate(gate) }
        for arrow in level.arrows { drawArrow(arrow) }
        updateGates(successfulMoves: 0)
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
        guard level != nil, size.width > 24, size.height > 24 else { return }
        boardCamera.removeAction(forKey: "introduction"); isIntroducing = false
        fitScale = max(worldBounds.width / (size.width - 24), worldBounds.height / (size.height - 24))
        boardCamera.setScale(fitScale)
        boardCamera.position = CGPoint(x: boardWidth / 2, y: boardHeight / 2)
        updateAccessibility()
    }
    private func introduceBoard() {
        guard needsIntroduction, view != nil else { return }
        needsIntroduction = false
        guard !skipsIntroduction, !UIAccessibility.isReduceMotionEnabled else { return }
        // Overview first; larger boards settle closer to the centre. The overview remains
        // the zoom-out limit, so a player can always find every perimeter gate again.
        let focusZoom: CGFloat = min(1.75, max(1.15, CGFloat(max(level.size, level.height)) / 12))
        isIntroducing = true
        let zoom = SKAction.scale(to: fitScale / focusZoom, duration: GameStyle.introDuration)
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
        boardCamera.setScale(min(fitScale, max(fitScale / GameStyle.maximumZoom, pinchStartScale / gesture.scale)))
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
        guard level.contains(cell) else { return }
        if let arrow = level.arrows.first(where: { arrowNodes[$0.id] != nil && !exiting.contains($0.id) && $0.cells.contains(cell) }) { onTap?(arrow.id) }
    }
    private func point(_ cell: Cell) -> CGPoint {
        CGPoint(x: (CGFloat(cell.x) + 0.5) * GameStyle.cellSize, y: (CGFloat(cell.y) + 0.5) * GameStyle.cellSize)
    }
    private func drawGrid() {
        let path = CGMutablePath()
        for x in 0..<level.size {
            for y in 0..<level.height {
                let centre = point(Cell(x: x, y: y))
                path.addEllipse(in: CGRect(x: centre.x - 1.6, y: centre.y - 1.6, width: 3.2, height: 3.2))
            }
        }
        let dots = SKShapeNode(path: path)
        dots.fillColor = GameStyle.guideDot; dots.strokeColor = .clear
        dots.zPosition = -1; addChild(dots)
    }
    private func gatePosition(_ key: GateKey) -> CGPoint {
        let lane = (CGFloat(key.lane) + 0.5) * GameStyle.cellSize
        switch key.side {
        case .right: return CGPoint(x: boardWidth, y: lane)
        case .up: return CGPoint(x: lane, y: boardHeight)
        case .left: return CGPoint(x: 0, y: lane)
        case .down: return CGPoint(x: lane, y: 0)
        }
    }
    private func drawGate(_ gate: GateDefinition) {
        let node = SKNode(); node.position = gatePosition(gate.key)
        node.zRotation = CGFloat(gate.key.side.rawValue) * .pi / 2
        // Local x=0 is the board edge; the entire socket extends outward.
        let color = GameStyle.uiColor(gate.color)
        let glow = SKShapeNode(rect: CGRect(x: 0, y: -17, width: 16, height: 34), cornerRadius: 8)
        glow.name = "glow"; glow.strokeColor = color; glow.fillColor = .clear
        glow.lineWidth = 2; glow.glowWidth = 0; glow.alpha = 0; node.addChild(glow)
        let socket = SKShapeNode(rect: CGRect(x: 0, y: -17, width: 16, height: 34), cornerRadius: 8)
        socket.zPosition = 2; socket.fillColor = color; socket.strokeColor = .clear; node.addChild(socket)
        let aperture = SKShapeNode(rect: CGRect(x: 4, y: -13, width: 8, height: 26), cornerRadius: 4)
        aperture.zPosition = 3; aperture.fillColor = GameStyle.portalWell
        aperture.strokeColor = UIColor(white: 0, alpha: 0.65); aperture.lineWidth = 1; node.addChild(aperture)
        let highlight = SKShapeNode(rect: CGRect(x: 1.5, y: -15.5, width: 13, height: 31), cornerRadius: 6.5)
        highlight.zPosition = 4; highlight.fillColor = .clear; highlight.strokeColor = color.withAlphaComponent(0.25)
        highlight.lineWidth = 0.65; node.addChild(highlight)
        let ice = SKNode(); ice.name = "ice"; ice.zPosition = 5
        let plate = SKShapeNode(rect: CGRect(x: 4, y: -13, width: 8, height: 26), cornerRadius: 4)
        plate.fillColor = UIColor(red: 0.50, green: 0.83, blue: 1, alpha: 0.72)
        plate.strokeColor = UIColor(red: 0.30, green: 0.61, blue: 0.75, alpha: 1); plate.lineWidth = 0.8; ice.addChild(plate)
        let snow = SKLabelNode(text: "❄"); snow.fontName = "AvenirNext-Medium"; snow.fontSize = 10
        snow.fontColor = GameStyle.portalWell; snow.verticalAlignmentMode = .center; snow.position.x = 8
        snow.zPosition = 1; snow.zRotation = -node.zRotation; ice.addChild(snow)
        let cracks = CGMutablePath(); cracks.move(to: CGPoint(x: 6, y: 11)); cracks.addLine(to: CGPoint(x: 9, y: 7)); cracks.addLine(to: CGPoint(x: 7, y: 3))
        cracks.move(to: CGPoint(x: 10, y: -11)); cracks.addLine(to: CGPoint(x: 6, y: -7))
        let crack = SKShapeNode(path: cracks); crack.strokeColor = UIColor(white: 1, alpha: 0.65); crack.zPosition = 1; crack.lineWidth = 0.7; ice.addChild(crack)
        let badge = SKShapeNode(circleOfRadius: 7.5); badge.name = "badge"; badge.zPosition = 2; badge.position = CGPoint(x: 23, y: 12)
        badge.fillColor = GameStyle.sceneBackground; badge.strokeColor = GameStyle.uiColor(gate.color); badge.lineWidth = 1.2
        let count = SKLabelNode(fontNamed: "AvenirNext-DemiBold"); count.name = "count"; count.fontSize = 10; count.fontColor = GameStyle.portalWell
        count.zPosition = 1; count.verticalAlignmentMode = .center; count.zRotation = -node.zRotation; badge.addChild(count)
        ice.addChild(badge); node.addChild(ice)
        gatesLayer.addChild(node); gateNodes[gate.key] = node
    }
    func updateGates(successfulMoves: Int) {
        self.successfulMoves = successfulMoves
        for gate in level.gates {
            guard let node = gateNodes[gate.key], let ice = node.childNode(withName: "ice") else { continue }
            let remaining = max(0, gate.thawAfterMoves - successfulMoves)
            if remaining == 0, !ice.isHidden, gate.thawAfterMoves > 0 {
                node.run(.sequence([.scale(to: 1.12, duration: 0.1), .scale(to: 1, duration: 0.16)]))
            }
            ice.isHidden = remaining == 0
            (ice.childNode(withName: "badge/count") as? SKLabelNode)?.text = String(remaining)
        }
        updateAccessibility()
    }
    private func arrowPath(_ arrow: ArrowDefinition, travel: Double = 0) -> CGPath {
        let points = (motions[arrow.id] ?? ArrowMotion(arrow)).points(travel: travel)
        let local = points.map { CGPoint(x: ($0.x - Double(arrow.head.x)) * Double(GameStyle.cellSize),
                                         y: ($0.y - Double(arrow.head.y)) * Double(GameStyle.cellSize)) }
        let path = CGMutablePath(); path.move(to: local[0])
        for point in local.dropFirst() { path.addLine(to: point) }
        let tip = local.last!, dx = CGFloat(arrow.direction.dx), dy = CGFloat(arrow.direction.dy)
        path.move(to: CGPoint(x: tip.x - dx * 7 - dy * 6, y: tip.y - dy * 7 + dx * 6))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x - dx * 7 + dy * 6, y: tip.y - dy * 7 - dx * 6))
        return path
    }
    private func render(_ arrow: ArrowDefinition, node: SKNode, travel: Double) {
        travels[arrow.id] = travel
        let path = arrowPath(arrow, travel: travel)
        for name in ["body", "hint", "warning"] { (node.childNode(withName: name) as? SKShapeNode)?.path = path }
        node.childNode(withName: "warningBadge")?.position = CGPoint(
            x: CGFloat(arrow.direction.dx) * (CGFloat(travel) * GameStyle.cellSize - 2) + CGFloat(arrow.direction.dy) * 13,
            y: CGFloat(arrow.direction.dy) * (CGFloat(travel) * GameStyle.cellSize - 2) - CGFloat(arrow.direction.dx) * 13)
    }
    private func stroke(_ path: CGPath, color: UIColor, width: CGFloat, name: String) -> SKShapeNode {
        let node = SKShapeNode(path: path); node.name = name; node.strokeColor = color
        node.lineWidth = width; node.lineCap = .round; node.lineJoin = .round; node.fillColor = .clear
        return node
    }
    private func drawArrow(_ arrow: ArrowDefinition) {
        let node = SKNode(); node.name = "arrow.\(arrow.id)"; node.position = point(arrow.head)
        motions[arrow.id] = ArrowMotion(arrow)
        let path = arrowPath(arrow)
        let warning = stroke(path, color: UIColor(red: 1, green: 0.23, blue: 0.29, alpha: 0.88), width: 7, name: "warning")
        warning.zPosition = 1; warning.isHidden = true; node.addChild(warning)
        let glow = stroke(path, color: GameStyle.uiColor(arrow.color).withAlphaComponent(0.22), width: 8, name: "hint")
        glow.zPosition = 2; glow.isHidden = true; node.addChild(glow)
        let body = stroke(path, color: GameStyle.uiColor(arrow.color), width: 2.8, name: "body"); body.zPosition = 3; node.addChild(body)
        let marker = SKShapeNode(circleOfRadius: 5); marker.name = "warningBadge"; marker.zPosition = 4
        marker.position = CGPoint(x: -2 * CGFloat(arrow.direction.dx) + 13 * CGFloat(arrow.direction.dy),
                                  y: -2 * CGFloat(arrow.direction.dy) - 13 * CGFloat(arrow.direction.dx)); marker.fillColor = GameStyle.sceneBackground
        marker.strokeColor = .systemRed; marker.lineWidth = 1.5; marker.isHidden = true
        let label = SKLabelNode(text: "!"); label.fontName = "AvenirNext-Bold"; label.fontSize = 8
        label.fontColor = .systemRed; label.zPosition = 1; label.verticalAlignmentMode = .center; label.zRotation = -node.zRotation; marker.addChild(label); node.addChild(marker)
        arrowLayer.addChild(node); arrowNodes[arrow.id] = node
    }
    func markBlocked(_ ids: Set<Int>) {
        warned = ids
        for (id, node) in arrowNodes {
            node.childNode(withName: "warning")?.isHidden = !ids.contains(id)
            node.childNode(withName: "warningBadge")?.isHidden = !ids.contains(id)
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
            let finger = SKLabelNode(text: "☝︎"); finger.fontSize = 23; finger.fontColor = GameStyle.portalWell
            finger.position = point(arrow.head); finger.position.y -= 26
            finger.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.45), .moveBy(x: 0, y: -4, duration: 0.45)])))
            self.tutorial.addChild(finger)
        }
    }
    func remove(_ arrow: ArrowDefinition, completion: @escaping () -> Void) {
        clearHint()
        guard let node = arrowNodes[arrow.id] else { completion(); return }
        exiting.insert(arrow.id); updateAccessibility()
        let gate = gatePosition(arrow.gateKey)
        node.removeAction(forKey: "reject"); node.setScale(1)
        let direction = arrow.direction
        let motion = motions[arrow.id]!
        let headToGate = Double((gate.x - node.position.x) * CGFloat(direction.dx) + (gate.y - node.position.y) * CGFloat(direction.dy)) / Double(GameStyle.cellSize)
        let contact = max(0, headToGate - 0.30)
        let travel = contact + motion.length + 0.06
        let start = travels[arrow.id] ?? 0
        let duration = max(GameStyle.exitDuration, min(0.65, 0.16 + (travel - start) * 0.035)) * 1.20
        var entered = false, sustained = false
        let slide = SKAction.customAction(withDuration: duration) { [weak self] node, elapsed in
            guard let self else { return }
            let distance = start + ArrowMotion.slideProgress(min(1, Double(elapsed) / duration)) * (travel - start)
            self.render(arrow, node: node, travel: distance)
            if !entered && distance >= contact {
                entered = true
                self.gateNodes[arrow.gateKey]?.childNode(withName: "glow")?.run(.sequence([
                    .fadeAlpha(to: 0.7, duration: 0.04), .fadeAlpha(to: 0.18, duration: 0.18)]))
                self.shatter(at: gate, direction: direction, color: arrow.color)
            }
            if !sustained && distance >= contact + motion.length / 2 {
                sustained = true; self.shatter(at: gate, direction: direction, color: arrow.color, count: 4)
            }
        }
        node.run(.sequence([slide, .removeFromParent(), .run { [weak self] in
            guard let self else { return }
            self.arrowNodes.removeValue(forKey: arrow.id); self.exiting.remove(arrow.id); self.warned.remove(arrow.id)
            self.updateAccessibility(); completion()
        }]), withKey: "exit")
    }
    /// Fragments live below the socket layer, emerging from its outer side.
    private func shatter(at point: CGPoint, direction: Direction, color: ArrowColor, count: Int = GameStyle.confettiCount) {
        for index in 0..<count {
            let path = CGMutablePath()
            if index.isMultiple(of: 2) {
                path.move(to: CGPoint(x: -2, y: -2)); path.addLine(to: CGPoint(x: 3, y: -1)); path.addLine(to: CGPoint(x: 0, y: 4)); path.closeSubpath()
            } else { path.addRoundedRect(in: CGRect(x: -1.5, y: -3, width: 3, height: 6), cornerWidth: 0.6, cornerHeight: 0.6) }
            let shard = SKShapeNode(path: path); shard.fillColor = GameStyle.uiColor(color); shard.strokeColor = .clear
            let start = CGFloat.random(in: 17...20)
            shard.position = CGPoint(x: point.x + CGFloat(direction.dx) * start, y: point.y + CGFloat(direction.dy) * start)
            fragmentLayer.addChild(shard)
            let forward = CGFloat.random(in: 10...20), side = CGFloat.random(in: -18...18)
            let drift = SKAction.moveBy(x: CGFloat(direction.dx) * forward - CGFloat(direction.dy) * side,
                                       y: CGFloat(direction.dy) * forward + CGFloat(direction.dx) * side,
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
        let gate = gatePosition(arrow.gateKey)
        var target = block.map(point) ?? gate
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
            let flash = SKShapeNode(circleOfRadius: 5); flash.position = target
            flash.fillColor = UIColor(red: 1, green: 0.25, blue: 0.30, alpha: 0.7); flash.strokeColor = .clear
            self.fragmentLayer.addChild(flash)
            flash.run(.sequence([.group([.scale(to: 1.5, duration: 0.10), .fadeOut(withDuration: 0.10)]), .removeFromParent()]))
        }
        node.run(.sequence([forward, impact, .wait(forDuration: 0.035), backward,
            .run { [weak self, weak node] in if let node { self?.render(arrow, node: node, travel: 0) }; completion() }]), withKey: "reject")
    }
}
