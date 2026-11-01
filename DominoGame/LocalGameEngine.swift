import Foundation

/// Drives one local vs-bot `DMatch` and exposes it to SwiftUI. `DMatch`/
/// `RState` are reference types mutated in place by the `Domino` engine
/// functions, so this wrapper bumps a `@Published` counter after every
/// mutation to trigger a redraw — the views read `engine.match` directly.
final class LocalGameEngine: ObservableObject {
    @Published private(set) var version: Int = 0
    @Published private(set) var toastMessage: String? = nil

    private(set) var match: DMatch
    let humanSeat = 0
    private let rng = SeededGenerator()
    private var botLevels: [Int]
    private let botLevel: Int

    /// One-shot guard so a finished match is only recorded into GameStats
    /// once, no matter how many more `bump()`s happen afterwards.
    private var statsRecorded = false

    var selectedTileID: Int? = nil
    var hintMoveID: Int? = nil
    var hintArm: Int? = nil

    init(variant: String, players: Int, botLevel: Int) {
        let m = Domino.newMatch(variant: variant, players: players, rnd: rng)
        self.match = m
        self.botLevel = botLevel
        self.botLevels = Array(repeating: botLevel, count: m.n)
        self.statsRecorded = false
        Domino.newRound(m)
        runBotsIfNeeded()
    }

    private func bump() {
        version += 1
        recordStatsIfFinished()
    }

    private func recordStatsIfFinished() {
        guard match.over, !statsRecorded else { return }
        statsRecorded = true
        let won: Bool
        if Domino.VARIANTS[match.variant]?.teams == true {
            won = Domino.slot(match, match.winner) == humanSeat % 2
        } else {
            won = match.winner == humanSeat
        }
        GameStats.record(variant: match.variant, won: won)
    }

    func isBot(_ p: Int) -> Bool { p != humanSeat }

    // MARK: - Human actions

    func humanSelect(tileID: Int) {
        guard let w = Domino.pending(match), w.p == humanSeat, w.type == "play" else { return }
        let legal = Domino.moves(match, humanSeat).filter { $0.id == tileID }
        if legal.isEmpty {
            showToast(t("This tile doesn't fit now", "Эта костяшка сейчас не подходит"))
            return
        }
        if legal.count == 1 {
            playMove(legal[0])
        } else {
            selectedTileID = (selectedTileID == tileID) ? nil : tileID
            bump()
        }
    }

    func playMove(_ mv: DMove) {
        Domino.play(match, humanSeat, mv.id, mv.arm)
        selectedTileID = nil
        hintMoveID = nil
        hintArm = nil
        bump()
        runBotsIfNeeded()
    }

    func humanDraw() {
        guard let w = Domino.pending(match), w.p == humanSeat, w.type == "draw" else { return }
        Domino.draw(match, humanSeat)
        bump()
    }

    func humanPass() {
        guard let w = Domino.pending(match), w.p == humanSeat, w.type == "pass" else { return }
        Domino.pass(match, humanSeat)
        bump()
        runBotsIfNeeded()
    }

    func requestHint() {
        guard let w = Domino.pending(match), w.p == humanSeat, w.type == "play" else { return }
        if let mv = Domino.botMove(match, humanSeat, 3, rng) {
            hintMoveID = mv.id
            hintArm = mv.arm
            selectedTileID = mv.id
            bump()
        }
    }

    func nextRound() {
        guard !match.over else { return }
        Domino.newRound(match)
        selectedTileID = nil
        hintMoveID = nil
        hintArm = nil
        bump()
        runBotsIfNeeded()
    }

    func rematch() {
        let fresh = Domino.newMatch(variant: match.variant, players: match.n, rnd: rng)
        match = fresh
        botLevels = Array(repeating: botLevel, count: fresh.n)
        statsRecorded = false
        Domino.newRound(fresh)
        selectedTileID = nil
        hintMoveID = nil
        hintArm = nil
        bump()
        runBotsIfNeeded()
    }

    private func showToast(_ message: String) {
        toastMessage = message
        bump()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.toastMessage = nil
        }
    }

    // MARK: - Bot stepping

    private func runBotsIfNeeded(delay: Double = 0.55) {
        guard let w = Domino.pending(match), isBot(w.p) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            let stepped = Domino.botStep(self.match, isBot: self.isBot, level: { self.botLevels[$0] }, rnd: self.rng)
            guard stepped else { return }
            self.bump()
            self.runBotsIfNeeded()
        }
    }
}
