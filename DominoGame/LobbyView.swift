import SwiftUI
import MultipeerConnectivity
import Foundation

/// Online "Play Nearby" lobby. The host picks a variant and how many seats
/// the table has (2-4, reusing the same `Domino.VARIANTS`/`GameOptions`-style
/// values the vs-bot setup uses), then advertises a real game card — host
/// name + variant + target player count — instead of a bare device-name
/// list; up to `players - 1` guests can browse that list and join one host.
/// Once every seat is filled, the host hands off to `NetworkGameEngine`,
/// which runs the real `Domino`/`DMatch` engine host-authoritatively over
/// the network (see that file for the snapshot+intent protocol). This
/// replaces the old 1-vs-1 `GameView`/`MultiplayerEngine` path for online
/// play; `MultiplayerEngine.swift` itself is left in place, unused, exactly
/// as the legacy engine it was already documented to be.
struct MultiplayerLobbyView: View {
    @ObservedObject var store: StoreManager
    @ObservedObject private var lang = AppLang.shared
    @StateObject private var multiplayer = MultiplayerManager(serviceType: "ar-domino")

    private enum Stage: Equatable {
        case choose
        case hostSetup
        case hostRoom
        case browse
        case guestWaiting // invited / connecting / connected, waiting for the host to start
    }

    @State private var stage: Stage = .choose
    @State private var hostVariant: String = Domino.BLOCK
    @State private var hostPlayers: Int = 2
    @State private var engine: NetworkGameEngine? = nil
    @State private var startGame = false

    @Environment(\.dismiss) private var dismiss

    private let yard = Color(red: 0.17, green: 0.22, blue: 0.16)
    private let chalk = Color(red: 0.95, green: 0.94, blue: 0.88)
    private let brick = Color(red: 0.70, green: 0.27, blue: 0.20)
    private let olive = Color(red: 0.34, green: 0.40, blue: 0.26)

    private var isTeams: Bool { Domino.VARIANTS[hostVariant]?.teams ?? false }
    private var roomFull: Bool { multiplayer.connectedPeers.count == hostPlayers - 1 }

