import SwiftUI

/// Setup sheet reachable from "Play vs Bot" on ContentView: pick a variant
/// (Kozel first/default) and, for non-Kozel variants, player count and bot
/// difficulty. Remembers the last choice via `GameOptions`.
struct GameSetupView: View {
    @ObservedObject private var lang = AppLang.shared
    @Binding var options: GameOptions
    var onPlay: () -> Void

    private let yard = Color(red: 0.17, green: 0.22, blue: 0.16)
    private let chalk = Color(red: 0.95, green: 0.94, blue: 0.88)
    private let brick = Color(red: 0.70, green: 0.27, blue: 0.20)
    private let olive = Color(red: 0.34, green: 0.40, blue: 0.26)

    private var isTeams: Bool { Domino.VARIANTS[options.variant]?.teams ?? false }

    var body: some View {
        NavigationStack {
            ZStack {
                yard.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        variantPicker
                        Text(variantHelp)
                            .font(.caption)
                            .foregroundStyle(chalk.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)

                        if isTeams {
                            Text(t("4 players, 2 vs 2 — you + Partner vs Bot 1 + Bot 3.", "4 игрока, 2 на 2 — вы + Партнёр против Бота 1 и Бота 3."))
                                .font(.caption)
                                .foregroundStyle(olive)
                        } else {
                            playersPicker
                        }

                        levelPicker

                        Button(action: {
                            options.save()
                            onPlay()
                        }) {
                            Text(t("Play", "Играть"))
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(brick)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.top, 6)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(t("New Game", "Новая игра"))
        }
        .preferredColorScheme(.dark)
    }

    private var variantPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Variant", "Вариант")).font(.subheadline.bold()).foregroundStyle(chalk)
            Picker("", selection: $options.variant) {
                Text(t("Partners", "Козёл")).tag(Domino.KOZEL)
                Text(t("Block", "Блок")).tag(Domino.BLOCK)
                Text(t("Draw", "С добором")).tag(Domino.DRAW)
                Text(t("All Fives", "Пятёрки")).tag(Domino.FIVES)
            }
            .pickerStyle(.segmented)
            .onChange(of: options.variant) { newValue in
                if Domino.VARIANTS[newValue]?.teams == true { options.players = 4 }
            }
        }
    }

    private var variantHelp: String {
        switch options.variant {
        case Domino.KOZEL:
            return t("4 players, 2 vs 2 — your partner sits opposite. The losing pair collects points; the first pair to reach 101 loses (the \"goats\").", "4 игрока, 2 на 2 — партнёр сидит напротив. Очки копит проигравшая пара; кто набрал 101 — «козлы».")
        case Domino.BLOCK:
            return t("No drawing: can't play — pass. The round winner scores the opponents' pips.", "Без добора: нечем ходить — пропуск. Победитель раунда получает очки с рук соперников.")
        case Domino.DRAW:
            return t("Can't play? Draw from the boneyard until you can.", "Нечем ходить — берёте из базара, пока не найдёте подходящую костяшку.")
        case Domino.FIVES:
            return t("Score when the open ends add up to a multiple of 5. The first double is a spinner with 4 sides.", "Очки за ход, если сумма концов кратна 5. Первый дубль — «спиннер» на 4 стороны.")
        default:
            return ""
        }
    }

    private var playersPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Players", "Игроков")).font(.subheadline.bold()).foregroundStyle(chalk)
            Picker("", selection: $options.players) {
                Text("2").tag(2)
                Text("3").tag(3)
                Text("4").tag(4)
            }
            .pickerStyle(.segmented)
        }
    }

    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Difficulty", "Сложность")).font(.subheadline.bold()).foregroundStyle(chalk)
            Picker("", selection: $options.botLevel) {
                Text(t("Easy", "Лёгкий")).tag(1)
                Text(t("Medium", "Средний")).tag(2)
                Text(t("Hard", "Сложный")).tag(3)
            }
            .pickerStyle(.segmented)
        }
    }
}

#Preview {
    GameSetupView(options: .constant(GameOptions()), onPlay: {})
}
