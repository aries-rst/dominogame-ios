import SwiftUI

struct GameView: View {
    @ObservedObject var store: StoreManager
    @StateObject private var engine = DominoEngine()
    @Environment(\.dismiss) private var dismiss

    private let yard = Color(red: 0.17, green: 0.22, blue: 0.16)
    private let chalk = Color(red: 0.95, green: 0.94, blue: 0.88)
    private let brick = Color(red: 0.70, green: 0.27, blue: 0.20)
    private let olive = Color(red: 0.34, green: 0.40, blue: 0.26)
    private let tileFace = Color(red: 0.98, green: 0.97, blue: 0.93)
    private let tileInk = Color(red: 0.12, green: 0.12, blue: 0.12)

    var body: some View {
        ZStack {
            yard.ignoresSafeArea()
            VStack(spacing: 14) {
                header
                boardView
                Spacer(minLength: 4)
                handView
                footer
            }
            .padding(.top, 10)
        }
        .onChange(of: engine.turn) { _ in
            botTurnIfNeeded()
        }
        .onAppear { botTurnIfNeeded() }
        .alert(
            "Игра окончена",
            isPresented: Binding(get: { engine.winner != nil || engine.isDraw }, set: { _ in })
        ) {
            Button("Новая игра") { engine.reset() }
            Button("В меню") { dismiss() }
        } message: {
            Text(engine.statusMessage.isEmpty
                 ? (engine.winner == .white ? "Вы победили!" : "Бот победил!")
                 : engine.statusMessage)
        }
    }

    private var header: some View {
        HStack {
            Text("Бот: \(engine.hands[.black]?.count ?? 0)")
                .foregroundStyle(chalk)
            Spacer()
            Text("Базар: \(engine.boneyard.count)")
                .font(.caption)
                .foregroundStyle(olive)
            Spacer()
            Text(engine.turn == .white ? "Ваш ход" : "Ход бота")
                .font(.headline)
                .foregroundStyle(brick)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
    }

    private var boardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if let selected = engine.selectedTile, let left = engine.leftEnd,
                   engine.legalSides(for: selected).contains(.left) {
                    endTapTarget(value: left, side: .left)
                }
                ForEach(engine.board) { tile in
                    tileView(tile, highlight: false)
                }
                if let selected = engine.selectedTile, let right = engine.rightEnd,
                   engine.legalSides(for: selected).contains(.right) {
                    endTapTarget(value: right, side: .right)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 70)
        }
        .frame(height: 90)
        .background(olive.opacity(0.25))
    }

    private func endTapTarget(value: Int, side: DominoSide) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(brick, lineWidth: 2)
            .frame(width: 40, height: 60)
            .overlay(Image(systemName: "arrow.down").foregroundStyle(brick))
            .onTapGesture { engine.tapEnd(side) }
    }

    private var handView: some View {
        VStack(spacing: 6) {
            Text("Ваши кости")
                .font(.caption)
                .foregroundStyle(chalk.opacity(0.7))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(engine.hands[.white] ?? []) { tile in
                        tileView(tile, highlight: engine.selectedTile == tile)
                            .opacity(engine.legalSides(for: tile).isEmpty ? 0.4 : 1)
                            .onTapGesture { engine.tapHandTile(tile) }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .background(olive.opacity(0.15))
    }

    private func tileView(_ tile: DominoTile, highlight: Bool) -> some View {
        HStack(spacing: 0) {
            pipHalf(tile.a)
            Rectangle().fill(tileInk).frame(width: 1.5)
            pipHalf(tile.b)
        }
        .frame(width: 56, height: 28)
        .background(tileFace)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(highlight ? brick : Color.black.opacity(0.35), lineWidth: highlight ? 2.5 : 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }

    private func pipHalf(_ value: Int) -> some View {
        let positions = DominoGameView.pipPattern(value)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 3), spacing: 1) {
            ForEach(0..<9, id: \.self) { i in
                Circle()
                    .fill(positions.contains(i) ? tileInk : .clear)
                    .frame(width: 3.5, height: 3.5)
            }
        }
        .padding(3)
        .frame(width: 27, height: 27)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                engine.reset()
            } label: {
                Label("Новая игра", systemImage: "arrow.counterclockwise")
            }
            Spacer()
            if !store.isPremium {
                Text("Реклама в бесплатной версии")
                    .font(.caption)
                    .foregroundStyle(chalk.opacity(0.5))
            }
        }
        .foregroundStyle(chalk)
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    private func botTurnIfNeeded() {
        guard engine.turn == .black, engine.winner == nil, !engine.isDraw else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            engine.playBotTurnIfNeeded()
        }
    }
}

/// Namespace holding the static domino pip layout used by GameView's tile faces.
enum DominoGameView {
    static func pipPattern(_ value: Int) -> Set<Int> {
        switch value {
        case 0: return []
        case 1: return [4]
        case 2: return [0, 8]
        case 3: return [0, 4, 8]
        case 4: return [0, 2, 6, 8]
        case 5: return [0, 2, 4, 6, 8]
        case 6: return [0, 2, 3, 5, 6, 8]
        default: return []
        }
    }
}

struct PremiumView: View {
    @ObservedObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    private let brick = Color(red: 0.70, green: 0.27, blue: 0.20)

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(brick)
                    .padding(.top, 24)

                Text("Domino Yard Premium")
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 12) {
                    featureRow("Без рекламы")
                    featureRow("Локальный мультиплеер по Wi-Fi/Bluetooth")
                    featureRow("Разовая покупка — навсегда")
                }
                .padding(.horizontal, 24)

                if store.isPremium {
                    Label("Premium уже активен", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        Task { await store.purchasePremium() }
                    } label: {
                        Text("Купить за \(store.priceText)")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(brick)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)

                    Button("Восстановить покупки") {
                        Task { await store.restorePurchases() }
                    }
                    .font(.footnote)
                }

                if let err = store.purchaseErrorMessage {
                    Text(err).font(.caption).foregroundStyle(.red)
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text(text)
        }
    }
}

#Preview {
    GameView(store: StoreManager())
}