    var body: some View {
        NavigationStack {
            ZStack {
                yard.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        header

                        Group {
                            switch stage {
                            case .choose: chooseSection
                            case .hostSetup: hostSetupSection
                            case .hostRoom: hostRoomSection
                            case .browse: browseSection
                            case .guestWaiting: guestWaitingSection
                            }
                        }

                        if let err = multiplayer.errorMessage {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("Close", "Закрыть")) {
                        multiplayer.stop()
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $startGame) {
                if let engine = engine {
                    NetworkGameView(store: store, engine: engine, multiplayer: multiplayer)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi")
                .font(.system(size: 40))
                .foregroundStyle(brick)
                .padding(.top, 10)
            Text(t("Online Game", "Игра по сети"))
                .font(.title2.bold())
                .foregroundStyle(chalk)
        }
    }

    // MARK: - Choose

    private var chooseSection: some View {
        VStack(spacing: 14) {
            Text(t("Host a game so nearby players can find and join it, or find a game that's already been created. Wi-Fi or Bluetooth required.", "Создайте игру, чтобы её нашли игроки рядом, либо найдите уже созданную игру. Нужны Wi-Fi или Bluetooth."))
                .font(.subheadline)
                .foregroundStyle(chalk.opacity(0.7))
                .multilineTextAlignment(.center)

            Button {
                stage = .hostSetup
            } label: {
                lobbyButtonLabel(t("Host a Game", "Создать игру"), system: "antenna.radiowaves.left.and.right")
            }
            Button {
                multiplayer.startBrowsing()
                stage = .browse
            } label: {
                lobbyButtonLabel(t("Find Nearby Games", "Найти игры рядом"), system: "magnifyingglass")
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Host setup (variant + player count, before advertising)

    private var hostSetupSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(t("Choose a variant and how many players will sit at the table, including you. The game starts once every seat is filled.", "Выберите вариант и сколько игроков будет за столом, включая вас. Игра начнётся, когда заполнятся все места."))
                .font(.caption)
                .foregroundStyle(chalk.opacity(0.75))

            VStack(alignment: .leading, spacing: 8) {
                Text(t("Variant", "Вариант")).font(.subheadline.bold()).foregroundStyle(chalk)
                Picker("", selection: $hostVariant) {
                    Text(t("Partners", "Козёл")).tag(Domino.KOZEL)
                    Text(t("Block", "Блок")).tag(Domino.BLOCK)
                    Text(t("Draw", "С добором")).tag(Domino.DRAW)
                    Text(t("All Fives", "Пятёрки")).tag(Domino.FIVES)
                }
                .pickerStyle(.segmented)
                .onChange(of: hostVariant) { newValue in
                    if Domino.VARIANTS[newValue]?.teams == true { hostPlayers = 4 }
                }
            }

            if isTeams {
                Text(t("4 players, 2 vs 2 — teammates sit opposite each other.", "4 игрока, 2 на 2 — партнёры сидят друг напротив друга."))
                    .font(.caption)
                    .foregroundStyle(olive)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("Players", "Игроков")).font(.subheadline.bold()).foregroundStyle(chalk)
                    Picker("", selection: $hostPlayers) {
                        Text("2").tag(2)
                        Text("3").tag(3)
                        Text("4").tag(4)
                    }
                    .pickerStyle(.segmented)
                }
            }

            Button {
                let info: [String: String] = [
                    "host": multiplayer.myDisplayName,
                    "variant": hostVariant,
                    "players": "\(hostPlayers)"
                ]
                multiplayer.startHosting(info: info)
                stage = .hostRoom
            } label: {
                Text(t("Start Hosting", "Начать поиск игроков"))
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(brick)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button(t("Back", "Назад")) { stage = .choose }
                .font(.footnote)
                .foregroundStyle(chalk.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Host room (advertising, waiting for the room to fill)

    private var hostRoomSection: some View {
        VStack(spacing: 16) {
            Text(t("Waiting for players (\(multiplayer.connectedPeers.count + 1)/\(hostPlayers))…", "Ждём игроков (\(multiplayer.connectedPeers.count + 1)/\(hostPlayers))…"))
                .font(.subheadline)
                .foregroundStyle(chalk.opacity(0.8))

            VStack(spacing: 8) {
                seatCard(name: multiplayer.myDisplayName, label: t("Host (you)", "Хост (вы)"), filled: true)
                ForEach(1..<hostPlayers, id: \.self) { i in
                    if i - 1 < multiplayer.connectedPeers.count {
                        seatCard(name: multiplayer.connectedPeers[i - 1].displayName, label: t("Seat \(i)", "Место \(i)"), filled: true)
                    } else {
                        seatCard(name: t("Waiting…", "Ожидание…"), label: t("Seat \(i)", "Место \(i)"), filled: false)
                    }
                }
            }

            Button {
                startHostedGame()
            } label: {
                Text(t("Start Game", "Начать игру"))
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(roomFull ? brick : brick.opacity(0.35))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!roomFull)

            Button(t("Cancel", "Отмена")) {
                multiplayer.stop()
                stage = .choose
            }
            .font(.footnote)
            .foregroundStyle(chalk.opacity(0.6))
        }
    }

    private func seatCard(name: String, label: String, filled: Bool) -> some View {
        HStack {
            Image(systemName: filled ? "person.fill" : "person.dashed")
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.subheadline.weight(.semibold))
                Text(label).font(.caption2)
            }
            Spacer()
        }
        .foregroundStyle(chalk.opacity(filled ? 1 : 0.5))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(brick.opacity(filled ? 0.5 : 0.2), lineWidth: 1))
        )
    }

    /// Host taps "Start Game": seats are the host (seat 0) plus every
    /// connected guest in join order (seat 1, 2, 3…) — this only runs once
    /// `roomFull` so there are no unfilled seats to paper over with bots.
    private func startHostedGame() {
        guard roomFull else { return }
        let names = [multiplayer.myDisplayName] + multiplayer.connectedPeers.map { $0.displayName }
        let e = NetworkGameEngine(multiplayer: multiplayer, isHost: true, variant: hostVariant, seatNames: names)
        multiplayer.stopHostDiscovery()
        engine = e
        startGame = true
    }

    // MARK: - Browse (guest): a real game-card list, not a bare name list

    private var browseSection: some View {
        VStack(spacing: 14) {
            if multiplayer.availablePeers.isEmpty {
                Text(t("Searching for nearby games…", "Поиск игр рядом…"))
                    .font(.subheadline)
                    .foregroundStyle(chalk.opacity(0.7))
            } else {
                VStack(spacing: 10) {
                    ForEach(multiplayer.availablePeers, id: \.self) { peer in
                        gameCard(peer)
                    }
                }
            }
            Button(t("Cancel", "Отмена")) {
                multiplayer.stop()
                stage = .choose
            }
            .font(.footnote)
            .foregroundStyle(chalk.opacity(0.6))
        }
    }

    private func gameCard(_ peer: MCPeerID) -> some View {
        let info = multiplayer.discoveredGames[peer] ?? [:]
        let hostName = info["host"] ?? peer.displayName
        let variant = info["variant"]
        let players = info["players"]
        return Button {
            joinGame(peer)
        } label: {
            HStack {
                Image(systemName: "gamecontroller.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text(hostName).font(.subheadline.weight(.semibold))
                    HStack(spacing: 6) {
                        if let variant = variant {
                            Text(variantLabel(variant))
                        }
                        if let players = players {
                            Text("· \(t("\(players) players", "\(players) игроков"))")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(chalk.opacity(0.6))
                }
                Spacer()
                Text(t("Join", "Войти")).font(.caption.weight(.semibold))
            }
            .foregroundStyle(chalk)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(brick.opacity(0.5), lineWidth: 1))
            )
        }
    }

    private func variantLabel(_ id: String) -> String {
        switch id {
        case Domino.KOZEL: return t("Partners", "Козёл")
        case Domino.BLOCK: return t("Block", "Блок")
        case Domino.DRAW: return t("Draw", "С добором")
        case Domino.FIVES: return t("All Fives", "Пятёрки")
        default: return id
        }
    }

    /// Guest taps a game card: before the match (and this guest's own
    /// `NetworkGameEngine`) exists, the lobby itself listens just long
    /// enough to catch the host's first broadcast (`OnlineMessage.start`),
    /// which is all it needs to build the engine and resolve this device's
    /// own seat — after that, the engine takes over `onReceive` itself.
    private func joinGame(_ peer: MCPeerID) {
        stage = .guestWaiting
        multiplayer.onReceive = { data in
            guard let msg = try? JSONDecoder().decode(OnlineMessage.self, from: data), let start = msg.start else { return }
            DispatchQueue.main.async {
                guard self.engine == nil else { return }
                let e = NetworkGameEngine(multiplayer: multiplayer, isHost: false, variant: start.variant, seatNames: start.seatNames)
                e.ingestInitial(msg)
                self.engine = e
                self.startGame = true
            }
        }
        multiplayer.invite(peer)
    }

    // MARK: - Guest waiting room

    private var guestWaitingSection: some View {
        VStack(spacing: 14) {
            Text(guestStatusText)
                .font(.subheadline)
                .foregroundStyle(chalk.opacity(0.7))
                .multilineTextAlignment(.center)
            Button(t("Cancel", "Отмена")) {
                multiplayer.stop()
                stage = .choose
            }
            .font(.footnote)
            .foregroundStyle(chalk.opacity(0.6))
        }
    }

    private var guestStatusText: String {
        switch multiplayer.state {
        case .connecting:
            return t("Connecting…", "Подключение…")
        case .connected(let name):
            return t("Connected to \(name). Waiting for the host to start the game…", "Подключено к \(name). Ждём, когда хост начнёт игру…")
        default:
            return t("Connecting…", "Подключение…")
        }
    }

    // MARK: - Shared

    private func lobbyButtonLabel(_ text: String, system: String) -> some View {
        HStack {
            Image(systemName: system)
            Text(text).fontWeight(.semibold)
            Spacer()
            Image(systemName: "chevron.right").font(.caption)
        }
        .foregroundStyle(chalk)
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(brick.opacity(0.5), lineWidth: 1))
        )
    }
}
