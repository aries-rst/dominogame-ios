import Foundation

// MARK: - Rich multi-variant domino engine (Kozel / Block / Draw / All-Fives)
//
// Faithful Swift port of the Android Kotlin engine (`DominoEngine.kt`, the
// `Domino` object). Kept intentionally close to the original structure/order
// of operations so the rules stay bug-for-bug compatible. Types are prefixed
// `D` (DTile, DMove, …) to avoid colliding with the legacy simple 2-player
// engine kept in `MultiplayerEngine.swift` for the online multiplayer mode,
// which is a separate concern from this engine.

/// A seedable xorshift64* RNG so bot/shuffle behaviour can be made
/// deterministic for testing if desired; defaults to a random seed, mirroring
/// Kotlin's `Random.Default` usage in the original engine.
final class SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// Uniform integer in [0, bound).
    func nextInt(_ bound: Int) -> Int {
        guard bound > 0 else { return 0 }
        return Int(next() % UInt64(bound))
    }

    /// Uniform double in [0, 1).
    func nextDouble() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0) // 2^-53
    }
}

/// A domino tile: `a <= b` by convention, `id = a*7 + b` (matches Kotlin's `Tile`).
struct DTile: Equatable, Hashable {
    let a: Int
    let b: Int

    var id: Int { a * 7 + b }
    var pips: Int { a + b }
    var dbl: Bool { a == b }

    static func of(_ id: Int) -> DTile { DTile(a: id / 7, b: id % 7) }

    static let ALL: [DTile] = {
        var out: [DTile] = []
        for a in 0...6 { for b in a...6 { out.append(DTile(a: a, b: b)) } }
        return out
    }()
}

/// A tile placed on one arm of the line. `open` = the number now facing out,
/// `touch` = the number that was joined to the previous tile.
struct ArmItem {
    let t: DTile
    let open: Int
    let touch: Int
}

/// A candidate move: `arm` is -1 when leading (first tile of the round),
/// otherwise 0=left, 1=right, 2=up, 3=down (up/down only open on a spinner).
struct DMove: Equatable {
    let id: Int
    let arm: Int
}

struct DVariant {
    let teams: Bool
    let draw: Bool
    let fives: Bool
    let spinner: Bool
    let target: Int
    let loseAtTarget: Bool

    init(teams: Bool, draw: Bool, fives: Bool, spinner: Bool, target: Int, loseAtTarget: Bool = false) {
        self.teams = teams
        self.draw = draw
        self.fives = fives
        self.spinner = spinner
        self.target = target
        self.loseAtTarget = loseAtTarget
    }
}

struct DRoundResult {
    let winner: Int
    let fish: Bool
    let points: Int
    let to: Int
    let eggs: Bool
    let hands: [Int]
}

struct DLastEv {
    let t: String
    let p: Int
    let id: Int
    let arm: Int
    let scored: Int

    init(_ t: String, _ p: Int, id: Int = -1, arm: Int = -1, scored: Int = 0) {
        self.t = t
        self.p = p
        self.id = id
        self.arm = arm
        self.scored = scored
    }
}

/// Mutable round state. Kept as a class (reference type) so engine functions
/// can mutate it in place exactly like the Kotlin `RState` class does.
final class RState {
    var hands: [[DTile]]
    var bone: [DTile]
    var arms: [[ArmItem]] = [[], [], [], []]
    var first: DTile? = nil
    var spinner: Bool = false
    var ends: [Int] = [0, 0, 0, 0]
    var endDouble: [Bool] = [false, false, false, false]
    var turn: Int = 0
    var passes: Int = 0
    var lastPlayer: Int = -1
    var roundOver: Bool = false
    var result: DRoundResult? = nil
    var last: DLastEv? = nil
    var mustLead: Int? = nil

    init(hands: [[DTile]], bone: [DTile]) {
        self.hands = hands
        self.bone = bone
    }
}

/// A full match (one or more rounds) of a given variant.
final class DMatch {
    let variant: String
    let n: Int
    let rnd: SeededGenerator
    let V: DVariant
    var scores: [Int]
    var round: Int = 0
    var leader: Int = -1
    var over: Bool = false
    var winner: Int = -1
    var eggs: Int = 0
    var st: RState!

    var started: Bool { round > 0 }

