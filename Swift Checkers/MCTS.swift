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

        lazy var children: [Node] = {
            return board.makeIteratorCont().map {
                Node(board: $0, parent: self)
            }
        }()

        init(board: BitBoard, parent: Node? = nil) {
            self.board = board
            self.parent = parent
        }

        var wins = 0
        var nums = 0

        func makeIteratorAncestors() -> AnyIterator<Node> {
            var node = self

            return AnyIterator {
                guard let result = node.parent else { return nil }
                node = result
                return node
            }
        }

        func UCT(total: Int) -> Double {
            return Double(wins) / Double(nums) + sqrt(2 * log(Double(total)) / Double(nums))
        }

        // there are three reason for not having movements
        // 1. the opponent has no pieces left (Win)
        // 2. the player has no pieces left (Loss)
        // 3. the player has no moveements left (Loss)
        var isWin: Bool {
            return (board.player ? board.black : board.white).nonzeroBitCount == 0
        }
    }

    let root: Node

    init(_ board: BitBoard) {
        self.root = Node(board: board)
    }

    public func search(plays: Int = 15) -> BitBoard? {
        for play in 0..<plays {
            guard let result = selection(node: root, play: play) else { continue }

            var leaf = result
            var depth = 50

            while depth > 0, let next = leaf.children.randomElement() {
                depth -= 1
                leaf = next
            }

            // back propagation
            let ancestors = result.makeIteratorAncestors()
            for node in ancestors {
                node.nums += 1

                if leaf.isWin && (node.board.player == leaf.board.player) {
                    node.wins += 1
                }
            }
        }

        return root.children.max { $0.wins > $1.wins }?.board
    }

    func selection(node: Node, play: Int) -> Node? {

        // no movements: terminal node
        guard !node.children.isEmpty else { return nil }

        // pickup the first unvisited
        if let unvisited = node.children.first(where: { $0.nums == 0 }) {
            return unvisited
        }

        // return the one with the highest UCT
        if let next = node.children.max(by: { $0.UCT(total: play) > $1.UCT(total: play) }) {
            return selection(node: next, play: play)
        }

        // this shouldn't happen
        return nil
    }
}

extension Array {
    func randomElement() -> Element? {
        if isEmpty { return nil }
        let index = Int(arc4random_uniform(UInt32(self.count)))
        return self[index]
    }
}
