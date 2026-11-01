import SwiftUI

/// Rich local vs-bot game screen: avatars/team tags, a real zig-zag
/// tile-chain board with pip graphics, tile-count indicators, a hint button
/// and status text — full parity with the Android sibling app's layout and
/// mechanics, built with this app's own "Domino Yard" palette.
struct LocalGameView: View {
    @ObservedObject var store: StoreManager
    @ObservedObject private var lang = AppLang.shared
    @StateObject private var engine: LocalGameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var pulse = false

    // Domino Yard's own palette — never Android's literal felt/wood colors.
    private let yard = Color(red: 0.17, green: 0.22, blue: 0.16)
    private let chalk = Color(red: 0.95, green: 0.94, blue: 0.88)
    private let brick = Color(red: 0.70, green: 0.27, blue: 0.20)
    private let olive = Color(red: 0.34, green: 0.40, blue: 0.26)
    private let gold = Color(red: 0.85, green: 0.68, blue: 0.22)
    private let tileFace = Color(red: 0.98, green: 0.97, blue: 0.93)
    private let tileInk = Color(red: 0.12, green: 0.12, blue: 0.12)

    init(store: StoreManager, options: GameOptions) {
        self.store = store
        _engine = StateObject(wrappedValue: LocalGameEngine(variant: options.variant, players: options.players, botLevel: options.botLevel))
    }

    private var isTeams: Bool { engine.match.V.teams }
    private var boardPalette: TilePalette { TilePalette(face: tileFace, rim: Color.black.opacity(0.4), line: tileInk.opacity(0.6), pip: tileInk) }

