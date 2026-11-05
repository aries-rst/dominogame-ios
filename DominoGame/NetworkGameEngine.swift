import Foundation
import MultipeerConnectivity

// MARK: - Online multiplayer: host-authoritative wrapper around the real
// `Domino` / `DMatch` engine (replaces the old 1-vs-1 `MultiplayerEngine`
// path for the "Play Nearby" screen).
//
// Same pattern already used for Nardy/Durak's network play in this
// portfolio: the HOST's `NetworkGameEngine` is the only instance that ever
// calls a mutating `Domino.*` function or rolls its `rng` — it broadcasts
// the resulting `DMatch`/`RState` state as an `OnlineSnapshot` after every
// change. Every guest's `NetworkGameEngine` is a pure mirror: it rebuilds a
// local `DMatch` from each snapshot purely so it can reuse the exact same
// read-only helpers (`Domino.pending`, `Domino.moves`, `BoardLayout.layout`,
// …) that `LocalGameEngine`/`LocalGameView` already use for display, and it
// sends small `OnlinePlayIntent`s back to the host ("I want to play tile X
// on side Y") whenever it is that guest's own seat's turn. The host
// re-validates every intent via `Domino.moves` before applying it — a guest
// can never mutate the match directly.

struct NetTile: Codable { let a: Int; let b: Int }
struct NetArmItem: Codable { let a: Int; let b: Int; let open: Int; let touch: Int }
struct NetRoundResult: Codable {
    let winner: Int
    let fish: Bool
    let points: Int
    let to: Int
    let eggs: Bool
    let hands: [Int]
}

/// Included with every broadcast (not just the first) so a guest can always
/// resolve which seat is its own by matching its own device name against
/// `seatNames` — `seatNames[0]` is always the host, `seatNames[1...]` are the
/// guests in the order they joined.
struct OnlineStart: Codable {
    let variant: String
    let seatNames: [String]
}

/// Enough of `DMatch`/`RState` for a guest to mirror the host's state and
/// render it with the same code `LocalGameView` uses: hands per seat, the
/// board (via `arms`/`first`/`spinner`/`ends`), remaining boneyard count,
/// whose turn it is, and the match/round outcome.
struct OnlineSnapshot: Codable {
    let scores: [Int]
    let round: Int
    let leader: Int
    let over: Bool
    let winner: Int
    let eggs: Int
    let hands: [[NetTile]]
    let boneCount: Int
    let arms: [[NetArmItem]]
    let first: NetTile?
    let spinner: Bool
    let ends: [Int]
    let endDouble: [Bool]
    let turn: Int
    let passes: Int
    let lastPlayer: Int
    let roundOver: Bool
    let result: NetRoundResult?
    let mustLead: Int?
}

/// A guest's requested action for its own seat; the host re-validates this
/// against the live `DMatch` before ever applying it.
struct OnlinePlayIntent: Codable {
    let seat: Int
    let action: String // "play" | "draw" | "pass"
    let tileID: Int?
    let arm: Int?
}

/// One wire message. Exactly one of the three fields matters per direction:
/// host → guests carries `start` + `snapshot`; guest → host carries `intent`.
struct OnlineMessage: Codable {
    var start: OnlineStart? = nil
    var snapshot: OnlineSnapshot? = nil
    var intent: OnlinePlayIntent? = nil
}

final class NetworkGameEngine: ObservableObject {
    @Published private(set) var version: Int = 0
    @Published private(set) var toastMessage: String? = nil
    /// Set once the transport reports the connection dropped; the view
    /// should offer the player a way back to the menu.
    @Published private(set) var connectionLost: Bool = false

    private(set) var match: DMatch
    let mySeat: Int
    let isHost: Bool
    /// Fixed for the lifetime of one match: index 0 is the host, 1... are
    /// the guests in join order. Also used to label seats in the UI.
    let seatNames: [String]

    private let multiplayer: MultiplayerManager
    private let rng = SeededGenerator()

    var selectedTileID: Int? = nil

