import Foundation

enum DominoPlayer: String, Codable, Equatable {
case white // human
case black // bot
}

struct DominoTile: Equatable, Hashable, Identifiable, Codable {
var a: Int
var b: Int
var id: String { "\(min(a,b))-\(max(a,b))" }
var pips: Int { a + b }
var isDouble: Bool { a == b }

func matches(_ value: Int) -> Bool { a == value || b == value }

/// Returns this tile oriented so its `a` touches `value` (for display when
/// attaching to the end of the chain that currently shows `value`).
func oriented(toTouch value: Int) -> DominoTile {
b == value ? self : DominoTile(a: b, b: a)
}
}

enum DominoSide: Codable {
case left
case right
}

/// Classic blocking domino ("Козёл" / goat style scoring on block), double-six set,
/// 2 players (you vs. a bot), 7 tiles each, 14 in the boneyard. Draw from the
/// boneyard when you cannot play; pass only once the boneyard is empty and you
/// still cannot play. First to empty their hand wins; if the game blocks
/// (neither player can move and the boneyard is empty) the player with the
/// lower pip count left in hand wins, equal pips is a draw.
final class DominoEngine: ObservableObject {
@Published var hands: [DominoPlayer: [DominoTile]] = [:]
@Published var boneyard: [DominoTile] = []
@Published var board: [DominoTile] = [] // oriented chain: board[i].b touches board[i+1].a
@Published var turn: DominoPlayer = .white
@Published var winner: DominoPlayer? = nil
@Published var isDraw: Bool = false
@Published var selectedTile: DominoTile? = nil
@Published var statusMessage: String = ""

private var consecutivePasses = 0

init() {
reset()
}

func reset() {
var full: [DominoTile] = []
for i in 0...6 {
for j in i...6 {
full.append(DominoTile(a: i, b: j))
}
}
full.shuffle()

var white = Array(full[0..<7])
var black = Array(full[7..<14])
let yard = Array(full[14..<28])

board = []
boneyard = yard
winner = nil
isDraw = false
selectedTile = nil
consecutivePasses = 0
statusMessage = ""

// Starter: whoever holds the highest double opens with it; if neither
// has a double, the player holding the heaviest tile starts.
func highestDouble(_ hand: [DominoTile]) -> DominoTile? {
hand.filter { $0.isDouble }.max { $0.pips < $1.pips }
}

if let wd = highestDouble(white), let bd = highestDouble(black) {
if wd.pips >= bd.pips {
startGame(opener: .white, tile: wd, hand: &white)
} else {
startGame(opener: .black, tile: bd, hand: &black)
}
} else if let wd = highestDouble(white) {
startGame(opener: .white, tile: wd, hand: &white)
} else if let bd = highestDouble(black) {
startGame(opener: .black, tile: bd, hand: &black)
} else {
let heaviestWhite = white.max { $0.pips < $1.pips }!
let heaviestBlack = black.max { $0.pips < $1.pips }!
if heaviestWhite.pips >= heaviestBlack.pips {
startGame(opener: .white, tile: heaviestWhite, hand: &white)
} else {
startGame(opener: .black, tile: heaviestBlack, hand: &black)
}
}

hands = [.white: white, .black: black]
advanceTurnIfBlocked()
}

/// Replaces the current random deal with one received from the host over
/// the network, so both devices start a multiplayer game on identical
/// hands/board/boneyard instead of each shuffling independently.
func applyDeal(white: [DominoTile], black: [DominoTile], boneyard: [DominoTile], board: [DominoTile], turn: DominoPlayer) {
hands = [.white: white, .black: black]
self.boneyard = boneyard
self.board = board
self.turn = turn
winner = nil
isDraw = false
selectedTile = nil
statusMessage = ""
consecutivePasses = 0
}

private func startGame(opener: DominoPlayer, tile: DominoTile, hand: inout [DominoTile]) {
board = [tile]
hand.removeAll { $0 == tile }
turn = opener == .white ? .black : .white
}

var leftEnd: Int? { board.first?.a }
var rightEnd: Int? { board.last?.b }

func legalSides(for tile: DominoTile) -> [DominoSide] {
guard let left = leftEnd, let right = rightEnd else { return [.left] }
var sides: [DominoSide] = []
if tile.matches(left) { sides.append(.left) }
if tile.matches(right) { sides.append(.right) }
return sides
}

func hasLegalMove(_ player: DominoPlayer) -> Bool {
guard let hand = hands[player] else { return false }
return hand.contains { !legalSides(for: $0).isEmpty }
}

/// Draws from the boneyard for `player` until they have a legal move or
/// the boneyard runs out. Returns true if the player can now move.
@discardableResult
func drawUntilPlayableOrEmpty(_ player: DominoPlayer) -> Bool {
while !hasLegalMove(player), !boneyard.isEmpty {
let drawn = boneyard.removeLast()
hands[player, default: []].append(drawn)
}
return hasLegalMove(player)
}

func play(tile: DominoTile, side: DominoSide, player: DominoPlayer) {
guard hands[player]?.contains(tile) == true, winner == nil else { return }
guard legalSides(for: tile).contains(side) else { return }

if board.isEmpty {
board = [tile]
} else if side == .left, let left = leftEnd {
// New head tile's `b` must touch the old head's `a` (== left).
board.insert(tile.oriented(toTouch: left), at: 0)
} else if side == .right, let right = rightEnd {
// New tail tile's `a` must touch the old tail's `b` (== right).
board.append(tile.oriented(toTouch: right).flipped())
}

hands[player]?.removeAll { $0 == tile }
selectedTile = nil
consecutivePasses = 0

if hands[player]?.isEmpty == true {
winner = player
statusMessage = player == .white ? t("You played all your tiles!", "Вы выставили все кости!") : t("The bot played all its tiles!", "Бот выставил все кости!")
return
}

turn = player == .white ? .black : .white
advanceTurnIfBlocked()
}

/// Call after switching turn: handles auto-draw / auto-pass for the player
/// now on turn, and detects a full block (both stuck, boneyard empty).
func advanceTurnIfBlocked() {
guard winner == nil else { return }
let current = turn
if drawUntilPlayableOrEmpty(current) {
consecutivePasses = 0
return
}
// Current player cannot move even after drawing — pass.
consecutivePasses += 1
if consecutivePasses >= 2 {
endByBlock()
} else {
turn = current == .white ? .black : .white
advanceTurnIfBlocked()
}
}

private func endByBlock() {
let whitePips = hands[.white]?.reduce(0) { $0 + $1.pips } ?? 0
let blackPips = hands[.black]?.reduce(0) { $0 + $1.pips } ?? 0
if whitePips == blackPips {
isDraw = true
statusMessage = t("Game blocked — draw (\(whitePips) points each).", "Игра заблокирована — ничья (\(whitePips) очков у каждого).")
} else {
winner = whitePips < blackPips ? .white : .black
statusMessage = t("Game blocked. You have \(whitePips), the bot has \(blackPips) points.", "Игра заблокирована. У вас \(whitePips), у бота \(blackPips) очков.")
}
}

func tapHandTile(_ tile: DominoTile) {
guard turn == .white, winner == nil else { return }
let sides = legalSides(for: tile)
guard !sides.isEmpty else { return }
if sides.count == 1 {
play(tile: tile, side: sides[0], player: .white)
} else {
selectedTile = (selectedTile == tile) ? nil : tile
}
}

func tapEnd(_ side: DominoSide) {
guard let tile = selectedTile, turn == .white, winner == nil else { return }
if legalSides(for: tile).contains(side) {
play(tile: tile, side: side, player: .white)
}
}
}

private extension DominoTile {
/// Swaps a/b — used when prepending to the left of the chain so that the
/// stored tile's `b` still touches the next tile's `a`.
func flipped() -> DominoTile { DominoTile(a: b, b: a) }
}

// MARK: - Simple AI (Black)

extension DominoEngine {
func playBotTurnIfNeeded() {
guard turn == .black, winner == nil else { return }
drawUntilPlayableOrEmpty(.black)
guard let hand = hands[.black] else { return }

// Prefer the heaviest playable tile (gets rid of high-pip tiles early);
// prefer playing a double when available, as it opens more options.
let candidates = hand.compactMap { tile -> (DominoTile, DominoSide)? in
guard let side = legalSides(for: tile).first else { return nil }
return (tile, side)
}
guard let choice = candidates.max(by: { a, b in
if a.0.isDouble != b.0.isDouble { return b.0.isDouble }
return a.0.pips < b.0.pips
}) else {
// Shouldn't happen: drawUntilPlayableOrEmpty already ensured a move
// or triggered the block path via advanceTurnIfBlocked's caller.
return
}
play(tile: choice.0, side: choice.1, player: .black)
}
}