    var body: some View {
        ZStack {
            yard.ignoresSafeArea()
            VStack(spacing: 10) {
                topBar
                seatsRow
                boardSection
                statusArea
                actionsRow
                Spacer(minLength: 2)
                handSection
            }
            .padding(.top, 8)
        }
        .sheet(isPresented: Binding(get: { engine.match.st?.roundOver ?? false }, set: { _ in })) {
            roundOverSheet
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(chalk.opacity(0.7))
                    .font(.title3)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(variantTitle).font(.headline).foregroundStyle(chalk)
                Text("\(t("Score", "Счёт")) \(t("to \(engine.match.V.target)", "до \(engine.match.V.target)"))")
                    .font(.caption2).foregroundStyle(olive)
            }
            Spacer()
            Text(scoreMini).font(.caption.bold()).foregroundStyle(brick)
        }
        .padding(.horizontal, 16)
    }

    private var variantTitle: String {
        switch engine.match.variant {
        case Domino.KOZEL: return t("Partners", "Козёл")
        case Domino.BLOCK: return t("Block", "Блок")
        case Domino.DRAW: return t("Draw", "С добором")
        case Domino.FIVES: return t("All Fives", "Пятёрки")
        default: return ""
        }
    }

    private var scoreMini: String {
        if isTeams {
            return "\(engine.match.scores[engine.humanSeat % 2]) : \(engine.match.scores[1 - engine.humanSeat % 2])"
        }
        return engine.match.scores.map(String.init).joined(separator: " · ")
    }

    // MARK: - Seats

    private var seatsRow: some View {
        let n = engine.match.n
        let order = n > 1 ? (1..<n).map { (engine.humanSeat + $0) % n } : []
        return HStack(spacing: 22) {
            ForEach(order, id: \.self) { p in seatView(p) }
        }
        .padding(.horizontal, 16)
    }

    private func seatView(_ p: Int) -> some View {
        let isTurn = Domino.pending(engine.match)?.p == p
        let count = engine.match.st?.hands[p].count ?? 0
        let onUs = (p % 2) == (engine.humanSeat % 2)
        return VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Text(avatarEmoji(p))
                    .font(.system(size: 28))
                    .padding(8)
                    .background(Circle().fill(olive.opacity(0.35)))
                    .overlay(Circle().stroke(isTurn ? gold : Color.clear, lineWidth: 3))
                if isTeams {
                    Text(onUs ? t("Us", "Мы") : t("Them", "Они"))
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(onUs ? olive : brick))
                        .foregroundStyle(chalk)
                        .offset(x: 12, y: -6)
                }
            }
            Text(seatName(p)).font(.caption2).foregroundStyle(chalk).lineLimit(1)
            tileCountIndicator(count)
        }
    }

    private func avatarEmoji(_ p: Int) -> String {
        ["🙂", "🧔", "👩", "👳"][p % 4]
    }

    private func tileCountIndicator(_ count: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<min(count, 10), id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5).fill(chalk.opacity(0.75)).frame(width: 4, height: 10)
            }
            if count > 10 {
                Text("+").font(.system(size: 9)).foregroundStyle(chalk.opacity(0.75))
            }
        }
    }

    private func seatName(_ p: Int) -> String {
        if p == engine.humanSeat { return t("You", "Вы") }
        if isTeams && p == (engine.humanSeat + 2) % engine.match.n { return t("Partner", "Партнёр") }
        return "\(t("Bot", "Бот")) \(p)"
    }

    // MARK: - Board

    private var basePlaced: [Placed] {
        guard let st = engine.match.st, let f = st.first else { return [] }
        return BoardLayout.layout(first: f, spinner: st.spinner, arms: st.arms)
    }

    private var ghostPlacements: [(DMove, Placed)] {
        guard let st = engine.match.st, let f = st.first, let sel = engine.selectedTileID else { return [] }
        let legal = Domino.moves(engine.match, engine.humanSeat).filter { $0.id == sel }
        guard let tile = st.hands[engine.humanSeat].first(where: { $0.id == sel }) else { return [] }
        var out: [(DMove, Placed)] = []
        for mv in legal {
            let v = st.ends[mv.arm]
            let other = (tile.a == v) ? tile.b : tile.a
            let extraItem = ArmItem(t: tile, open: other, touch: v)
            let placedAll = BoardLayout.layout(first: f, spinner: st.spinner, arms: st.arms, extra: (mv.arm, extraItem))
            if let ghost = placedAll.last(where: { $0.ghost }) {
                out.append((mv, ghost))
            }
        }
        return out
    }

    private func computeTransform(placed: [Placed], size: CGSize) -> (scale: CGFloat, originX: CGFloat, originY: CGFloat) {
        guard !placed.isEmpty, size.width > 0, size.height > 0 else {
            return (1, size.width / 2, size.height / 2)
        }
        var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude, maxY = -Float.greatestFiniteMagnitude
        for p in placed {
            minX = min(minX, p.x); maxX = max(maxX, p.x + p.w)
            minY = min(minY, p.y); maxY = max(maxY, p.y + p.h)
        }
        let margin: Float = 0.5
        minX -= margin; maxX += margin; minY -= margin; maxY += margin
        let boundW = CGFloat(maxX - minX)
        let boundH = CGFloat(maxY - minY)
        guard boundW > 0, boundH > 0 else { return (1, size.width / 2, size.height / 2) }
        let scale = min(size.width / boundW, size.height / boundH)
        let centerXUnits = CGFloat(minX + maxX) / 2
        let centerYUnits = CGFloat(minY + maxY) / 2
        return (scale, size.width / 2 - centerXUnits * scale, size.height / 2 - centerYUnits * scale)
    }

    private func placedRect(_ p: Placed, scale: CGFloat, ox: CGFloat, oy: CGFloat) -> CGRect {
        CGRect(x: ox + CGFloat(p.x) * scale, y: oy + CGFloat(p.y) * scale, width: CGFloat(p.w) * scale, height: CGFloat(p.h) * scale)
    }

    private var boardSection: some View {
        GeometryReader { geo in
            let ghosts = ghostPlacements
            let bounds = basePlaced + ghosts.map { $0.1 }
            let (scale, ox, oy) = computeTransform(placed: bounds, size: geo.size)
            ZStack {
                Canvas { context, size in
                    for p in basePlaced {
                        let rect = placedRect(p, scale: scale, ox: ox, oy: oy)
                        DominoTileRender.draw(context: context, rect: rect, a: p.a, b: p.b, palette: boardPalette)
                    }
                }
                ForEach(ghosts, id: \.0.arm) { pair in
                    let rect = placedRect(pair.1, scale: scale, ox: ox, oy: oy)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(gold.opacity(pulse ? 0.38 : 0.14))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(gold, lineWidth: 2.5))
                        .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                        .position(x: rect.midX, y: rect.midY)
                        .onTapGesture { engine.playMove(pair.0) }
                }
            }
        }
        .frame(height: 210)
        .background(olive.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }

    // MARK: - Status / actions

    private var statusArea: some View {
        VStack(spacing: 4) {
            Text(statusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(brick)
                .multilineTextAlignment(.center)
            if let toast = engine.toastMessage {
                Text(toast)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: engine.toastMessage)
    }

    private var statusText: String {
        guard let w = Domino.pending(engine.match) else { return "" }
        if w.p == engine.humanSeat {
            switch w.type {
            case "play":
                return engine.selectedTileID == nil
                    ? t("Your turn — pick a tile", "Ваш ход — выберите костяшку")
                    : t("Where to? Tap a highlighted spot", "Куда положить? Нажмите на подсвеченное место")
            case "draw":
                return t("No move — draw from the boneyard", "Нечем ходить — возьмите из базара")
            default:
                return t("No move — pass", "Нечем ходить — пропуск")
            }
        }
        return t("\(seatName(w.p)) is thinking…", "\(seatName(w.p)) думает…")
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            if let w = Domino.pending(engine.match), w.p == engine.humanSeat {
                if w.type == "draw" {
                    pillButton(t("Draw", "Взять из базара"), system: "rectangle.stack", tint: brick) { engine.humanDraw() }
                }
                if w.type == "pass" {
                    pillButton(t("Pass", "Пас"), system: "arrow.uturn.forward", tint: brick) { engine.humanPass() }
                }
                if w.type == "play" {
                    pillButton(t("Hint", "Подсказка"), system: "lightbulb.fill", tint: gold) { engine.requestHint() }
                }
            }
            Spacer()
            if engine.match.V.draw {
                Text("\(t("Boneyard", "Базар")): \(engine.match.st?.bone.count ?? 0)")
                    .font(.caption)
                    .foregroundStyle(chalk.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
    }

    private func pillButton(_ text: String, system: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(text, systemImage: system)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(tint.opacity(0.22)))
                .overlay(Capsule().stroke(tint.opacity(0.7), lineWidth: 1))
                .foregroundStyle(chalk)
        }
    }

    // MARK: - Hand

    private var sortedHand: [DTile] {
        (engine.match.st?.hands[engine.humanSeat] ?? []).sorted { a, b in
            if a.pips != b.pips { return a.pips < b.pips }
            return a.id < b.id
        }
    }

    private var legalTileIDs: Set<Int> {
        guard let w = Domino.pending(engine.match), w.p == engine.humanSeat, w.type == "play" else { return [] }
        return Set(Domino.moves(engine.match, engine.humanSeat).map { $0.id })
    }

    private var hasPendingHuman: Bool {
        Domino.pending(engine.match)?.p == engine.humanSeat
    }

    private var handSection: some View {
        VStack(spacing: 6) {
            Text(t("Your Tiles", "Ваши кости")).font(.caption).foregroundStyle(chalk.opacity(0.7))
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 10) {
                    ForEach(sortedHand, id: \.id) { tile in
                        handTileView(tile)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 160)
        }
        .padding(.vertical, 8)
        .background(olive.opacity(0.15))
    }

    private func handTileView(_ tile: DTile) -> some View {
        let isSelected = engine.selectedTileID == tile.id
        let isHint = engine.hintMoveID == tile.id
        let isLegal = legalTileIDs.contains(tile.id)
        let borderColor: Color = isHint ? gold : (isSelected ? brick : (isLegal ? gold.opacity(0.7) : Color.black.opacity(0.35)))
        let borderWidth: CGFloat = (isSelected || isHint) ? 3 : (isLegal ? 2 : 1)
        return DominoTileFace(a: tile.a, b: tile.b, palette: boardPalette)
            .frame(width: 64, height: 32)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor, lineWidth: borderWidth))
            .opacity((isLegal || !hasPendingHuman) ? 1 : 0.5)
            .offset(y: isSelected ? -6 : 0)
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            .onTapGesture { engine.humanSelect(tileID: tile.id) }
            .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Round / match over

    private func seatOrTeamName(_ slotOrSeat: Int) -> String {
        guard slotOrSeat >= 0 else { return "" }
        if isTeams {
            let humanSlot = engine.humanSeat % 2
            return slotOrSeat == humanSlot ? t("Us", "Мы") : t("Them", "Они")
        }
        return seatName(slotOrSeat)
    }

    @ViewBuilder
    private var roundResultSummary: some View {
        if let r = engine.match.st?.result {
            if r.eggs {
                Text(t("A tie! The points carry over to the next round", "Яйца! Поровну — очки переходят в следующий раунд"))
                    .multilineTextAlignment(.center)
            } else if r.fish {
                VStack(spacing: 4) {
                    Text(t("Blocked!", "Рыба!")).font(.headline).foregroundStyle(chalk)
                    Text(t("Nobody can play — counting the pips in hand", "Ходить больше некому — считаем очки на руках"))
                        .font(.subheadline).foregroundStyle(chalk.opacity(0.8))
                    if r.to >= 0 {
                        Text(t("+\(r.points) — \(seatOrTeamName(r.to))", "+\(r.points) — \(seatOrTeamName(r.to))"))
                            .foregroundStyle(gold)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    if isTeams {
                        let wonByUs = Domino.slot(engine.match, r.winner) == engine.humanSeat % 2
                        Text(wonByUs ? t("Our pair won the round!", "Наша пара выиграла раунд!") : t("The round goes to the opponents", "Раунд за соперниками"))
                            .font(.headline).foregroundStyle(chalk)
                    } else if r.winner == engine.humanSeat {
                        Text(t("You won the round!", "Вы выиграли раунд!")).font(.headline).foregroundStyle(chalk)
                    }
                    if r.to >= 0 {
                        Text(t("+\(r.points) — \(seatOrTeamName(r.to))", "+\(r.points) — \(seatOrTeamName(r.to))"))
                            .foregroundStyle(gold)
                    }
                    Text("\(t("In hand", "На руках")): \(r.hands.enumerated().map { "\(seatName($0.offset)) \($0.element)" }.joined(separator: "  "))")
                        .font(.caption2).foregroundStyle(chalk.opacity(0.7))
                }
            }
        }
    }

    private var scoreSummary: some View {
        VStack(spacing: 2) {
            Text("\(t("Score", "Счёт")) (\(t("to \(engine.match.V.target)", "до \(engine.match.V.target)")))")
                .font(.caption).foregroundStyle(chalk.opacity(0.7))
            if isTeams {
                Text("\(t("Us", "Мы")): \(engine.match.scores[engine.humanSeat % 2])   \(t("Them", "Они")): \(engine.match.scores[1 - engine.humanSeat % 2])")
                    .foregroundStyle(chalk)
            } else {
                Text(engine.match.scores.enumerated().map { "\(seatName($0.offset)): \($0.element)" }.joined(separator: "   "))
                    .foregroundStyle(chalk)
            }
        }
    }

    private var roundOverSheet: some View {
        ZStack {
            yard.ignoresSafeArea()
            VStack(spacing: 18) {
                if engine.match.over {
                    let humanWon = isTeams
                        ? engine.match.winner % 2 == engine.humanSeat % 2
                        : engine.match.winner == engine.humanSeat
                    Text(humanWon ? t("Victory!", "Победа!") : t("Defeat", "Поражение"))
                        .font(.largeTitle.bold())
                        .foregroundStyle(humanWon ? gold : brick)
                    if engine.match.variant == Domino.KOZEL {
                        Text(humanWon ? t("The opponents are the goats!", "Соперники — козлы!") : t("We are the goats…", "Мы — козлы…"))
                            .font(.headline).foregroundStyle(chalk)
                    } else {
                        Text(t("\(seatName(engine.match.winner)) wins the game", "Партию выиграл \(seatName(engine.match.winner))"))
                            .font(.headline).foregroundStyle(chalk)
                    }
                } else {
                    roundResultSummary
                }
                scoreSummary
                HStack(spacing: 16) {
                    Group {
                        if engine.match.over {
                            Button(t("Play again", "Ещё партия")) { engine.rematch() }
                        } else {
                            Button(t("Next round", "Следующий раунд")) { engine.nextRound() }
                        }
                    }
                    .fontWeight(.bold)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(brick)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button(t("Menu", "В меню")) { dismiss() }
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .foregroundStyle(chalk)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(chalk.opacity(0.4), lineWidth: 1))
                }
            }
            .padding(28)
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    LocalGameView(store: StoreManager(), options: GameOptions())
}
