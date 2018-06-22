//
//  GameModel.swift
//  Swift Checkers
//
//  Created by Manuel Broncano on 6/22/18.
//  Copyright © 2018 Manuel Broncano. All rights reserved.
//

import Foundation
import GameplayKit

class Player: NSObject, GKGameModelPlayer {
    var playerId: Int = 0
    var isComputer: Bool = false
    var opposite: Player { return self == .White ? .Black : .White }

    static let White = Player(0, false)
    static let Black = Player(1, true)

    init(_ playerId: Int, _ isComputer: Bool) {
        self.playerId = playerId
        self.isComputer = isComputer
    }

    override var description: String {
        return (self == .White ? "White" : "Black") + (self.isComputer ? " (Computer)" : " (Human)")
    }
}

class Board: NSObject {
    var moves: [BitBoard] // cache for potential movements
    var board: BitBoard
    var move: Int // > 50 it's a draw

    convenience override init() {
        self.init(BitBoard())
    }

    init(_ board: BitBoard) {
        self.board = board
        self.moves = board.makeIteratorCont().map { $0 }
        self.move = 0
    }
}

class Update: NSObject, GKGameModelUpdate {
    var board: BitBoard
    var previous: BitBoard
    var value: Int = 0

    init(_ board: BitBoard, _ previous: BitBoard) {
        self.board = board
        self.previous = previous
    }

    var move: (Int, Int)? {
        let (prev, next) = previous.player ? (previous.black, board.black) : (previous.white, board.white)
        let mask = prev ^ next
        guard let from = BitBoard.Mask(mask & prev).checkSet().first else { return nil }
        guard let to = BitBoard.Mask(mask & next).checkSet().first else { return nil }
        return (from, to)
    }

    var capture: Int? {
        let (prev, next) = previous.player ? (previous.white, board.white) : (previous.black, board.black)
        let mask = prev ^ next
        guard let from = BitBoard.Mask(mask & prev).checkSet().first else { return nil }
        return from
    }

    var promotion: Int? {
        let (prev, next) = previous.player ? (previous.black, board.black) : (previous.white, board.white)
        let (prevQueen, nextQueen) = (prev & previous.queen, next & board.queen)
        if prevQueen == 0 && nextQueen != 0 {
            guard let promo = BitBoard.Mask(nextQueen).checkSet().first else { return nil }
            return promo
        }

        return nil
    }
}

extension Board: GKGameModel {
    var players: [GKGameModelPlayer]? {
        return [Player.White, Player.Black]
    }

    var activePlayer: GKGameModelPlayer? {
        guard !isDraw() else { return nil }
        guard !isWin(for: Player.Black) && !isWin(for: Player.White) else { return nil }
//        guard !isLoss(for: Player.Black) && !isLoss(for: Player.White) else { return nil }

        return board.player ? Player.Black : Player.White
    }

    func setGameModel(_ gameModel: GKGameModel) {
        if let model = gameModel as? Board {
            self.board = model.board
            self.moves = model.moves
            self.move = model.move
        }
    }

    func gameModelUpdates(for player: GKGameModelPlayer) -> [GKGameModelUpdate]? {
        return moves.map { Update($0, self.board) }
    }

    func apply(_ gameModelUpdate: GKGameModelUpdate) {
        if let update = gameModelUpdate as? Update {
            self.board = update.board
            self.moves = board.makeIteratorCont().map { $0 }
            self.move += update.board.player != update.previous.player ? 1 : 0
        }
    }

    func unapplyGameModelUpdate(_ gameModelUpdate: GKGameModelUpdate) {
        if let update = gameModelUpdate as? Update {
            self.board = update.previous
            self.moves = board.makeIteratorCont().map { $0 }
            self.move -= update.board.player != update.previous.player ? 1 : 0
        }
    }

    func copy(with zone: NSZone? = nil) -> Any {
        return Board(board)
    }
}

extension Board {
    func isDraw() -> Bool {
        return move > 100
    }

    func isWin(for player: GKGameModelPlayer) -> Bool {
        guard let player = player as? Player else { return false }

        return isLoss(for: player.opposite)
    }

    func isLoss(for player: GKGameModelPlayer) -> Bool {
        // check we can move if active player
        if (player.playerId == 1) == board.player {
            guard moves.count > 0 else { return true }
        }

        // check if we have any pieces left
        return (player.playerId == 1 ? board.black : board.white) == 0
    }

    func score(for player: GKGameModelPlayer) -> Int {
        let position =
            [8, 8, 8, 8,
             6, 6, 6, 7,
             6, 4, 4, 5,
             4, 2, 3, 5,
             4, 2, 1, 3,
             3, 2, 2, 4,
             4, 3, 3, 3,
             4, 4, 4, 4]

        let pos2 =
            [ 3, 3, 2, 1,
              4, 3, 2, 1,
              3, 4, 3, 2,
              3, 4, 3, 2,
              2, 3, 4, 3,
              2, 3, 4, 3,
              1, 2, 3, 4,
              1, 2, 3, 3]

        let (me, you) = player.playerId == 1 ? (board.black, board.white) : (board.white, board.black)
        let empty = ~(me | you)

        let val = (0..<32).reduce(0) {
            let mask = BitBoard.Mask(maskIndex: $1)
            guard empty & mask == 0 else { return $0 }
            let score: Int
            if board.queen & mask != 0 {
                score = 15 + pos2[$1]
            } else {
                score = 5 + position[player.playerId != 0 ? 31 - $1 : $1]
            }
            return me & mask != 0 ? $0 + score : $0 - score
        }

        return val
    }
}

extension Board {
    func checkSet() -> [Int] {
        return (board.white | board.black).checkSet()
    }

    func isQueen(_ index: Int) -> Bool {
        return board.queen.hasIndex(maskIndex: BitBoard.MaskIndex(checkIndex: index))
    }

    func isWhite(_ index: Int) -> Bool {
        return board.white.hasIndex(maskIndex: BitBoard.MaskIndex(checkIndex: index))
    }

    func update(_ from: Int, _ to: Int) -> Update? {
        let from = BitBoard.MaskIndex(checkIndex: from)
        let to = BitBoard.MaskIndex(checkIndex: to)
        guard let update = board.applyMove(from: from, to: to) else { return nil }
        return Update(update, self.board)
    }
}
