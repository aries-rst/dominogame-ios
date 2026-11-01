import SwiftUI

/// Root screen. Merges the old ContentView (main menu) + GameSetupView
/// (setup sheet) into one screen: variant / players / difficulty are picked
/// directly here, and "Play" goes straight into the game — matching the
/// Android home screen layout (individually-tappable outlined buttons for
/// each choice, not segmented pickers).
struct ContentView: View {
    @StateObject private var store = StoreManager()
    @ObservedObject private var lang = AppLang.shared
    @State private var options = GameOptions.load()

    @State private var showLocalGame = false
    @State private var showLobby = false
    @State private var showPremium = false
    @State private var showStats = false
    @State private var showRules = false
    @State private var showSettings = false

    private let yard = Color(red: 0.17, green: 0.22, blue: 0.16)
    private let chalk = Color(red: 0.95, green: 0.94, blue: 0.88)
    private let brick = Color(red: 0.70, green: 0.27, blue: 0.20)
    private let olive = Color(red: 0.34, green: 0.40, blue: 0.26)
    private let gold = Color(red: 0.85, green: 0.68, blue: 0.22)

    private var isTeams: Bool { Domino.VARIANTS[options.variant]?.teams ?? false }

    var body: some View {
        NavigationStack {
            ZStack {
                yard.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        languageToggle

                        header

                        variantGrid

                        Text(variantHelp)
                            .font(.caption)
                            .foregroundStyle(chalk.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        playersSection

                        difficultySection

                        playButton

                        nearbyButton

                        utilityRow

                        CrossPromoSection(accent: brick, textColor: chalk, cardFill: olive.opacity(0.35))
                    }
                    .padding(20)
                }
            }
            .navigationDestination(isPresented: $showLocalGame) {
                LocalGameView(store: store, options: options)
            }
            .navigationDestination(isPresented: $showLobby) {
                MultiplayerLobbyView(store: store)
            }
            .navigationDestination(isPresented: $showStats) {
                StatsView()
            }
            .navigationDestination(isPresented: $showRules) {
                RulesView()
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView(store: store)
            }
            .sheet(isPresented: $showPremium) {
                PremiumView(store: store)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var languageToggle: some View {
        HStack {
            Spacer()
            Button {
                AppLang.shared.isRussian.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                    Text(lang.isRussian ? "EN" : "RU")
                        .fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(chalk)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(olive.opacity(0.4))
                        .overlay(Capsule().stroke(brick.opacity(0.6), lineWidth: 1))
                )
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 44))
                .foregroundStyle(brick)
            Text(t("DOMINO YARD", "DOMINO YARD"))
                .font(.system(size: 28, weight: .heavy, design: .serif))
                .foregroundStyle(chalk)
                .tracking(3)
            Text(t("Partners, Block, Draw, All Fives · 2–4 players", "Козёл, блок, с добором, пятёрки · 2–4 игрока"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(olive)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Variant picker (2x2 grid of individual buttons)

    private var variantGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            variantButton(t("Partners", "Козёл"), value: Domino.KOZEL)
            variantButton(t("Block", "Блок"), value: Domino.BLOCK)
            variantButton(t("Draw", "С добором"), value: Domino.DRAW)
            variantButton(t("All Fives", "Пятёрки"), value: Domino.FIVES)
        }
    }

    private func variantButton(_ title: String, value: String) -> some View {
        let selected = options.variant == value
        return Button {
            options.variant = value
            if Domino.VARIANTS[value]?.teams == true { options.players = 4 }
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(chalk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(selected ? olive.opacity(0.55) : olive.opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selected ? gold : chalk.opacity(0.15), lineWidth: selected ? 2 : 1)
                        )
                )
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

    // MARK: - Players

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(t("PLAYERS", "ИГРОКОВ"))
            if isTeams {
                teamsPill
            } else {
                HStack(spacing: 12) {
                    chip(t("2", "2"), selected: options.players == 2) { options.players = 2 }
                    chip(t("3", "3"), selected: options.players == 3) { options.players = 3 }
                    chip(t("4", "4"), selected: options.players == 4) { options.players = 4 }
                }
            }
        }
    }

    private var teamsPill: some View {
        HStack {
            Spacer()
            Text(t("2 × 2", "2 × 2"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(chalk)
                .padding(.vertical, 12)
                .padding(.horizontal, 32)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(olive.opacity(0.55))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(gold, lineWidth: 2))
                )
            Spacer()
        }
    }

    // MARK: - Difficulty

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(t("DIFFICULTY", "СЛОЖНОСТЬ"))
            HStack(spacing: 12) {
                chip(t("Easy", "Лёгкий"), selected: options.botLevel == 1) { options.botLevel = 1 }
                chip(t("Medium", "Средний"), selected: options.botLevel == 2) { options.botLevel = 2 }
                chip(t("Hard", "Сложный"), selected: options.botLevel == 3) { options.botLevel = 3 }
            }
        }
    }

    // MARK: - Primary actions

    private var playButton: some View {
        Button {
            options.save()
            showLocalGame = true
        } label: {
            HStack {
                Image(systemName: "play.fill")
                Text(t("Play", "Играть")).fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(yard)
            .background(RoundedRectangle(cornerRadius: 14).fill(gold))
        }
    }

    private var nearbyButton: some View {
        Button {
            if store.isPremium {
                showLobby = true
            } else {
                showPremium = true
            }
        } label: {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                Text(t("Play Nearby", "Игра рядом")).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(chalk)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(olive.opacity(0.35))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(chalk.opacity(0.25), lineWidth: 1))
            )
        }
    }

    private var utilityRow: some View {
        HStack(spacing: 12) {
            smallActionButton(t("Stats", "Статистика"), system: "chart.bar.fill") { showStats = true }
            smallActionButton(t("Rules", "Правила"), system: "book.fill") { showRules = true }
            smallActionButton(t("Settings", "Настройки"), system: "gearshape.fill") { showSettings = true }
        }
    }

    // MARK: - Shared button styles

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(chalk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selected ? olive.opacity(0.55) : olive.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? gold : chalk.opacity(0.12), lineWidth: selected ? 2 : 1)
                        )
                )
        }
    }

    private func smallActionButton(_ title: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: system)
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(chalk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(olive.opacity(0.3))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(chalk.opacity(0.15), lineWidth: 1))
            )
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(chalk.opacity(0.55))
            .tracking(1.2)
    }
}

#Preview {
    ContentView()
}
