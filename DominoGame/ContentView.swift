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
