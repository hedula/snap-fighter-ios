import SwiftUI

struct CardView: View {
    enum Layout {
        case standard
        case compact
    }

    let monster: Monster
    var layout: Layout = .standard

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
                if let cardArtwork = monster.displayArtwork {
                    Image(uiImage: cardArtwork)
                        .resizable()
                        .scaledToFill()
                        .frame(height: imageHeight)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                }

                Text(monster.name)
                    .font(titleFont)
                    .bold()
                    .foregroundColor(.white)
                    .lineLimit(layout == .compact ? 1 : 2)
                    .minimumScaleFactor(0.75)

                HStack {
                    Text(monster.element.rawValue)
                        .font(elementFont)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("Lv. \(monster.level)")
                        .font(levelFont)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.16))
                        .clipShape(Capsule())
                }

                Divider().background(Color.white.opacity(0.4))

                statRow(label: "HP", value: monster.currentHp, max: 100)
                statRow(label: "ATK", value: monster.atk, max: 100)
                statRow(label: "DEF", value: monster.def, max: 100)
                statRow(label: "EXP", value: monster.experience, max: monster.experienceNeededForNextLevel)

                Text("⚡ \(monster.skill)")
                    .font(skillFont)
                    .foregroundColor(.white)
                    .lineLimit(layout == .compact ? 4 : nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(contentPadding)
        }
    }

    @ViewBuilder
    private func statRow(label: String, value: Int, max: Int) -> some View {
        HStack {
            Text(label)
                .font(statFont)
                .bold()
                .foregroundColor(.white)
                .frame(width: 30, alignment: .leading)
            ProgressView(value: Double(value), total: Double(max))
                .tint(.white)
            Text("\(value)")
                .font(statFont)
                .foregroundColor(.white)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var imageHeight: CGFloat {
        switch layout {
        case .standard: return 170
        case .compact: return 96
        }
    }

    private var contentPadding: CGFloat {
        switch layout {
        case .standard: return 24
        case .compact: return 16
        }
    }

    private var titleFont: Font {
        switch layout {
        case .standard: return .largeTitle
        case .compact: return .title3
        }
    }

    private var elementFont: Font {
        switch layout {
        case .standard: return .title3
        case .compact: return .subheadline
        }
    }

    private var skillFont: Font {
        switch layout {
        case .standard: return .callout
        case .compact: return .caption
        }
    }

    private var statFont: Font {
        switch layout {
        case .standard: return .caption
        case .compact: return .caption2
        }
    }

    private var levelFont: Font {
        switch layout {
        case .standard: return .subheadline
        case .compact: return .caption
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
