//
//  BitBoard.swift
//  Swift Checkers
//
//  Created by Manuel Broncano on 6/22/18.
//  Copyright © 2018 Manuel Broncano. All rights reserved.
//

import Foundation

public struct BitBoard {
    public typealias Mask = UInt32
    public typealias MaskIndex = Int
    public typealias CheckIndex = Int

    let white: Mask
    let black: Mask
    let queen: Mask

    let player: Bool
    let range: Range<Int>

    public init() {
        self.init(white: 0x00000FFF, black: 0xFFF00000, queen: 0, player: false)
    }

    public init(white: Mask, black: Mask, queen: Mask, player: Bool, range: Range<Int> = 0..<256) {
        if white & black != 0 {
            fatalError("white and black pieces in the same check")
        }

        if (white | black) & queen != queen {
            fatalError("queen must have a side")
        }

        self.white = white
        self.black = black
        self.queen = queen
        self.player = player
        self.range = range
    }
}

extension BitBoard.Mask {
    public init(maskIndex: BitBoard.MaskIndex) {
        self.init(1 << maskIndex)
    }

    public var description: String {
        return "\(BitBoard(white: self, black: 0, queen: 0, player: false))"
    }

    public func hasIndex(maskIndex: BitBoard.MaskIndex) -> Bool {
        return self & BitBoard.Mask(maskIndex: maskIndex) != 0
    }

    public func indexSet() -> [BitBoard.MaskIndex] {
        return (0..<self.bitWidth).compactMap { self.hasIndex(maskIndex: $0) ? $0 : nil }
    }

    public func checkSet() -> [BitBoard.CheckIndex] {
        return self.indexSet().map { $0.checkIndex() }
    }
}

extension BitBoard.MaskIndex {
    public init(checkIndex: BitBoard.CheckIndex) {
        self = checkIndex >> 1
    }

    public func checkIndex() -> BitBoard.CheckIndex {
        return self << 1 + (self >> 2 & 1)
    }
}

extension BitBoard: CustomStringConvertible {
    public var description: String {
        let check = { (mask: Mask) -> String in
            if self.white & mask != 0 {
                return self.queen & mask != 0 ? "◆" : "●"
            }
            if self.black & mask != 0 {
                return self.queen & mask != 0 ? "◇" : "○"
            }
            return " "
        }

        let top = "┌─┬─┬─┬─┬─┬─┬─┬─┐"
        let bot = "└─┴─┴─┴─┴─┴─┴─┴─┘"
        let header = (0..<8).reduce(""){ "\($0) \($1)" } + (player ? "  ○" : "  ●") + "\n\(top)\n"
        let lines = (0..<8).reversed().reduce(header) { res, row in
            let cols = (0..<4).reduce("") { cur, col in
                let check = "\(check(1 << (row * 4 + col)))"
                let (first, second) = (row & 1 != 0) ? (" ", check) : (check, " ")

                return cur + "\(first)│\(second)│"
            }

            return res + "│\(cols) \(row)\n"
            } + "\(bot)\n"

        return lines
    }
}

extension BitBoard: Sequence {

    static let allMovements = 0..<256

    var isContinuation: Bool { return range != BitBoard.allMovements }

    // this iterator will skip the intermediate captures
    public func makeIterator() -> AnyIterator<BitBoard> {
        var stack = [self.makeIteratorCont()]

        return AnyIterator {
            while let iter = stack.popLast() {
                // if this is the last item in this iterator, continue to the next one
                guard let res = iter.next() else { continue }

                // add back the current iterator
                stack.append(iter)

                // if it's not a continuation, return it right away
                guard res.isContinuation else { return res }

                // proceed to return the board or iterate on capture
                let next = res.makeIteratorCont()
                stack.append(next)
            }
            return nil
        }
    }

