//
//  GameScene.swift
//  Swift Checkers
//
//  Created by Manuel Broncano on 6/22/18.
//  Copyright © 2018 Manuel Broncano. All rights reserved.
//

import SpriteKit
import GameplayKit


class GameScene: SKScene {

    var strategist: GKStrategist!
    var gameModel: Board { return strategist.gameModel as! Board }

    var board: SKNode!
    var label: SKLabelNode!
    var newLabel: SKLabelNode!
    var whiteLabel: SKLabelNode!
    var blackLabel: SKLabelNode!
    var pieces: [SKNode?] = Array(repeating: nil, count: 64)

    func isValidIndex(index i: Int) -> Bool {
        return (i >> 3) & 1 == i & 1
    }

    func locationForIndex(index i: Int) -> CGPoint {
        let x = check * CGFloat((i % 8) - 4) + check / 2
        let y = check * CGFloat((i / 8) - 4) + check / 2
        return CGPoint(x: x, y: y)
    }

    func indexForLocation(location l: CGPoint) -> Int? {
        guard abs(l.x) < (side / 2) && abs(l.y) < (side / 2) else { return nil }

        let i = l.x / check + 4
        let j = l.y / check + 4

        let pos = Int(floor(i) + floor(j) * 8)
        print(pos)

        return pos
    }

    var side: CGFloat { return min(size.width, size.height) * 0.8 }
    var check: CGFloat { return side / 8}
    var radius: CGFloat { return check * 0.4 }

    override func didChangeSize(_ oldSize: CGSize) {
        board?.position = CGPoint(x: frame.midX, y: frame.midY)
    }

    override func didMove(to view: SKView) {
//        strategist = GKMonteCarloStrategist()
        strategist = GKMinmaxStrategist()
        (strategist as? GKMinmaxStrategist)?.maxLookAheadDepth = 4
        strategist.randomSource = GKLinearCongruentialRandomSource()
        strategist.gameModel = Board(BitBoard())

        board = SKShapeNode(rectOf: CGSize(width: side, height: side))
        board.name = "board"
        board.position = CGPoint(x: frame.midX, y: frame.midY)
        addChild(board)

        let fontSize = side / 32
        let offset = CGPoint(x: side / 2, y: side / 2 + fontSize * 1.5)

        label = SKLabelNode(text: "Checkers!")
        label.verticalAlignmentMode = .baseline
        label.horizontalAlignmentMode = .right
        label.fontSize = fontSize
        label.fontColor = SKColor.yellow
        label.fontName = "Avenir"
        label.position = CGPoint(x: offset.x, y: -offset.y)
        board.addChild(label)

        newLabel = SKLabelNode(text: "New Game")
        newLabel.verticalAlignmentMode = .baseline
        newLabel.horizontalAlignmentMode = .left
        newLabel.fontSize = fontSize
        newLabel.fontColor = SKColor.yellow
        newLabel.fontName = "Avenir"
        newLabel.position = CGPoint(x: -offset.x, y: offset.y - fontSize)
        board.addChild(newLabel)

        whiteLabel = SKLabelNode(text: "\(Player.White)")
        whiteLabel.verticalAlignmentMode = .baseline
        whiteLabel.horizontalAlignmentMode = .left
        whiteLabel.fontSize = fontSize
        whiteLabel.fontColor = .white
        whiteLabel.fontName = "Avenir"
        whiteLabel.position = CGPoint(x: -offset.x, y: -offset.y)
        board.addChild(whiteLabel)

        blackLabel = SKLabelNode(text: "\(Player.Black)")
        blackLabel.verticalAlignmentMode = .baseline
        blackLabel.horizontalAlignmentMode = .right
        blackLabel.fontSize = fontSize
        blackLabel.fontColor = .white
        blackLabel.fontName = "Avenir"
        blackLabel.position = CGPoint(x: offset.x, y: offset.y - fontSize)
        board.addChild(blackLabel)

        for i in 0..<64 {
            let position = locationForIndex(index: i)

            let square = SKShapeNode(rectOf: CGSize(width: check, height: check))
            let gray = isValidIndex(index: i)
            square.fillColor = gray ? .clear : .gray
            square.position = position
            square.name = "square"
            board.addChild(square)

            if isValidIndex(index: i) {
                let label = SKLabelNode(text: "\(i >> 1)")
                label.fontSize = radius * 0.8
                label.fontColor = .yellow
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                label.position = position
                label.name = "label"
                label.zPosition = 9
                board.addChild(label)
            }
        }

        resetBoard()
    }

    func resetBoard() {
        board.enumerateChildNodes(withName: "piece", using: { (node, nil) in
            node.removeFromParent()
        })

        pieces = Array(repeating: nil, count: 64)

        for index in gameModel.checkSet() {
            let color: SKColor = gameModel.isWhite(index) ? .red : .blue
            let piece = SKShapeNode(circleOfRadius: radius)
            let inner = SKShapeNode(circleOfRadius: radius * 0.8)
            inner.fillColor = color
            piece.addChild(inner)
            piece.position = self.locationForIndex(index: index)
            piece.name = "piece"
            piece.fillColor = gameModel.isQueen(index) ? .yellow : color
            piece.zPosition = 2

            pieces[index] = piece

            board.addChild(piece)
        }

        nextTurn()
    }

