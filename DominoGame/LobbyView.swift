import SwiftUI
import MultipeerConnectivity

struct MultiplayerLobbyView: View {
@ObservedObject var store: StoreManager
@ObservedObject private var lang = AppLang.shared
@StateObject private var multiplayer = MultiplayerManager(serviceType: "ar-domino")
@State private var myRole: DominoPlayer = .white
@State private var startGame = false
@Environment(\.dismiss) private var dismiss

private let yard = Color(red: 0.17, green: 0.22, blue: 0.16)
private let chalk = Color(red: 0.95, green: 0.94, blue: 0.88)
private let brick = Color(red: 0.70, green: 0.27, blue: 0.20)

var body: some View {
NavigationStack {
ZStack {
yard.ignoresSafeArea()
VStack(spacing: 20) {
Image(systemName: "wifi")
.font(.system(size: 40))
.foregroundStyle(brick)
.padding(.top, 20)

Text(t("Online Game", "Игра по сети"))
.font(.title2.bold())
.foregroundStyle(chalk)

Text(statusText)
.font(.subheadline)
.foregroundStyle(chalk.opacity(0.7))
.multilineTextAlignment(.center)
.padding(.horizontal, 24)

if multiplayer.role == .none {
VStack(spacing: 14) {
Button {
myRole = .white
multiplayer.startHosting()
} label: {
lobbyButtonLabel(t("Create Game", "Создать игру"), system: "antenna.radiowaves.left.and.right")
}
Button {
myRole = .black
multiplayer.startBrowsing()
} label: {
lobbyButtonLabel(t("Find Nearby Game", "Найти игру рядом"), system: "magnifyingglass")
}
}
.padding(.horizontal, 32)
}

if multiplayer.role == .guest {
List(multiplayer.availablePeers, id: \.self) { peer in
Button {
multiplayer.invite(peer)
} label: {
HStack {
Image(systemName: "iphone")
Text(peer.displayName)
Spacer()
Text(t("Invite", "Пригласить")).font(.caption)
}
}
}
.listStyle(.plain)
.frame(maxHeight: 240)
.scrollContentBackground(.hidden)
}

if multiplayer.role != .none {
Button(t("Cancel", "Отмена")) {
multiplayer.stop()
}
.font(.footnote)
.foregroundStyle(chalk.opacity(0.6))
}

if let err = multiplayer.errorMessage {
Text(err).font(.caption).foregroundStyle(.red)
}

Spacer()
}
.padding(.bottom, 24)
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
GameView(store: store, multiplayer: multiplayer, localRole: myRole)
}
.onChange(of: multiplayer.state) { state in
if case .connected = state {
startGame = true
}
}
}
.preferredColorScheme(.dark)
}

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

private var statusText: String {
switch multiplayer.state {
case .idle:
return t("Create a game so a nearby opponent can find you, or find a game that's already been created. Wi-Fi or Bluetooth required.", "Создайте игру, чтобы вас нашёл соперник рядом, либо найдите уже созданную игру. Нужны Wi-Fi или Bluetooth.")
case .hosting:
return t("Waiting for opponent… The other player should open this game and tap \"Find Nearby Game\".", "Ожидание соперника… Другой игрок должен открыть эту игру и нажать «Найти игру рядом».")
case .browsing:
return multiplayer.availablePeers.isEmpty ? t("Searching for nearby games…", "Поиск игр рядом…") : t("Choose a game from the list.", "Выберите игру из списка.")
case .connecting:
return t("Connecting…", "Подключение…")
case .connected(let name):
return t("Connected to \(name). Starting game…", "Подключено к \(name). Начинаем игру…")
}
}
}
