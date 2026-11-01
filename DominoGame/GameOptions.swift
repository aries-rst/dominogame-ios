import Foundation

/// Local vs-bot game setup, persisted between launches (mirrors Android's
/// `GameOpts` / `Store.loadOpts`/`saveOpts`).
struct GameOptions: Codable, Equatable {
    var variant: String = Domino.KOZEL
    var players: Int = 4
    var botLevel: Int = 2 // 1 easy, 2 medium, 3 hard

    private static let key = "domino.localGameOptions.v1"

    static func load() -> GameOptions {
        guard let data = UserDefaults.standard.data(forKey: key),
              let opts = try? JSONDecoder().decode(GameOptions.self, from: data) else {
            return GameOptions()
        }
        return opts
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