    var moving: SKNode?
    var fromPosition: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if whiteLabel.contains(touch.location(in: board)) {
                Player.White.isComputer = !Player.White.isComputer
                whiteLabel.text = "\(Player.White)"
                if let activePlayer = gameModel.activePlayer as? Player, activePlayer == Player.White {
                    nextTurn()
                }
                return
            }

            if blackLabel.contains(touch.location(in: board)) {
                Player.Black.isComputer = !Player.Black.isComputer
                blackLabel.text = "\(Player.Black)"
                if let activePlayer = gameModel.activePlayer as? Player, activePlayer == Player.Black {
                    nextTurn()
                }
                return
            }
        }

        if let activePlayer = gameModel.activePlayer as? Player {
            guard !activePlayer.isComputer else { return }
        }

        for touch in touches {
            if newLabel.contains(touch.location(in: board)) {
                strategist.gameModel = Board(BitBoard())
                resetBoard()
                return
            }

            let location = touch.location(in: board)

            for node in board.nodes(at: location) {
                guard node.name == "piece", node.contains(location) else { continue }

                moving = node
                node.zPosition = 3
                fromPosition = node.position
                return
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let node = moving, let touch = touches.first else { return }
        node.position = touch.location(in: board)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let node = moving, let touch = touches.first else { return }

        defer {
            node.position = fromPosition!
            node.zPosition = 1
            moving = nil
            fromPosition = nil
        }

        let newLocation = touch.location(in: board)
        guard let to = indexForLocation(location: newLocation) else { return }
        guard let from = indexForLocation(location: fromPosition!) else { return }
        guard let update = gameModel.update(from, to) else { return }

        let action = SKAction.move(to: locationForIndex(index: to), duration: 0.0)
        runAction(action, node)

        updateBoard(update)
        nextTurn()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let node = moving else { return }

        node.position = fromPosition!
        node.zPosition = 1
        moving = nil
        fromPosition = nil
    }

    func runAction(_ action:SKAction, _ piece: SKNode) {
        if piece.hasActions() {
            DispatchQueue.main.async {
                action.timingMode = SKActionTimingMode.easeIn
                self.runAction(action, piece)
            }
        } else {
            piece.run(action)
        }
    }

    func updateBoard(_ update: Update) {
        gameModel.apply(update)
//        print("move: \(String(describing: update.move))")
//        print("capture: \(String(describing: update.capture))")
//        print("promotion: \(String(describing: update.promotion))")

        let duration = Player.White.isComputer && Player.Black.isComputer ? 0.01 : 0.25

        if let (from, to) = update.move, let piece = pieces[from] as? SKShapeNode {
            pieces[to] = pieces[from]
            pieces[from] = nil

            let action = SKAction.move(to: locationForIndex(index: to), duration: duration)
            if gameModel.isQueen(from) == gameModel.isQueen(to) {
                runAction(action, piece)
            } else {
                let color = piece.fillColor
                let glow = SKAction.customAction(withDuration: duration) { (node, elapsedTime) in
                    piece.fillColor = UIColor.interpolate(from: color, to: .white, with: elapsedTime / CGFloat(duration))
                }
                let group = SKAction.group([action, glow])
                runAction(group, piece)
            }
        }

        if let pos = update.capture, let piece = pieces[pos] {
            pieces[pos] = nil
            piece.zPosition = 1

            let action = SKAction.sequence([SKAction.fadeOut(withDuration: duration), SKAction.removeFromParent()])
            runAction(action, piece)
        }
    }

    func nextTurn() {

        if let player = gameModel.activePlayer as? Player {
            if player.isComputer {
                label.text = "Thinking ..."
                DispatchQueue.global(qos: .background).async {
                    DispatchQueue.main.async {

                        var update: Update? = nil
                        if player == .White {

                            if let mcts = MCTS(self.gameModel.board).search() {
                                update = Update(mcts, self.gameModel.board)
                            }
                        } else {
                            update = self.strategist.bestMoveForActivePlayer() as? Update

                        }

                        if let update = update as? Update {
                            self.updateBoard(update)
                        } else {
                            print("wat")
                        }
                        self.nextTurn()
                    }
                }
            } else {
                label.text =  "Move!" + " (\(gameModel.move))"
            }
        } else {
            if gameModel.isWin(for: Player.White) {
                label.text = "\(Player.White) wins!"
            } else if gameModel.isWin(for: Player.Black) {
                label.text = "\(Player.Black) wins!"
            } else {
                label.text = "Draw at move \(gameModel.move)"
            }
        }
    }
}

public extension UIColor {
    var components: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let components = self.cgColor.components!

        switch components.count == 2 {
        case true : return (r: components[0], g: components[0], b: components[0], a: components[1])
        case false: return (r: components[0], g: components[1], b: components[2], a: components[3])
        }
    }

    static func interpolate(from fromColor: UIColor, to toColor: UIColor, with progress: CGFloat) -> UIColor {
        let fromComponents = fromColor.components
        let toComponents = toColor.components

        let r = (1 - progress) * fromComponents.r + progress * toComponents.r
        let g = (1 - progress) * fromComponents.g + progress * toComponents.g
        let b = (1 - progress) * fromComponents.b + progress * toComponents.b
        let a = (1 - progress) * fromComponents.a + progress * toComponents.a

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
