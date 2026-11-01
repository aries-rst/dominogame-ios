import SwiftUI

/// Real settings screen, pushed from the root screen's "Settings" button.
/// Hosts language, Premium status/purchase, the ad/unlock status footer
/// line (moved off the root screen to keep it clean, matching the Android
/// home screen), and a convenience Reset Stats control.
struct SettingsView: View {
    @ObservedObject var store: StoreManager
    @ObservedObject private var lang = AppLang.shared
    @State private var showPremium = false
    @State private var statsResetConfirmed = false

    private let yard = Color(red: 0.17, green: 0.22, blue: 0.16)
    private let chalk = Color(red: 0.95, green: 0.94, blue: 0.88)
    private let brick = Color(red: 0.70, green: 0.27, blue: 0.20)
    private let olive = Color(red: 0.34, green: 0.40, blue: 0.26)
    private let gold = Color(red: 0.85, green: 0.68, blue: 0.22)

    var body: some View {
        ZStack {
            yard.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    languageRow
                    premiumRow
                    statusFooter
                    resetStatsRow
                }
                .padding(20)
            }
        }
        .navigationTitle(t("Settings", "Настройки"))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPremium) {
            PremiumView(store: store)
        }
    }

    private var languageRow: some View {
        settingsCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Language", "Язык"))
                        .font(.subheadline.bold())
                        .foregroundStyle(chalk)
                    Text(lang.isRussian ? t("Russian", "Русский") : t("English", "Английский"))
                        .font(.caption)
                        .foregroundStyle(chalk.opacity(0.7))
                }
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
    }

    private var premiumRow: some View {
        settingsCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: store.isPremium ? "crown.fill" : "crown")
                            .foregroundStyle(gold)
                        Text(store.isPremium ? t("Premium Active", "Premium активен") : t("Premium", "Premium"))
                            .font(.subheadline.bold())
                            .foregroundStyle(chalk)
                    }
                    if !store.isPremium {
                        Text(t("Removes ads · unlocks local multiplayer", "Убирает рекламу · открывает локальный мультиплеер"))
                            .font(.caption)
                            .foregroundStyle(chalk.opacity(0.7))
                    }
                }
                Spacer()
                if store.isPremium {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(gold)
                        .font(.system(size: 20))
                } else {
                    Button {
                        showPremium = true
                    } label: {
                        Text(store.priceText)
                            .fontWeight(.semibold)
                            .foregroundStyle(yard)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(gold))
                    }
                }
            }
        }
    }

    private var statusFooter: some View {
        Text(store.isPremium
             ? t("Ads disabled · Local multiplayer unlocked", "Реклама отключена · Локальный мультиплеер открыт")
             : t("Free version · with ads", "Бесплатная версия · с рекламой"))
            .font(.footnote)
            .foregroundStyle(chalk.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    private var resetStatsRow: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(t("Statistics", "Статистика"))
                    .font(.subheadline.bold())
                    .foregroundStyle(chalk)
                Button {
                    GameStats.reset()
                    statsResetConfirmed = true
                } label: {
                    Text(statsResetConfirmed ? t("Stats Reset", "Статистика сброшена") : t("Reset Stats", "Сбросить статистику"))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(brick)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(olive.opacity(0.2))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(brick.opacity(0.6), lineWidth: 1))
                        )
                }
            }
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(olive.opacity(0.3))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(chalk.opacity(0.12), lineWidth: 1))
            )
    }
}

#Preview {
    NavigationStack { SettingsView(store: StoreManager()) }
}