    init(variant: String, n: Int, rnd: SeededGenerator) {
        self.variant = variant
        self.n = n
        self.rnd = rnd
        self.V = Domino.VARIANTS[variant]!
        self.scores = Array(repeating: 0, count: V.teams ? 2 : n)
    }
}

struct DPending {
    let type: String // "play" | "draw" | "pass"
    let p: Int
}

enum Domino {
    static let KOZEL = "kozel"
    static let BLOCK = "block"
    static let DRAW = "draw"
    static let FIVES = "fives"
    static let VARIANT_IDS = [KOZEL, BLOCK, DRAW, FIVES]

    static let VARIANTS: [String: DVariant] = [
        KOZEL: DVariant(teams: true, draw: false, fives: false, spinner: false, target: 101, loseAtTarget: true),
        BLOCK: DVariant(teams: false, draw: false, fives: false, spinner: false, target: 100),
        DRAW: DVariant(teams: false, draw: true, fives: false, spinner: false, target: 100),
        FIVES: DVariant(teams: false, draw: true, fives: true, spinner: true, target: 150)
    ]

    static func handPips(_ h: [DTile]) -> Int { h.reduce(0) { $0 + $1.pips } }

    static func newMatch(variant: String, players: Int, rnd: SeededGenerator = SeededGenerator()) -> DMatch {
        let V = VARIANTS[variant]!
        let n = V.teams ? 4 : min(max(players, 2), 4)
        return DMatch(variant: variant, n: n, rnd: rnd)
    }

    static func slot(_ m: DMatch, _ p: Int) -> Int { m.V.teams ? p % 2 : p }

    @discardableResult
    static func newRound(_ m: DMatch) -> RState {
        let V = m.V
        let n = m.n
        var set = DTile.ALL
        if set.count > 1 {
            for i in stride(from: set.count - 1, through: 1, by: -1) {
                let j = m.rnd.nextInt(i + 1)
                set.swapAt(i, j)
            }
        }
        let per = (V.draw && n > 2) ? 5 : 7
        var hands: [[DTile]] = Array(repeating: [], count: n)
        for _ in 0..<per {
            for p in 0..<n {
                hands[p].append(set.removeLast())
            }
        }
        m.round += 1
        let st = RState(hands: hands, bone: set)
        if m.round == 1 || m.leader < 0 {
            if m.variant == KOZEL {
                for p in 0..<n {
                    if hands[p].contains(where: { $0.a == 1 && $0.b == 1 }) {
                        st.turn = p
                        st.mustLead = 8 // Tile(1,1).id == 1*7+1
                    }
                }
            } else {
                var best = -1
                var bp = 0
                var bt: DTile? = nil
                for p in 0..<n {
                    for t in hands[p] {
                        let v = t.dbl ? 100 + t.a : t.pips
                        if v > best { best = v; bp = p; bt = t }
                    }
                }
                st.turn = bp
                st.mustLead = bt!.id
            }
        } else {
            st.turn = m.leader
        }
        m.st = st
        return st
    }

    static func openArms(_ st: RState) -> [Int] {
        if st.first == nil { return [] }
        if st.spinner && !st.arms[0].isEmpty && !st.arms[1].isEmpty {
            return [0, 1, 2, 3]
        }
        return [0, 1]
    }

    static func moves(_ m: DMatch, _ p: Int) -> [DMove] {
        let st = m.st
        if st.roundOver { return [] }
        let h = st.hands[p]
        if st.first == nil {
            return h.filter { st.mustLead == nil || $0.id == st.mustLead! }.map { DMove(id: $0.id, arm: -1) }
        }
        var out: [DMove] = []
        let arms = openArms(st)
        for t in h {
            for arm in arms {
                let v = st.ends[arm]
                if t.a == v || t.b == v { out.append(DMove(id: t.id, arm: arm)) }
            }
        }
        return out
    }

