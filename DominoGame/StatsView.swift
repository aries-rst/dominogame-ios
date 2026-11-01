import SwiftUI

/// Lightweight local match-result tracker, persisted via UserDefaults.
/// `LocalGameEngine` calls `GameStats.record(...)` once per finished match.
struct GameStats: Codable {
    var played: Int = 0
    var won: Int = 0
    var byVariant: [String: VariantStats] = [:]

    struct VariantStats: Codable {
        var played: Int = 0
        var won: Int = 0
    }

    private static let key = "domino.gameStats.v1"

    static func load() -> GameStats {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(GameStats.self, from: data) else {
            return GameStats()
        }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    static func record(variant: String, won: Bool) {
        var s = load()
        s.played += 1
        if won { s.won += 1 }
        var v = s.byVariant[variant] ?? VariantStats()
        v.played += 1
        if won { v.won += 1 }
        s.byVariant[variant] = v
        s.save()
    }

    static func reset() {
        GameStats().save()
    }
}

/// Real stats screen, pushed from the root screen's "Stats" button.
struct StatsView: View {
    @ObservedObject private var lang = AppLang.shared
    @State private var stats = GameStats.load()

    private let yard = Color(red: 0.17, green: 0.22, blue: 0.16)
    private let chalk = Color(red: 0.95, green: 0.94, blue: 0.88)
    private let brick = Color(red: 0.70, green: 0.27, blue: 0.20)
    private let olive = Color(red: 0.34, green: 0.40, blue: 0.26)
    private let gold = Color(red: 0.85, green: 0.68, blue: 0.22)

    private let variantOrder = [Domino.KOZEL, Domino.BLOCK, Domino.DRAW, Domino.FIVES]

    private func variantLabel(_ v: String) -> String {
        switch v {
        case Domino.KOZEL: return t("Partners", "Козёл")
        case Domino.BLOCK: return t("Block", "Блок")
        case Domino.DRAW: return t("Draw", "С добором")
        case Domino.FIVES: return t("All Fives", "Пятёрки")
        default: return v
        }
    }

    private var winRateText: String {
        guard stats.played > 0 else { return "—" }
        let pct = Int((Double(stats.won) / Double(stats.played) * 100).rounded())
        return "\(pct)%"
    }

    var body: some View {
        ZStack {
            yard.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    overallTiles

                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("BY VARIANT", "ПО ВАРИАНТАМ"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(chalk.opacity(0.55))
                            .tracking(1.2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 10) {
                            ForEach(variantOrder, id: \.self) { v in
                                variantRow(v)
                            }
                        }
                    }

                    Button {
                        GameStats.reset()
                        stats = GameStats.load()
                    } label: {
                        Text(t("Reset Stats", "Сбросить статистику"))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(brick)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(olive.opacity(0.2))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(brick.opacity(0.6), lineWidth: 1))
                            )
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(t("Stats", "Статистика"))
        .preferredColorScheme(.dark)
        .onAppear {
            stats = GameStats.load()
        }
    }

    private var overallTiles: some View {
        HStack(spacing: 12) {
            statTile(t("Played", "Сыграно"), value: "\(stats.played)")
            statTile(t("Won", "Побед"), value: "\(stats.won)")
            statTile(t("Win Rate", "Процент побед"), value: winRateText)
        }
    }

    private func statTile(_ label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(gold)
            Text(label)
                .font(.caption)
                .foregroundStyle(chalk.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(olive.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(chalk.opacity(0.15), lineWidth: 1))
        )
    }

    private func variantRow(_ v: String) -> some View {
        let vs = stats.byVariant[v] ?? GameStats.VariantStats()
        return HStack {
            Text(variantLabel(v))
                .font(.subheadline.bold())
                .foregroundStyle(chalk)
            Spacer()
            Text("\(t("Played", "Сыграно")): \(vs.played)")
                .font(.caption)
                .foregroundStyle(chalk.opacity(0.75))
            Text("\(t("Won", "Побед")): \(vs.won)")
                .font(.caption)
                .foregroundStyle(chalk.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(olive.opacity(0.25))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(chalk.opacity(0.1), lineWidth: 1))
        )
    }
}

#Preview {
    NavigationStack { StatsView() }
}
