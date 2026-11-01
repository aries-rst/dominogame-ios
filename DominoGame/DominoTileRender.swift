import SwiftUI

/// Colors used to paint one tile face. Callers supply the app's own "Domino
/// Yard" palette — never Android's literal colors.
struct TilePalette {
    let face: Color
    let rim: Color
    let line: Color
    let pip: Color
}

/// Draws a domino tile (rounded-rect face + center divider + pips) into a
/// SwiftUI `Canvas`. Mirrors Android's `drawTile`: orientation (horizontal vs
/// vertical) follows the box's own aspect ratio, and each half's pips are
/// positioned from a normalized 0..1 layout table.
enum DominoTileRender {
    /// Normalized (x, y) pip positions within a half-tile's own square, keyed
    /// by pip count 0...6.
    static let PIPS: [Int: [(CGFloat, CGFloat)]] = [
        0: [],
        1: [(0.5, 0.5)],
        2: [(0.27, 0.27), (0.73, 0.73)],
        3: [(0.27, 0.27), (0.5, 0.5), (0.73, 0.73)],
        4: [(0.27, 0.27), (0.73, 0.27), (0.27, 0.73), (0.73, 0.73)],
        5: [(0.27, 0.27), (0.73, 0.27), (0.5, 0.5), (0.27, 0.73), (0.73, 0.73)],
        6: [(0.27, 0.24), (0.27, 0.5), (0.27, 0.76), (0.73, 0.24), (0.73, 0.5), (0.73, 0.76)]
    ]

    static func draw(context: GraphicsContext, rect: CGRect, a: Int, b: Int, palette: TilePalette) {
        guard rect.width > 0, rect.height > 0 else { return }
        let horizontal = rect.width >= rect.height
        let r = min(rect.width, rect.height) * 0.16
        let facePath = Path(roundedRect: rect, cornerRadius: r)
        context.fill(facePath, with: .color(palette.face))
        context.stroke(facePath, with: .color(palette.rim), lineWidth: max(1, min(rect.width, rect.height) * 0.05))

        var divider = Path()
        if horizontal {
            let mx = rect.midX
            divider.move(to: CGPoint(x: mx, y: rect.minY + rect.height * 0.12))
            divider.addLine(to: CGPoint(x: mx, y: rect.maxY - rect.height * 0.12))
        } else {
            let my = rect.midY
            divider.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: my))
            divider.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: my))
        }
        context.stroke(divider, with: .color(palette.line), lineWidth: max(1, min(rect.width, rect.height) * 0.045))

        let half1: CGRect
        let half2: CGRect
        if horizontal {
            let halfW = rect.width / 2
            half1 = CGRect(x: rect.minX, y: rect.minY, width: halfW, height: rect.height)
            half2 = CGRect(x: rect.minX + halfW, y: rect.minY, width: halfW, height: rect.height)
        } else {
            let halfH = rect.height / 2
            half1 = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: halfH)
            half2 = CGRect(x: rect.minX, y: rect.minY + halfH, width: rect.width, height: halfH)
        }
        drawPips(context: context, rect: half1, value: a, palette: palette)
        drawPips(context: context, rect: half2, value: b, palette: palette)
    }

    private static func drawPips(context: GraphicsContext, rect: CGRect, value: Int, palette: TilePalette) {
        guard let pts = PIPS[value] else { return }
        let dotR = min(rect.width, rect.height) * 0.11
        for pt in pts {
            let cx = rect.minX + rect.width * pt.0
            let cy = rect.minY + rect.height * pt.1
            let dotRect = CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)
            context.fill(Path(ellipseIn: dotRect), with: .color(palette.pip))
        }
    }
}

/// A single reusable tile view for both the board and the hand row.
struct DominoTileFace: View {
    let a: Int
    let b: Int
    let palette: TilePalette

    var body: some View {
        Canvas { context, size in
            DominoTileRender.draw(context: context, rect: CGRect(origin: .zero, size: size), a: a, b: b, palette: palette)
        }
    }
}