    /// - Parameters:
    ///   - isHost: true to actually run the match (seat 0); false to mirror
    ///     one being run elsewhere.
    ///   - seatNames: seat 0 = host's display name, 1... = guests in join
    ///     order. On the guest side this comes from the host's `OnlineStart`;
    ///     on the host side the caller builds it from `MultiplayerManager`.
    init(multiplayer: MultiplayerManager, isHost: Bool, variant: String, seatNames: [String]) {
        self.multiplayer = multiplayer
        self.isHost = isHost
        self.seatNames = seatNames
        let n = seatNames.count

        if isHost {
            mySeat = 0
            let m = Domino.newMatch(variant: variant, players: n, rnd: rng)
            Domino.newRound(m)
            match = m
        } else {
            mySeat = max(0, seatNames.firstIndex(of: multiplayer.myDisplayName) ?? 0)
            let m = DMatch(variant: variant, n: n, rnd: rng)
            m.st = RState(hands: Array(repeating: [], count: n), bone: [])
            match = m
        }

        multiplayer.onReceive = { [weak self] data in self?.handleIncoming(data) }
        multiplayer.onStateChange = { [weak self] connected in
            guard let self = self, !connected else { return }
            DispatchQueue.main.async {
                self.connectionLost = true
                self.version += 1
            }
        }

        if isHost { broadcast() }
    }

    /// Applies a message that arrived *before* this engine existed (the
    /// very first broadcast, which is what a guest uses to construct the
    /// engine in the first place) — the lobby screen calls this once, right
    /// after creating a guest engine, so that first snapshot isn't lost.
    func ingestInitial(_ msg: OnlineMessage) {
        guard !isHost, let snap = msg.snapshot else { return }
        applySnapshot(snap)
    }

    // MARK: - My actions (identical calls whether I'm the host or a guest)

    func mySelect(tileID: Int) {
        guard let w = Domino.pending(match), w.p == mySeat, w.type == "play" else { return }
        let legal = Domino.moves(match, mySeat).filter { $0.id == tileID }
        if legal.isEmpty {
            showToast(t("This tile doesn't fit now", "Эта костяшка сейчас не подходит"))
            return
        }
        if legal.count == 1 {
            performPlay(legal[0])
        } else {
            selectedTileID = (selectedTileID == tileID) ? nil : tileID
            version += 1
        }
    }

    func performPlay(_ mv: DMove) {
        selectedTileID = nil
        if isHost {
            hostApply(seat: mySeat, action: "play", tileID: mv.id, arm: mv.arm)
        } else {
            sendIntent(action: "play", tileID: mv.id, arm: mv.arm)
        }
    }

    func myDraw() {
        guard let w = Domino.pending(match), w.p == mySeat, w.type == "draw" else { return }
        if isHost {
            hostApply(seat: mySeat, action: "draw", tileID: nil, arm: nil)
        } else {
            sendIntent(action: "draw", tileID: nil, arm: nil)
        }
    }

    func myPass() {
        guard let w = Domino.pending(match), w.p == mySeat, w.type == "pass" else { return }
        if isHost {
            hostApply(seat: mySeat, action: "pass", tileID: nil, arm: nil)
        } else {
            sendIntent(action: "pass", tileID: nil, arm: nil)
        }
    }

    // MARK: - Host-only: advancing between rounds / matches

    func hostNextRound() {
        guard isHost, !match.over else { return }
        Domino.newRound(match)
        selectedTileID = nil
        bumpAndBroadcast()
    }

    func hostRematch() {
        guard isHost else { return }
        let fresh = Domino.newMatch(variant: match.variant, players: match.n, rnd: rng)
        Domino.newRound(fresh)
        match = fresh
        selectedTileID = nil
        bumpAndBroadcast()
    }

    // MARK: - Host: validate then apply any seat's action (local or remote)

