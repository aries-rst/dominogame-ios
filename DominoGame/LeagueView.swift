import SwiftUI

/// "Домино-лига" — persistent scoreboard across repeated online matches
/// played with the same group of nearby players (identified by the set of
/// device display names seen in a match's `seatNames`). Unlike `GameStats`
/// (one device's own solo record against bots), a league group is shared
/// context for an actual recurring group of people — a courtyard crew that
/// plays together session after session — so each device keeps its own
/// local copy, keyed by that group's name signature, updated once per
/// finished `NetworkGameEngine` match (never for local vs-bot play).
struct DominoLeague: Codable {
    struct PlayerRecord: Codable, Identifiable {
        var id: String { name }
        var name: String
        var played: Int = 0
        var won: Int = 0
    }

    struct Group: Codable, Identifiable {
        var id: String { key }
        /// Stable signature for "the same group" — the participants' device
        /// names, sorted, joined. Independent of join order or who hosted.
        var key: String
        var players: [PlayerRecord]
        var lastPlayed: Date
    }

    var groups: [Group] = []

    private static let storageKey = "domino.league.v1"

    static func load() -> DominoLeague {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let s = try? JSONDecoder().decode(DominoLeague.self, from: data) else {
            return DominoLeague()
        }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// Records one finished match's result into the league. `winnerSeat` is
    /// `DMatch.winner` exactly as the engine leaves it: a team slot (0/1)
    /// when `isTeams`, otherwise a seat index — matching how `NetworkGameView`
    /// already interprets it.
    static func record(seatNames: [String], winnerSeat: Int, isTeams: Bool) {
        guard seatNames.count >= 2 else { return }
        var league = load()
        let key = seatNames.sorted().joined(separator: " · ")
        var group = league.groups.first(where: { $0.key == key })
            ?? Group(key: key, players: seatNames.map { PlayerRecord(name: $0) }, lastPlayed: Date())

        for (seatIndex, name) in seatNames.enumerated() {
            let wonThis = isTeams ? (seatIndex % 2 == winnerSeat) : (seatIndex == winnerSeat)
            if let idx = group.players.firstIndex(where: { $0.name == name }) {
                group.players[idx].played += 1
                if wonThis { group.players[idx].won += 1 }
            } else {
                var rec = PlayerRecord(name: name)
                rec.played = 1
                if wonThis { rec.won = 1 }
                group.players.append(rec)
            }
        }
        group.lastPlayed = Date()

        if let idx = league.groups.firstIndex(where: { $0.key == key }) {
            league.groups[idx] = group
        } else {
            league.groups.append(group)
        }
        league.save()
    }

    static func resetGroup(key: String) {
        var league = load()
        league.groups.removeAll { $0.key == key }
        league.save()
    }

    static func resetAll() {
        DominoLeague().save()
    }
}

/// League screen — a card per remembered group, most recently played first,
/// each a little standings table. Pushed from the root screen's "League"
/// button, next to Stats.
struct LeagueView: View {
    @ObservedObject private var lang = AppLang.shared
    @State private var league = DominoLeague.load()

    private let yard = Color(red: 0.17, green: 0.22, blue: 0.16)
    private let chalk = Color(red: 0.95, green: 0.94, blue: 0.88)
    private let brick = Color(red: 0.70, green: 0.27, blue: 0.20)
    private let olive = Color(red: 0.34, green: 0.40, blue: 0.26)
    private let gold = Color(red: 0.85, green: 0.68, blue: 0.22)

    private var sortedGroups: [DominoLeague.Group] {
        league.groups.sorted { $0.lastPlayed > $1.lastPlayed }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        ZStack {
            yard.ignoresSafeArea()
            if sortedGroups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        ForEach(sortedGroups) { group in
                            groupCard(group)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(t("League", "Домино-лига"))
        .preferredColorScheme(.dark)
        .onAppear { league = DominoLeague.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "rosette")
                .font(.system(size: 44))
                .foregroundStyle(gold.opacity(0.7))
            Text(t("No league play yet", "Пока нет данных лиги"))
                .font(.headline)
                .foregroundStyle(chalk)
            Text(t("Play a match over \"Play Nearby\" and the score for your group will show up here, carried over between sessions.", "Сыграйте партию через «Игра рядом» — счёт вашей группы появится здесь и сохранится между сессиями."))
                .font(.subheadline)
                .foregroundStyle(chalk.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func groupCard(_ group: DominoLeague.Group) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.key.replacingOccurrences(of: " · ", with: ", "))
                        .font(.subheadline.bold())
                        .foregroundStyle(chalk)
                        .lineLimit(2)
                    Text("\(t("Last played", "Последняя игра")): \(Self.dateFormatter.string(from: group.lastPlayed))")
                        .font(.caption2)
                        .foregroundStyle(chalk.opacity(0.55))
                }
                Spacer()
                Button {
                    DominoLeague.resetGroup(key: group.key)
                    league = DominoLeague.load()
                } label: {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .foregroundStyle(brick.opacity(0.8))
                }
            }

            VStack(spacing: 8) {
                ForEach(group.players.sorted(by: { $0.won > $1.won }).indices, id: \.self) { i in
                    let p = group.players.sorted(by: { $0.won > $1.won })[i]
                    standingRow(rank: i + 1, player: p)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(olive.opacity(0.3))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(gold.opacity(0.35), lineWidth: 1))
        )
    }

    private func standingRow(rank: Int, player: DominoLeague.PlayerRecord) -> some View {
        HStack {
            Text("\(rank)")
                .font(.caption.bold())
                .foregroundStyle(rank == 1 ? gold : chalk.opacity(0.5))
                .frame(width: 18, alignment: .leading)
            Text(player.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(chalk)
                .lineLimit(1)
            Spacer()
            Text("\(t("W", "П")) \(player.won)")
                .font(.caption.bold())
                .foregroundStyle(gold)
            Text("/ \(player.played)")
                .font(.caption)
                .foregroundStyle(chalk.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(rank == 1 ? gold.opacity(0.15) : Color.white.opacity(0.04))
        )
    }
}

#Preview {
    NavigationStack { LeagueView() }
}
