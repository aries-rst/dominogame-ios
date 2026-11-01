import SwiftUI

struct DealPayload: Codable {
var white: [DominoTile]
var black: [DominoTile]
var boneyard: [DominoTile]
var board: [DominoTile]
var turn: DominoPlayer
}

struct NetMessage: Codable {
var tile: DominoTile? = nil
var side: DominoSide? = nil
var deal: DealPayload? = nil
}

struct GameView: View {
@ObservedObject var store: StoreManager
@ObservedObject private var lang = AppLang.shared
@StateObject private var engine = DominoEngine()
@Environment(\.dismiss) private var dismiss

var multiplayer: MultiplayerManager? = nil
var localRole: DominoPlayer = .white

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
.onAppear {
setupMultiplayerReceiver()
botTurnIfNeeded()
}
.alert(
t("Game Over", "Игра окончена"),
isPresented: Binding(get: { engine.winner != nil || engine.isDraw }, set: { _ in })
) {
Button(t("New Game", "Новая игра")) { resetGame() }
Button(t("Menu", "В меню")) { dismiss() }
} message: {
Text(engine.statusMessage.isEmpty
? (engine.winner == .white ? t("You won!", "Вы победили!") : t("The bot won!", "Бот победил!"))
: engine.statusMessage)
}
}

private var header: some View {
HStack {
Text(t("Bot: \(engine.hands[.black]?.count ?? 0)", "Бот: \(engine.hands[.black]?.count ?? 0)"))
.foregroundStyle(chalk)
Spacer()
Text(t("Boneyard: \(engine.boneyard.count)", "Базар: \(engine.boneyard.count)"))
.font(.caption)
.foregroundStyle(olive)
Spacer()
Text(headerTurnText)
.font(.headline)
.foregroundStyle(brick)
}
.font(.subheadline)
.padding(.horizontal, 16)
}

private var headerTurnText: String {
if multiplayer != nil {
return engine.turn == localRole ? t("Your turn", "Ваш ход") : t("Opponent's turn", "Ход соперника")
}
return engine.turn == .white ? t("Your turn", "Ваш ход") : t("Bot's turn", "Ход бота")
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
.onTapGesture { handleTapEnd(side) }
}

private var handView: some View {
VStack(spacing: 6) {
Text(t("Your Tiles", "Ваши кости"))
.font(.caption)
.foregroundStyle(chalk.opacity(0.7))
ScrollView(.horizontal, showsIndicators: false) {
HStack(spacing: 6) {
ForEach(engine.hands[.white] ?? []) { tile in
tileView(tile, highlight: engine.selectedTile == tile)
.opacity(engine.legalSides(for: tile).isEmpty ? 0.4 : 1)
.onTapGesture { handleTapHandTile(tile) }
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
if multiplayer == nil || localRole == .white {
Button {
resetGame()
} label: {
Label(t("New Game", "Новая игра"), systemImage: "arrow.counterclockwise")
}
}
Spacer()
if let mp = multiplayer {
Text(multiplayerStatusText(mp))
.font(.caption)
.foregroundStyle(chalk.opacity(0.6))
} else if !store.isPremium {
Text(t("Ads in free version", "Реклама в бесплатной версии"))
.font(.caption)
.foregroundStyle(chalk.opacity(0.5))
}
}
.foregroundStyle(chalk)
.padding(.horizontal, 18)
.padding(.bottom, 8)
}

private func multiplayerStatusText(_ mp: MultiplayerManager) -> String {
if case .connected(let name) = mp.state {
return t("Connected: \(name)", "Подключено: \(name)")
}
return t("Connection lost", "Соединение прервано")
}

private func handleTapHandTile(_ tile: DominoTile) {
if multiplayer != nil {
guard engine.turn == localRole, engine.winner == nil else { return }
let sides = engine.legalSides(for: tile)
guard !sides.isEmpty else { return }
if sides.count == 1 {
localPlay(tile: tile, side: sides[0])
} else {
engine.selectedTile = (engine.selectedTile == tile) ? nil : tile
}
} else {
engine.tapHandTile(tile)
}
}

private func handleTapEnd(_ side: DominoSide) {
if multiplayer != nil {
guard let tile = engine.selectedTile, engine.turn == localRole, engine.winner == nil else { return }
if engine.legalSides(for: tile).contains(side) {
localPlay(tile: tile, side: side)
}
} else {
engine.tapEnd(side)
}
}

private func localPlay(tile: DominoTile, side: DominoSide) {
engine.play(tile: tile, side: side, player: localRole)
multiplayer?.send(NetMessage(tile: tile, side: side))
}

private func botTurnIfNeeded() {
guard multiplayer == nil else { return }
guard engine.turn == .black, engine.winner == nil, !engine.isDraw else { return }
DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
engine.playBotTurnIfNeeded()
}
}

private func resetGame() {
if multiplayer != nil {
guard localRole == .white else { return }
engine.reset()
sendCurrentDeal()
} else {
engine.reset()
}
}

private func sendCurrentDeal() {
let deal = DealPayload(
white: engine.hands[.white] ?? [],
black: engine.hands[.black] ?? [],
boneyard: engine.boneyard,
board: engine.board,
turn: engine.turn
)
multiplayer?.send(NetMessage(deal: deal))
}

private func setupMultiplayerReceiver() {
guard let mp = multiplayer else { return }
if localRole == .white {
// Host already dealt the real game in engine's init(); broadcast it
// so the guest mirrors the exact same hands/board/boneyard.
sendCurrentDeal()
}
mp.onReceive = { data in
guard let msg = try? JSONDecoder().decode(NetMessage.self, from: data) else { return }
DispatchQueue.main.async {
if let deal = msg.deal {
engine.applyDeal(white: deal.white, black: deal.black, boneyard: deal.boneyard, board: deal.board, turn: deal.turn)
} else if let tile = msg.tile, let side = msg.side {
engine.play(tile: tile, side: side, player: engine.turn)
}
}
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
@ObservedObject private var lang = AppLang.shared
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
featureRow(t("No ads", "Без рекламы"))
featureRow(t("Local multiplayer over Wi-Fi/Bluetooth", "Локальный мультиплеер по Wi-Fi/Bluetooth"))
featureRow(t("One-time purchase — forever", "Разовая покупка — навсегда"))
}
.padding(.horizontal, 24)

if store.isPremium {
Label(t("Premium Already Active", "Premium уже активен"), systemImage: "checkmark.seal.fill")
.foregroundStyle(.green)
} else {
Button {
Task { await store.purchasePremium() }
} label: {
Text(t("Buy for \(store.priceText)", "Купить за \(store.priceText)"))
.fontWeight(.bold)
.frame(maxWidth: .infinity)
.padding()
.background(brick)
.foregroundStyle(.white)
.clipShape(RoundedRectangle(cornerRadius: 14))
}
.padding(.horizontal, 24)

Button(t("Restore Purchases", "Восстановить покупки")) {
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
Button(t("Close", "Закрыть")) { dismiss() }
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
