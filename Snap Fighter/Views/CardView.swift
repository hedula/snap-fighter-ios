import SwiftUI

struct CardView: View {
    let monster: Monster

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: monster.element.gradientColors.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(radius: 8)

            VStack(alignment: .leading, spacing: 10) {
                if let capturedImage = monster.capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 170)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                }

                Text(monster.name)
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)

                Text(monster.element.rawValue)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))

                Divider().background(Color.white.opacity(0.4))

                statRow(label: "HP", value: monster.currentHp, max: 100)
                statRow(label: "ATK", value: monster.atk, max: 100)
                statRow(label: "DEF", value: monster.def, max: 100)

                Spacer()

                Text("⚡ \(monster.skill)")
                    .font(.callout)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func statRow(label: String, value: Int, max: Int) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .bold()
                .foregroundColor(.white)
                .frame(width: 30, alignment: .leading)
            ProgressView(value: Double(value), total: Double(max))
                .tint(.white)
            Text("\(value)")
                .font(.caption)
                .foregroundColor(.white)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

extension Color {
    init(hex: String) {
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