    /// Sum of the open ends (All Fives): a double at an end counts twice; an
    /// uncovered spinner side counts the spinner.
    static func endsSum(_ st: RState) -> Int {
        guard let f = st.first else { return 0 }
        func endVal(_ arm: Int) -> Int { st.endDouble[arm] ? 2 * st.ends[arm] : st.ends[arm] }
        if st.spinner {
            let v = f.a
            if st.arms[0].isEmpty && st.arms[1].isEmpty { return 2 * v }
            var s = 0
            for arm in 0...1 { if !st.arms[arm].isEmpty { s += endVal(arm) } }
            if st.arms[0].isEmpty || st.arms[1].isEmpty { s += 2 * v }
            for arm in 2...3 { if !st.arms[arm].isEmpty { s += endVal(arm) } }
            return s
        }
        if st.arms[0].isEmpty && st.arms[1].isEmpty {
            return f.dbl ? 2 * f.a : f.a + f.b
        }
        return endVal(0) + endVal(1)
    }

    static func play(_ m: DMatch, _ p: Int, _ id: Int, _ arm: Int) {
        let V = m.V
        let st = m.st
        let i = st.hands[p].firstIndex { $0.id == id }!
        let t = st.hands[p].remove(at: i)
        var scored = 0
        if st.first == nil {
            st.first = t
            st.mustLead = nil
            st.spinner = V.spinner && t.dbl
            st.ends[0] = t.a; st.ends[1] = t.b; st.ends[2] = t.a; st.ends[3] = t.a
            st.endDouble[0] = t.dbl; st.endDouble[1] = t.dbl; st.endDouble[2] = false; st.endDouble[3] = false
        } else {
            let v = st.ends[arm]
            let other = (t.a == v) ? t.b : t.a
            st.arms[arm].append(ArmItem(t: t, open: other, touch: v))
            st.ends[arm] = other
            st.endDouble[arm] = t.dbl
        }
        if V.fives {
            let s = endsSum(st)
            if s > 0 && s % 5 == 0 {
                scored = s
                m.scores[slot(m, p)] += s
            }
        }
        st.passes = 0
        st.lastPlayer = p
        st.last = DLastEv("play", p, id: id, arm: arm, scored: scored)
        if st.hands[p].isEmpty {
            endRound(m, p, false, false)
            return
        }
        if V.fives && m.scores[slot(m, p)] >= V.target {
            endRound(m, p, false, true)
            return
        }
        st.turn = (p + 1) % m.n
    }

    static func canDraw(_ m: DMatch, _ p: Int) -> Bool {
        let st = m.st
        return m.V.draw && !st.roundOver && st.first != nil && moves(m, p).isEmpty && !st.bone.isEmpty
    }

    static func draw(_ m: DMatch, _ p: Int) {
        let st = m.st
        st.hands[p].append(st.bone.removeLast())
        st.last = DLastEv("draw", p)
    }

    static func pass(_ m: DMatch, _ p: Int) {
        let st = m.st
        st.passes += 1
        st.last = DLastEv("pass", p)
        if st.passes >= m.n {
            endRound(m, -1, true, false)
            return
        }
        st.turn = (p + 1) % m.n
    }

    static func pending(_ m: DMatch) -> DPending? {
        if m.over || !m.started { return nil }
        let st = m.st
        if st.roundOver { return nil }
        let p = st.turn
        if !moves(m, p).isEmpty { return DPending(type: "play", p: p) }
        if canDraw(m, p) { return DPending(type: "draw", p: p) }
        return DPending(type: "pass", p: p)
    }

    private static func round5(_ x: Int) -> Int {
        Int((Double(x) / 5.0).rounded()) * 5
    }

