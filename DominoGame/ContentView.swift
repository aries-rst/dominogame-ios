import SwiftUI

struct ContentView: View {
    @StateObject private var store = StoreManager()
    @State private var showGame = false
    @State private var showPremium = false

    private let yard = Color(red: 0.17, green: 0.22, blue: 0.16)
    private let chalk = Color(red: 0.95, green: 0.94, blue: 0.88)
    private let brick = Color(red: 0.70, green: 0.27, blue: 0.20)
    private let olive = Color(red: 0.34, green: 0.40, blue: 0.26)

    var body: some View {
        NavigationStack {
            ZStack {
                yard.ignoresSafeArea()
                VStack(spacing: 28) {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(brick)
                        Text("DOMINO YARD")
                            .font(.system(size: 28, weight: .heavy, design: .serif))
                            .foregroundStyle(chalk)
                            .tracking(3)
                        Text("Классическое домино")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(olive)
                    }

                    VStack(spacing: 14) {
                        Button {
                            showGame = true
                        } label: {
                            menuLabel("Играть с ботом", system: "person.2.fill")
                        }

                        Button {
                            showPremium = true
                        } label: {
                            menuLabel(store.isPremium ? "Premium активен" : "Premium — \(store.priceText)", system: store.isPremium ? "crown.fill" : "crown")
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    Text(store.isPremium ? "Реклама отключена · Локальный мультиплеер открыт" : "Бесплатная версия · с рекламой")
                        .font(.footnote)
                        .foregroundStyle(chalk.opacity(0.6))
                        .padding(.bottom, 24)
                }
            }
            .navigationDestination(isPresented: $showGame) {
                GameView(store: store)
            }
            .sheet(isPresented: $showPremium) {
                PremiumView(store: store)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func menuLabel(_ text: String, system: String) -> some View {
        HStack {
            Image(systemName: system)
            Text(text)
                .fontWeight(.semibold)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
        }
        .foregroundStyle(chalk)
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(olive.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(brick.opacity(0.6), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ContentView()
}
import SwiftUI

// Courtyard poster palette — bold red, mustard, ink on cream paper.
// Distinct from Checkers (dark wood/brass), Nardy (ochre/copper/turquoise)
// and Durak (burgundy/gold).
enum CourtyardPalette {
    static let poster = Color(red: 0.95, green: 0.25, blue: 0.20)
    static let mustard = Color(red: 0.95, green: 0.75, blue: 0.15)
    static let ink = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let paper = Color(red: 0.96, green: 0.93, blue: 0.85)
}

struct ContentView: View {
    var body: some View {
        ZStack {
            CourtyardPalette.paper.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("ДОМИНО ДВОРА")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(CourtyardPalette.poster)
                Text("Домино-лига — счёт серии партий")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CourtyardPalette.ink.opacity(0.8))
                RoundedRectangle(cornerRadius: 12)
                    .fill(CourtyardPalette.ink)
                    .frame(width: 220, height: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(CourtyardPalette.mustard, lineWidth: 4)
                    )
                    .overlay(Text("Board scaffold").foregroundStyle(CourtyardPalette.paper.opacity(0.6)))
            }
        }
    }
}

#Preview {
    ContentView()
}
