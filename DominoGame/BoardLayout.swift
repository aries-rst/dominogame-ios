import Foundation

/// A tile placed on the board, in half-tile units: (x, y) is the top-left
/// corner, w×h is 2×1 (horizontal) or 1×2 (vertical); `a`/`b` are the two
/// pip values read in the tile's own left-to-right / top-to-bottom order.
/// Faithful port of Android's `BoardLayout.kt`.
struct Placed {
    let x: Float
    let y: Float
    let w: Float
    let h: Float
    let a: Int
    let b: Int
    let arm: Int
    let ghost: Bool

    init(x: Float, y: Float, w: Float, h: Float, a: Int, b: Int, arm: Int, ghost: Bool = false) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.a = a
        self.b = b
        self.arm = arm
        self.ghost = ghost
    }
}

/// Turns the tile chain (the four arms of `RState`) into rectangles for
/// drawing, laying each arm out from the center and wrapping into a new row
/// when it would run off the board.
enum BoardLayout {
    private struct Loc {
        let cu: Float
        let cv: Float
        let alongU: Bool
        let neg: Int
        let pos: Int
    }

    // arm: 0 Left, 1 Right, 2 Up, 3 Down.
    // Each entry: ((u axis is x?, v axis is x?), (u sign, v sign)).
    private static let MAP: [((Bool, Bool), (Int, Int))] = [
        ((true, false), (-1, -1)), // L: u = -x, v = -y
        ((true, false), (1, 1)),   // R: u = +x, v = +y
        ((false, true), (-1, 1)),  // U: u = -y, v = +x
        ((false, true), (1, -1))   // D: u = +y, v = -x
    ]

    private static func arm(_ list: [ArmItem], _ s0: Float, _ lo: Float, _ hi: Float) -> [Loc] {
        var out: [Loc] = []
        var u: Float = s0
        var rowV: Float = 0
        var dir: Float = 1
        var lastDouble = false
        for it in list {
            let near = it.touch
            let far = it.open
            let dbl = near == far
            let len: Float = dbl ? 1 : 2
            let fits = dir > 0 ? (u + len <= hi) : (u - len >= lo)
            if fits {
                if dbl {
                    out.append(Loc(cu: u + dir * 0.5, cv: rowV, alongU: false, neg: near, pos: far))
                    u += dir
                    lastDouble = true
                } else {
                    let negV = dir > 0 ? near : far
                    let posV = dir > 0 ? far : near
                    out.append(Loc(cu: u + dir, cv: rowV, alongU: true, neg: negV, pos: posV))
                    u += 2 * dir
                    lastDouble = false
                }
            } else {
                let vtop = rowV + (lastDouble ? Float(1.0) : Float(0.5))
                out.append(Loc(cu: u - dir * 0.5, cv: vtop + 1, alongU: false, neg: near, pos: far))
                rowV = vtop + 1.5
                u -= dir
                dir = -dir
                lastDouble = false
            }
        }
        return out
    }

    /// `extra` is a hypothetical tile on an arm (to preview where a move
    /// would go — a "ghost" placement). Its resulting `Placed` has `ghost =
    /// true` and is always the last entry appended for that arm.
    static func layout(first: DTile?, spinner: Bool, arms: [[ArmItem]], extra: (Int, ArmItem)? = nil) -> [Placed] {
        var res: [Placed] = []
        guard let f = first else { return res }
        let fd = f.dbl
        res.append(
            fd ? Placed(x: -0.5, y: -1, w: 1, h: 2, a: f.a, b: f.b, arm: -1)
               : Placed(x: -1, y: -0.5, w: 2, h: 1, a: f.a, b: f.b, arm: -1)
        )

        let cfg: [(Int, (Float, Float, Float))]
        if spinner {
            cfg = [(0, (0.5, 1.5, 6)), (1, (0.5, 1.5, 6)), (2, (1, 1.5, 5)), (3, (1, 1.5, 5))]
        } else {
            let s: Float = fd ? 0.5 : 1
            cfg = [(0, (s, -5, 5)), (1, (s, -5, 5))]
        }

        for (a, c) in cfg {
            var list = arms[a]
            let withExtra = extra != nil && extra!.0 == a
            if withExtra { list.append(extra!.1) }
            let (axes, signs) = MAP[a]
            let locs = arm(list, c.0, c.1, c.2)
            for (idx, p) in locs.enumerated() {
                var gx: Float = 0
                var gy: Float = 0
                if axes.0 { gx += Float(signs.0) * p.cu } else { gy += Float(signs.0) * p.cu }
                if axes.1 { gx += Float(signs.1) * p.cv } else { gy += Float(signs.1) * p.cv }
                let horiz: Bool
                let sign: Int
                if p.alongU { horiz = axes.0; sign = signs.0 } else { horiz = axes.1; sign = signs.1 }
                let va: Int
                let vb: Int
                if sign < 0 { va = p.pos; vb = p.neg } else { va = p.neg; vb = p.pos }
                let w: Float = horiz ? 2 : 1
                let h: Float = horiz ? 1 : 2
                res.append(Placed(
                    x: gx - w / 2, y: gy - h / 2, w: w, h: h,
                    a: va, b: vb, arm: a,
                    ghost: withExtra && idx == locs.count - 1
                ))
            }
        }
        return res
    }
}
