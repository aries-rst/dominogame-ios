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