    private static func endRound(_ m: DMatch, _ winnerSeat: Int, _ fish: Bool, _ reachedByFives: Bool) {
        let V = m.V
        let st = m.st
        st.roundOver = true
        let hands = st.hands.map { handPips($0) }
        var winner = winnerSeat
        var points = 0
        var to = -1
        var eggs = false
        if reachedByFives {
            to = slot(m, winnerSeat)
        } else if V.teams {
            let tp = [hands[0] + hands[2], hands[1] + hands[3]]
            if !fish {
                let lt = 1 - winnerSeat % 2
                points = tp[lt] + m.eggs
                to = lt
                m.eggs = 0
                m.leader = winnerSeat
            } else {
                if tp[0] == tp[1] {
                    eggs = true
                    m.eggs += tp[0] + tp[1]
                } else {
                    let lt = tp[0] > tp[1] ? 0 : 1
                    points = tp[0] + tp[1] + m.eggs
                    to = lt
                    m.eggs = 0
                }
                m.leader = st.lastPlayer >= 0 ? st.lastPlayer : 0
                winner = to >= 0 ? (to == 0 ? 1 : 0) : -1
            }
            if to >= 0 { m.scores[to] += points }
        } else {
            var w = winnerSeat
            if fish {
                let minV = hands.min()!
                let ws = hands.indices.filter { hands[$0] == minV }
                w = ws.count == 1 ? ws[0] : -1
            }
            winner = w
            if w >= 0 {
                var pts = hands.indices.filter { $0 != w }.reduce(0) { $0 + hands[$1] }
                if V.fives { pts = round5(pts) }
                points = pts
                to = w
                m.scores[w] += pts
                m.leader = w
            } else {
                m.leader = st.lastPlayer >= 0 ? st.lastPlayer : 0
            }
        }
        st.result = DRoundResult(winner: winner, fish: fish, points: points, to: to, eggs: eggs, hands: hands)
        st.last = DLastEv(fish ? "fish" : "domino", winnerSeat)
        if V.loseAtTarget {
            if let lost = m.scores.firstIndex(where: { $0 >= V.target }) {
                m.over = true
                m.winner = 1 - lost
            }
        } else {
            let best = m.scores.max()!
            if best >= V.target {
                m.over = true
                m.winner = m.scores.firstIndex(of: best)!
            }
        }
    }

    // MARK: - Bots: 1 easy, 2 normal, 3 strong

    private static func simScore(_ m: DMatch, _ p: Int, _ mv: DMove) -> Int {
        let st = m.st
        if !m.V.fives { return 0 }
        let t = st.hands[p].first { $0.id == mv.id }!
        var s: Int
        if st.first == nil {
            s = t.dbl ? 2 * t.a : t.pips
        } else {
            let saveEnd = st.ends[mv.arm]
            let saveDbl = st.endDouble[mv.arm]
            let v = st.ends[mv.arm]
            let other = (t.a == v) ? t.b : t.a
            st.ends[mv.arm] = other
            st.endDouble[mv.arm] = t.dbl
            st.arms[mv.arm].append(ArmItem(t: t, open: other, touch: v))
            s = endsSum(st)
            st.arms[mv.arm].removeLast()
            st.ends[mv.arm] = saveEnd
            st.endDouble[mv.arm] = saveDbl
        }
        return (s % 5 == 0) ? s : 0
    }

    static func botMove(_ m: DMatch, _ p: Int, _ level: Int, _ rnd: SeededGenerator) -> DMove? {
        let st = m.st
        let ms = moves(m, p)
        if ms.isEmpty { return nil }
        if level == 1 && rnd.nextDouble() < 0.5 {
            return ms[rnd.nextInt(ms.count)]
        }
        let h = st.hands[p]
        var suit = [Int](repeating: 0, count: 7)
        for t in h {
            suit[t.a] += 1
            if t.b != t.a { suit[t.b] += 1 }
        }
        var best: DMove? = nil
        var bv = -1e9
        for mv in ms {
            let t = h.first { $0.id == mv.id }!
            var v = Double(t.pips) + (t.dbl ? 4.0 : 0.0)
            if level >= 2 { v += Double(simScore(m, p, mv)) * 3 }
            if level == 3 && st.first != nil {
                let end = st.ends[mv.arm]
                let other = (t.a == end) ? t.b : t.a
                v += Double(suit[other]) * 2
                if m.V.teams {
                    let partner = (p + 2) % 4
                    if let l = st.last, l.p == partner, l.arm == mv.arm { v -= 3 }
                }
            }
            v += rnd.nextDouble() * (level == 1 ? 6.0 : 0.5)
            if v > bv { bv = v; best = mv }
        }
        return best
    }

    /// One automatic step for a bot seat; false when a human must act (or the
    /// round/match has ended).
    @discardableResult
    static func botStep(_ m: DMatch, isBot: (Int) -> Bool, level: (Int) -> Int, rnd: SeededGenerator) -> Bool {
        guard let w = pending(m) else { return false }
        if !isBot(w.p) { return false }
        switch w.type {
        case "play":
            let mv = botMove(m, w.p, level(w.p), rnd)!
            play(m, w.p, mv.id, mv.arm)
        case "draw":
            draw(m, w.p)
        default:
            pass(m, w.p)
        }
        return true
    }
}