    // this iterator returns all the possible next movements
    public func makeIteratorCont() -> AnyIterator<BitBoard> {
        var i = self.range.startIndex
        var hasCaptured = false

        let moveMask: [Mask] = [0xF0808080, 0xF1010101, 0x8080808F, 0x0101010F] // cannot move in this direction
        let captMask: [Mask] = [0xFF888888, 0xFF111111, 0x888888FF, 0x111111FF] // cannot capture in this direction
        let (playerMask, opponentMask) = player ? (black, white) : (white, black)
        let empty: Mask = ~(white|black)

        let board = self

        return AnyIterator {

            // 0..127 - capture, 128..257 - move
            while i < self.range.endIndex {
                let idx = (i >> 2) & 31   // the mask index
                let dir = i & 3           // one ofthe four directions
                let this = Mask(1 << idx) // the current piece
                let cap = i < 128         // capturing or moving
                i += 1

                // finish right away if we're moving and we can capture
                guard cap || !hasCaptured else { break }

                // only occupied checks
                guard empty & this == 0 else { continue }

                // check for capture or move in this direction for the player
                guard ~(cap ? captMask : moveMask)[dir] & this & playerMask != 0 else { continue }

                // check if player can capture or move in this direction, or it is a queen
                let isQueen = board.queen & this != 0
                let isForward = board.player == (dir & 2 != 0)
                guard isQueen || isForward else { continue }

                let odd = (idx >> 2 & 1) // 1 if odd row
                let wst = (dir & 1)      // 1 if west direction
                let sth = (dir & 2) << 2 // 8 if south direction

                // radius 1 mask
                let adj1 = idx + odd - wst - sth
                let mask1 = Mask(0x10 << adj1)

                // check for opponent or empty check
                guard mask1 & (cap ? opponentMask : empty) != 0 else { continue }

                let playerXor: Mask
                let opponentXor: Mask

                if cap {
                    // radius 2 mask
                    let adj2 = idx - (wst << 1) - (sth << 1) + 9
                    let mask2 = Mask(1 << adj2)

                    // check for empty check
                    guard mask2 & empty != 0 else { continue }

                    hasCaptured = true
                    playerXor = mask2
                    opponentXor = mask1

                } else {
                    playerXor = mask1
                    opponentXor = 0
                }

                // player capture and movement
                let newPlayerMask = playerMask ^ this ^ playerXor
                let newOpponentMask = opponentMask ^ opponentXor
                let (newWhite, newBlack) = board.player ? (newOpponentMask, newPlayerMask) : (newPlayerMask, newOpponentMask)

                // queen promotion, movement and capture
                let newQueenMaskPromo = playerXor & (board.player ? 0xf : 0xf0000000)
                let newQueenMaskPlayer = (isQueen ? this | playerXor : 0) | (board.queen & opponentXor)
                let newQueenMask = board.queen ^ newQueenMaskPlayer | newQueenMaskPromo // order is important

                // for captures that are not promotions, continue capturing
                let new = (idx - (wst << 1) - (sth << 1) + 9) << 2
                let cont = cap && (isQueen || (newQueenMaskPromo == 0))
                let range = cont ? new..<(new + 4) : BitBoard.allMovements
                let newPlayer = cont ? board.player : !board.player

                let res = BitBoard(white: newWhite, black: newBlack, queen: newQueenMask, player: newPlayer, range: range)

                return res
            }

            // when exploring continuations, and there's none, return self and flip sides
            if !hasCaptured && self.isContinuation {
                hasCaptured = true
                return BitBoard(white: board.white, black: board.black, queen: board.queen, player: !board.player)
            }

            return nil
        }
    }

    func applyMove(from: MaskIndex, to: MaskIndex) -> BitBoard? {

        // apply the move to the player mask
        let playerMask = (player ? black : white) ^ (Mask(maskIndex: from) | Mask(maskIndex: to))

        // find the first move when the player position matches what we expect
        guard let result = makeIteratorCont().first(where: {
            playerMask == (player ? $0.black : $0.white)
        }) else {
            // invalid movement
            return nil
        }

        // check if we need to keep on capturing, if not just return the next
        if result.isContinuation {
            guard let next = result.makeIteratorCont().next() else { return nil }
            guard next.player == result.player else { return next }
        }

        return result
    }
}