    private func hostApply(seat: Int, action: String, tileID: Int?, arm: Int?) {
        guard isHost else { return }
        guard let w = Domino.pending(match), w.p == seat else { return }
        switch action {
        case "play":
            guard let tileID = tileID, let arm = arm,
                  Domino.moves(match, seat).contains(DMove(id: tileID, arm: arm)) else { return }
            Domino.play(match, seat, tileID, arm)
        case "draw":
            guard w.type == "draw" else { return }
            Domino.draw(match, seat)
        case "pass":
            guard w.type == "pass" else { return }
            Domino.pass(match, seat)
        default:
            return
        }
        bumpAndBroadcast()
    }

    private func sendIntent(action: String, tileID: Int?, arm: Int?) {
        multiplayer.send(OnlineMessage(intent: OnlinePlayIntent(seat: mySeat, action: action, tileID: tileID, arm: arm)))
    }

    // MARK: - Networking plumbing

    private func handleIncoming(_ data: Data) {
        guard let msg = try? JSONDecoder().decode(OnlineMessage.self, from: data) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isHost {
                if let intent = msg.intent {
                    self.hostApply(seat: intent.seat, action: intent.action, tileID: intent.tileID, arm: intent.arm)
                }
            } else if let snap = msg.snapshot {
                self.applySnapshot(snap)
            }
        }
    }

    private func bumpAndBroadcast() {
        version += 1
        if isHost { broadcast() }
    }

    private func broadcast() {
        multiplayer.send(OnlineMessage(start: OnlineStart(variant: match.variant, seatNames: seatNames), snapshot: makeSnapshot()))
    }

    private func makeSnapshot() -> OnlineSnapshot {
        let st = match.st!
        return OnlineSnapshot(
            scores: match.scores,
            round: match.round,
            leader: match.leader,
            over: match.over,
            winner: match.winner,
            eggs: match.eggs,
            hands: st.hands.map { $0.map { NetTile(a: $0.a, b: $0.b) } },
            boneCount: st.bone.count,
            arms: st.arms.map { $0.map { NetArmItem(a: $0.t.a, b: $0.t.b, open: $0.open, touch: $0.touch) } },
            first: st.first.map { NetTile(a: $0.a, b: $0.b) },
            spinner: st.spinner,
            ends: st.ends,
            endDouble: st.endDouble,
            turn: st.turn,
            passes: st.passes,
            lastPlayer: st.lastPlayer,
            roundOver: st.roundOver,
            result: st.result.map { NetRoundResult(winner: $0.winner, fish: $0.fish, points: $0.points, to: $0.to, eggs: $0.eggs, hands: $0.hands) },
            mustLead: st.mustLead
        )
    }

    /// Rebuilds the mirrored `RState` (board/hands/turn/etc.) and copies the
    /// top-level `DMatch` fields (scores/round/leader/over/winner/eggs) from
    /// a received snapshot. The boneyard's actual tiles are never shared
    /// (they're never anyone's business but the host's) — only its count,
    /// via a same-length placeholder array, so `st.bone.count` still reads
    /// correctly anywhere the UI shows it.
    private func applySnapshot(_ s: OnlineSnapshot) {
        let st = RState(
            hands: s.hands.map { $0.map { DTile(a: $0.a, b: $0.b) } },
            bone: Array(repeating: DTile(a: 0, b: 0), count: s.boneCount)
        )
        st.arms = s.arms.map { $0.map { ArmItem(t: DTile(a: $0.a, b: $0.b), open: $0.open, touch: $0.touch) } }
        st.first = s.first.map { DTile(a: $0.a, b: $0.b) }
        st.spinner = s.spinner
        st.ends = s.ends
        st.endDouble = s.endDouble
        st.turn = s.turn
        st.passes = s.passes
        st.lastPlayer = s.lastPlayer
        st.roundOver = s.roundOver
        st.mustLead = s.mustLead
        st.result = s.result.map { DRoundResult(winner: $0.winner, fish: $0.fish, points: $0.points, to: $0.to, eggs: $0.eggs, hands: $0.hands) }

        match.scores = s.scores
        match.round = s.round
        match.leader = s.leader
        match.over = s.over
        match.winner = s.winner
        match.eggs = s.eggs
        match.st = st
        version += 1
    }

    private func showToast(_ message: String) {
        toastMessage = message
        version += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.toastMessage = nil
        }
    }
}
