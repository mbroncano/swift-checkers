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
            var node: Node? = self

            return AnyIterator {
                defer { node = node?.parent }
                return node
            }
        }

        var pwin: Double { return Double(wins) / Double(nums) }

        // UCT (Upper Confidence Bound 1 applied to trees)
        func UCT(total: Int) -> Double {
            return pwin + sqrt(2 * log(Double(total)) / Double(nums))
        }

        // there are three reason for not having movements
        // 1. the opponent has no pieces left (Win)
        // 2. the player has no pieces left (Loss)
        // 3. the player has no movements left (Loss)
        var isWin: Bool {
            guard children.count == 0 else { return false }
            return (board.player ? board.white : board.black).nonzeroBitCount == 0
        }

    }

    let root: Node

    init(_ board: BitBoard) {
        self.root = Node(board: board)
    }

    public func search(plays: Int = 30, depth: Int = 50) -> BitBoard? {
        var play = 0

//        for play in 0..<plays {
//        while play < plays {
        let when = Date(timeIntervalSinceNow: 0.5)
        while when > Date() {
            play += 1

            // selection/expansion
            guard let result = selection(node: root, play: play) else { continue }

            // rollout
            var leaf = result
            var i = 0
            while i < depth {
                guard !leaf.isWin else { break }
                guard let next = leaf.children.randomElement() else { break }
                i += 1
                leaf = next
            }

            // back propagation
            for node in result.makeIteratorAncestors() {
                node.nums += 1

                if leaf.isWin && (node.board.player == leaf.board.player) {
                    node.wins += 1
                }
            }
        }

//        print("wins", root.children.map{ $0.wins }.reduce(0, +), root.wins)
//        print("nums", root.children.map{ $0.nums }.reduce(0, +), root.nums)
        print(play, root.children.map{ $0.pwin }.sorted().first! )

        return root.children.max { $0.pwin < $1.pwin }?.board
    }

    func selection(node: Node, play: Int) -> Node? {

        // no movements: terminal node
        guard !node.children.isEmpty else { return nil }

        // pickup the first unvisited (expansion)
        if let unvisited = node.children.first(where: { $0.nums == 0 }) {
            return unvisited
        }

        // return the one with the highest UCT (selection)
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
