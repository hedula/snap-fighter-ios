import SwiftUI

enum RPGTheme {
    static let midnight = Color(red: 0.025, green: 0.055, blue: 0.12)
    static let panel = Color(red: 0.055, green: 0.09, blue: 0.17)
    static let panelRaised = Color(red: 0.085, green: 0.125, blue: 0.22)
    static let parchment = Color(red: 0.93, green: 0.88, blue: 0.72)
    static let gold = Color(red: 0.92, green: 0.72, blue: 0.30)
    static let goldDark = Color(red: 0.50, green: 0.32, blue: 0.08)
    static let ink = Color(red: 0.12, green: 0.09, blue: 0.07)
    static let mist = Color.white.opacity(0.72)
}

struct CardView: View {
    enum Layout {
        case standard
        case compact
    }

    let monster: Monster
    var layout: Layout = .standard

    var body: some View {
        VStack(spacing: 0) {
            cardHeader
            artwork
            cardDetails
        }
        .background(RPGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(RPGTheme.goldDark, lineWidth: layout == .standard ? 7 : 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius - 4, style: .continuous)
                .stroke(RPGTheme.gold.opacity(0.9), lineWidth: 1)
                .padding(4)
        }
        .shadow(color: .black.opacity(0.42), radius: layout == .standard ? 12 : 7, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(monster.name)，\(monster.element.rawValue)屬性，等級 \(monster.level)")
    }

    private var cardHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: monster.element.symbolName)
                .font(layout == .standard ? .headline : .caption)
                .foregroundStyle(monster.element.tintColor)

            Text(monster.name)
                .font(layout == .standard ? .title3.weight(.black) : .caption.weight(.black))
                .foregroundStyle(RPGTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 4)

            Text("Lv.\(monster.level)")
                .font(layout == .standard ? .caption.weight(.black) : .caption2.weight(.black))
                .foregroundStyle(RPGTheme.ink.opacity(0.8))
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: layout == .standard ? 44 : 30)
        .background(RPGTheme.parchment)
    }

    @ViewBuilder
    private var artwork: some View {
        Group {
            if let cardArtwork = monster.displayArtwork {
                Image(uiImage: cardArtwork)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(monster.element.fallbackArtworkName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: imageHeight)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            Text("\(monster.element.rawValue) ATTRIBUTE")
                .font(.system(size: layout == .standard ? 10 : 7, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white)
                .padding(.horizontal, layout == .standard ? 10 : 7)
                .padding(.vertical, layout == .standard ? 6 : 4)
                .background(monster.element.tintColor.opacity(0.92))
                .padding(layout == .standard ? 10 : 6)
        }
        .overlay {
            Rectangle()
                .stroke(RPGTheme.goldDark.opacity(0.8), lineWidth: 2)
        }
    }

    private var cardDetails: some View {
        VStack(alignment: .leading, spacing: layout == .standard ? 10 : 6) {
            HStack(spacing: layout == .standard ? 12 : 5) {
                compactStat("HP", value: monster.hp)
                compactStat("ATK", value: monster.atk)
                compactStat("DEF", value: monster.def)
            }

            if layout == .standard {
                Divider().overlay(RPGTheme.gold.opacity(0.35))
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(RPGTheme.gold)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(monster.skill)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text(skillDescription)
                            .font(.caption)
                            .foregroundStyle(RPGTheme.mist)
                            .lineLimit(2)
                    }
                }

                ProgressView(value: Double(monster.experience), total: Double(monster.experienceNeededForNextLevel))
                    .tint(RPGTheme.gold)
                    .accessibilityLabel("經驗值 \(monster.experienceProgressText)")
            } else {
                Text(monster.skill)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(RPGTheme.parchment)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(horizontalPadding)
    }

    private func compactStat(_ label: String, value: Int) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: layout == .standard ? 9 : 7, weight: .black, design: .rounded))
                .foregroundStyle(RPGTheme.mist)
            Text("\(value)")
                .font(.system(size: layout == .standard ? 15 : 10, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private var skillDescription: String {
        switch monster.skillType {
        case .powerStrike: return "以高威力招式突破敵人的防線。"
        case .fortify: return "強化防禦並恢復部分生命。"
        case .siphonStrike: return "造成傷害後吸收生命能量。"
        }
    }

    private var imageHeight: CGFloat {
        layout == .standard ? 238 : 112
    }

    private var horizontalPadding: CGFloat {
        layout == .standard ? 16 : 9
    }

    private var cornerRadius: CGFloat {
        layout == .standard ? 22 : 14
    }
}

extension Element {
    var tintColor: Color {
        switch self {
        case .fire: return Color(red: 0.92, green: 0.22, blue: 0.12)
        case .water: return Color(red: 0.12, green: 0.55, blue: 0.88)
        case .grass: return Color(red: 0.20, green: 0.67, blue: 0.32)
        case .electric: return Color(red: 0.96, green: 0.73, blue: 0.12)
        case .dark: return Color(red: 0.50, green: 0.25, blue: 0.72)
        case .normal: return Color(red: 0.47, green: 0.51, blue: 0.58)
        }
    }

    var symbolName: String {
        switch self {
        case .fire: return "flame.fill"
        case .water: return "drop.fill"
        case .grass: return "leaf.fill"
        case .electric: return "bolt.fill"
        case .dark: return "moon.stars.fill"
        case .normal: return "circle.hexagongrid.fill"
        }
    }

    var fallbackArtworkName: String {
        switch self {
        case .fire: return "FlameLampKnight"
        case .water, .grass: return "TideBottleGuardian"
        case .electric, .dark: return "ThunderBellKnight"
        case .normal: return "FlameLampKnight"
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
