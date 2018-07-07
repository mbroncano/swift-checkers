//
//  MCTS.swift
//  Swift Checkers
//
//  Created by Manuel Broncano on 6/24/18.
//  Copyright © 2018 Manuel Broncano. All rights reserved.
//

import Foundation

public struct MCTS {

    class Node {
        let board: BitBoard
        let parent: Node?

        var wins = 0
        var nums = 0

        lazy var children: [Node] = { return board.makeIteratorCont().map { Node(board: $0, parent: self) } }()
        var pwin: Double { return Double(wins) / Double(nums) }

        init(board: BitBoard, parent: Node? = nil) {
            self.board = board
            self.parent = parent
        }

        func makeIteratorAncestors() -> AnyIterator<Node> {
            var node: Node? = self

            return AnyIterator {
                defer { node = node?.parent }
                return node
            }
        }

        // UCT (Upper Confidence Bound 1 applied to trees)
        func UCT(total: Int) -> Double {
            return pwin + sqrt(2 * log(Double(total)) / Double(nums))
        }

        // there are three reason for not having movements
        // 1. the opponent has no pieces left (Win)
        // 2. the player has no pieces left (Loss)
        // 3. the player has no movements left (Loss)
        var isWin: BitBoard.Player? {
            guard children.count == 0 else { return nil }

            let opponentHasNoPieces = (board.player ? board.white : board.black).nonzeroBitCount == 0

            return opponentHasNoPieces ? board.player : !board.player
        }

//        lazy var score: Double = {
//            let (me, you) = !board.player ? (board.black, board.white) : (board.white, board.black)
//            let total = Double((me | you).nonzeroBitCount)
//            let player = Double(me.nonzeroBitCount)
//            let playerQueens = Double((me & board.queen).nonzeroBitCount) * 4
//            let totalQueens = Double(board.queen.nonzeroBitCount) * 4
//
//            let score = ((player + playerQueens) / (total + totalQueens) - 0.5) * 2
//
//            return score
//        }()

        lazy var score: Double = {

            let flip = parent?.board.player == board.player
            var (me, you) = board.player ? (board.black, board.white) : (board.white, board.black)
            if flip {
                swap(&me, &you)
            }

            let total = (me | you).nonzeroBitCount // 0...24
            let player = me.nonzeroBitCount // 0...12
            let playerQueens = (me & board.queen).nonzeroBitCount << 2
            let totalQueens = board.queen.nonzeroBitCount << 2

            let a = Double(player + playerQueens)
            let b = Double(total + totalQueens)
            let score = a/b - 0.5

            return score
        }()

        func bestScoreChild() -> Node? {
            let result = children.max{ $0.score < $1.score }
            return result
        }

    }

    let root: Node

    init(_ board: BitBoard) {
        self.root = Node(board: board)
    }

    let group = DispatchGroup()
    let queue = DispatchQueue(label: "mcts")

    public func search(plays: Int = 30, depth: Int = 100) -> BitBoard? {
        var play = 0

        let when = Date(timeIntervalSinceNow: 0.5)
        while when > Date() {

            // selection/expansion
            guard let resultArray = selection(node: root, play: play) else { continue }

            play += resultArray.count

            for result in resultArray {
                queue .async {
                    self.group.enter()

                    // rollout
                    var leaf = result
                    var i = 0
                    while i < depth {
                        guard leaf.isWin == nil else { break }
                        guard let next = leaf.bestScoreChild() else { break }
                        i += 1
                        leaf = next
                    }

                    // debug
                    var iter: Node? = leaf
                    let leaft = AnyIterator<Node> {
                        iter = iter?.parent
//                        guard let parent = leaf.parent e
//                        defer { leaf = leaf.parent }
                        return iter
                        }.reversed().reduce([]){ $0 + [$1.parent] }.compactMap{ $0?.score }

                    print(leaft)

                    // back propagation
                    for node in result.makeIteratorAncestors() {
                        node.nums += 1

                        guard let playerWin = leaf.isWin else { continue }

                        if playerWin != node.board.player {
                            node.wins += 1
                        }
                    }

                    self.group.leave()
                }
            }

            group.wait()
        }

        let result = root.children.max { $0.pwin < $1.pwin }
        print(play, result?.pwin as Any, result?.score as Any)

        return result?.board
    }

    func selection(node: Node, play: Int) -> [Node]? {

        // no movements: terminal node
        guard !node.children.isEmpty else { return nil }

        // return all the unvisited nodes first
        let unvisited = node.children.filter{ $0.nums == 0 }
        guard unvisited.count == 0 else { return unvisited }

        // return the one with the highest UCT (selection)
        if let next = node.children.max(by: { $0.UCT(total: play) < $1.UCT(total: play) }) {
            return selection(node: next, play: play)
        }

        // this shouldn't happen
        return nil
    }

}
/*
extension BitBoard {
    func score(player: Player) -> Double {
        let (me, you) = player ? (black, white) : (white, black)

        return (Double(me.nonzeroBitCount)/(Double(me.nonzeroBitCount)+Double(you.nonzeroBitCount))-0.5)*2
        /*
         let empty = ~(me | you)
         let position =
         [4, 4, 4, 4,
         3, 3, 3, 4,
         4, 2, 2, 3,
         3, 1, 2, 4,
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

        let val = (0..<32).reduce(0) {
            let mask = BitBoard.Mask(maskIndex: $1)
            guard empty & mask == 0 else { return $0 }
            let score: Int
            if queen & mask != 0 {
                score = 15 + pos2[$1]
            } else {
                score = 5 + position[player ? 31 - $1 : $1]
            }
            return me & mask != 0 ? $0 + score : $0 - score
        }

        return val*/
    }

}
*/
