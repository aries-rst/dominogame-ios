import SwiftUI

struct ContentView: View {
    @StateObject private var store = StoreManager()
    @ObservedObject private var lang = AppLang.shared
    @State private var showSetup = false
    @State private var showLocalGame = false
    @State private var options = GameOptions.load()
    @State private var showPremium = false
    @State private var showLobby = false

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
                        .padding(.trailing, 20)
                    }

                    VStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(brick)
                        Text("DOMINO YARD")
                            .font(.system(size: 28, weight: .heavy, design: .serif))
                            .foregroundStyle(chalk)
                            .tracking(3)
                        Text(t("Classic Dominoes", "Классическое домино"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(olive)
                    }

                    VStack(spacing: 14) {
                        Button {
                            showSetup = true
                        } label: {
                            menuLabel(t("Play vs Bot", "Играть с ботом"), system: "person.2.fill")
                        }

                        Button {
                            if store.isPremium {
                                showLobby = true
                            } else {
                                showPremium = true
                            }
                        } label: {
                            menuLabel(t("Play Online (Wi-Fi/Bluetooth)", "Игра по сети (Wi-Fi/Bluetooth)"), system: "wifi")
                        }

                        Button {
                            showPremium = true
                        } label: {
                            menuLabel(store.isPremium ? t("Premium Active", "Premium активен") : "Premium — \(store.priceText)", system: store.isPremium ? "crown.fill" : "crown")
                        }
                    }
                    .padding(.horizontal, 32)

                    CrossPromoSection(accent: brick, textColor: chalk, cardFill: olive.opacity(0.35))

                    Spacer()

                    Text(store.isPremium ? t("Ads disabled · Local multiplayer unlocked", "Реклама отключена · Локальный мультиплеер открыт") : t("Free version · with ads", "Бесплатная версия · с рекламой"))
                        .font(.footnote)
                        .foregroundStyle(chalk.opacity(0.6))
                        .padding(.bottom, 24)
                }
            }
            .navigationDestination(isPresented: $showLocalGame) {
                LocalGameView(store: store, options: options)
            }
            .navigationDestination(isPresented: $showLobby) {
                MultiplayerLobbyView(store: store)
            }
            .sheet(isPresented: $showPremium) {
                PremiumView(store: store)
            }
            .sheet(isPresented: $showSetup) {
                GameSetupView(options: $options) {
                    showSetup = false
                    showLocalGame = true
                }
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
