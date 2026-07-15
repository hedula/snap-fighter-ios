import SwiftUI

struct BattleView: View {
    @State private var battle: BattleSession
    @StateObject private var sceneLocation = BattleSceneLocationController()
    let onBattleEnd: (Monster) -> Void

    @State private var isResolvingTurn = false
    @State private var hasReportedBattleEnd = false
    @State private var m1Shake = false
    @State private var m2Shake = false
    @State private var m1DamageText: String?
    @State private var m2DamageText: String?
    @State private var m1DamageOpacity: Double = 0
    @State private var m2DamageOpacity: Double = 0
    @State private var activeSkillEffect: BattleSkillEffect?
    @State private var skillEffectScene = SkillEffectScene(size: .zero)

    init(player1: Monster, player2: Monster, reservePlayer: Monster? = nil, onBattleEnd: @escaping (Monster) -> Void) {
        _battle = State(initialValue: BattleSession(player: player1, opponent: player2, reservePlayer: reservePlayer))
        self.onBattleEnd = onBattleEnd
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BattleArenaBackdropView(
                    coordinate: sceneLocation.coordinate,
                    lookAroundSnapshot: sceneLocation.lookAroundSnapshot,
                    isUsingLiveArena: sceneLocation.isUsingLiveArena
                )

                VStack(spacing: 0) {
                    battleHeader
                        .frame(height: 62)

                    arcaneBattlefield
                        .frame(maxHeight: .infinity)

                    eventBanner
                        .padding(.horizontal, 14)
                        .padding(.bottom, 6)

                    commandHand(availableWidth: proxy.size.width)
                        .frame(height: 194)
                }
                .padding(.top, 4)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var battleHeader: some View {
        ZStack {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color.arcaneGold.opacity(0.5))
                    .frame(height: 1)
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundStyle(Color.arcaneGold)
                Rectangle()
                    .fill(Color.arcaneGold.opacity(0.5))
                    .frame(height: 1)
            }
            .padding(.horizontal, 68)

            VStack(spacing: 1) {
                Text(battleTitle)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(Color.parchment)
                    .shadow(color: .black.opacity(0.8), radius: 4, y: 2)
                Text("回合 \(battle.roundNumber)")
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.arcaneGold.opacity(0.9))
            }

            HStack {
                locationControlButton
                Spacer()

                if isResolvingTurn {
                    ProgressView()
                        .tint(Color.arcaneGold)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
        }
    }

    private var locationControlButton: some View {
        Button {
            sceneLocation.toggleLiveArena()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.48))
                Circle()
                    .stroke(Color.arcaneGold.opacity(0.72), lineWidth: 1)

                if sceneLocation.isLoadingLocation {
                    ProgressView()
                        .tint(Color.parchment)
                        .controlSize(.mini)
                } else {
                    Image(systemName: sceneLocation.isUsingLiveArena ? "location.fill" : "map.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.parchment)
                }
            }
            .frame(width: 38, height: 38)
        }
        .disabled(sceneLocation.isLoadingLocation)
        .accessibilityLabel(sceneLocation.actionTitle)
        .accessibilityHint(sceneLocation.arenaSubtitle)
    }

    private var arcaneBattlefield: some View {
        GeometryReader { proxy in
            let enemyWidth = min(170, proxy.size.width * 0.43)
            let playerWidth = min(152, proxy.size.width * 0.39)

            ZStack {
                fighterNameplate(monster: battle.opponent, isPlayerSide: false)
                    .frame(width: min(210, proxy.size.width * 0.55))
                    .position(x: proxy.size.width * 0.29, y: 88)

                battleCard(
                    monster: battle.opponent,
                    isPlayerSide: false,
                    damageText: m2DamageText,
                    damageOpacity: m2DamageOpacity
                )
                .frame(width: enemyWidth, height: enemyWidth * 1.34)
                .rotationEffect(.degrees(4))
                .offset(x: m2Shake ? 8 : 0)
                .position(x: proxy.size.width - enemyWidth * 0.56, y: enemyWidth * 0.71)

                elementRelationshipWheel
                    .position(x: proxy.size.width * 0.53, y: proxy.size.height * 0.54)

                battleCard(
                    monster: battle.player,
                    isPlayerSide: true,
                    damageText: m1DamageText,
                    damageOpacity: m1DamageOpacity
                )
                .frame(width: playerWidth, height: playerWidth * 1.34)
                .rotationEffect(.degrees(-4))
                .offset(x: m1Shake ? -8 : 0)
                .position(x: playerWidth * 0.63, y: proxy.size.height - playerWidth * 0.72)

                reserveBookmark
                    .frame(width: 76, height: 112)
                    .position(x: proxy.size.width - 48, y: proxy.size.height * 0.72)

                SkillEffectSpriteView(scene: skillEffectScene, effect: activeSkillEffect)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .zIndex(5)
            }
        }
    }

    private func battleCard(
        monster: Monster,
        isPlayerSide: Bool,
        damageText: String?,
        damageOpacity: Double
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(monster.name)
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Image(systemName: elementIcon(for: monster.element))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.ink)
                        .frame(width: 24, height: 24)
                        .background(elementColor(for: monster.element))
                        .clipShape(Circle())
                }
                .padding(.horizontal, 10)
                .frame(height: 34)

                artwork(for: monster)
                    .overlay(alignment: .topTrailing) {
                        Text("Lv. \(monster.level)")
                            .font(.system(size: 10, weight: .bold, design: .serif))
                            .foregroundStyle(Color.parchment)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.78))
                            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 7))
                    }
                    .clipped()

                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("HP")
                            .font(.system(size: 10, weight: .semibold, design: .serif))
                        Text("\(monster.currentHp) / \(monster.hp)")
                            .font(.system(size: 16, weight: .bold, design: .serif))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Color.parchment)

                    GeometryReader { hpProxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15))
                            Capsule()
                                .fill(isPlayerSide ? Color.ember : Color.cyanMagic)
                                .frame(width: hpProxy.size.width * hpProgress(for: monster))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.88))
            }
            .background(Color.parchment)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [Color.arcaneGold, .white.opacity(0.8), Color.arcaneGold.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isPlayerSide ? 3 : 2
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.ink.opacity(0.5), lineWidth: 1)
                    .padding(5)
            }
            .shadow(color: elementColor(for: monster.element).opacity(0.45), radius: 12)

            if let damageText {
                Text(damageText)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .red, radius: 5)
                    .opacity(damageOpacity)
                    .offset(x: 8, y: -14)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(monster.name)，\(monster.element.rawValue)屬性，等級 \(monster.level)，生命 \(monster.currentHp) / \(monster.hp)")
    }

    private func artwork(for monster: Monster) -> some View {
        GeometryReader { proxy in
            Image(uiImage: displayArtwork(for: monster))
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }

    private func fighterNameplate(monster: Monster, isPlayerSide: Bool) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: elementIcon(for: monster.element))
                    .font(.caption.bold())
                    .foregroundStyle(Color.parchment)
                    .frame(width: 28, height: 28)
                    .background(elementColor(for: monster.element).opacity(0.7))
                    .clipShape(Circle())
                Text(monster.name)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(Color.parchment)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("Lv. \(monster.level)")
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.parchment.opacity(0.9))
            }

            HStack(spacing: 7) {
                Text("HP")
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundStyle(Color.arcaneGold)
                GeometryReader { hpProxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule()
                            .fill(isPlayerSide ? Color.ember : Color.cyanMagic)
                            .frame(width: hpProxy.size.width * hpProgress(for: monster))
                    }
                }
                .frame(height: 6)
                Text("\(monster.currentHp) / \(monster.hp)")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .foregroundStyle(Color.parchment)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.64))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.arcaneGold.opacity(0.7)).frame(height: 1)
        }
    }

    private var elementRelationshipWheel: some View {
        VStack(spacing: 5) {
            Image(systemName: "bolt.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.arcaneGold)
            HStack(spacing: 10) {
                Image(systemName: "flame.fill").foregroundStyle(Color.ember)
                Image(systemName: "arrow.right").foregroundStyle(Color.arcaneGold.opacity(0.8))
                Image(systemName: "drop.fill").foregroundStyle(Color.cyanMagic)
                Image(systemName: "arrow.right").foregroundStyle(Color.arcaneGold.opacity(0.8))
                Image(systemName: "leaf.fill").foregroundStyle(.green)
            }
            .font(.caption.bold())
        }
        .padding(8)
        .background(Color.black.opacity(0.28), in: Capsule())
        .accessibilityLabel("屬性相剋提示")
    }

    private var reserveBookmark: some View {
        let presentation = battle.actionPresentation(for: .swap)

        return Button {
            Task { await handlePlayerAction(.swap) }
        } label: {
            VStack(spacing: 6) {
                if let reserve = battle.reservePlayer {
                    Image(uiImage: displayArtwork(for: reserve))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.arcaneGold, lineWidth: 1))
                    Text("待命")
                        .font(.system(size: 12, weight: .bold, design: .serif))
                    Text(reserve.name)
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .lineLimit(2)
                } else {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.title2)
                    Text("無副將")
                        .font(.caption.bold())
                }
            }
            .foregroundStyle(Color.parchment)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(6)
            .background(Color(red: 0.12, green: 0.08, blue: 0.18).opacity(0.9))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.arcaneGold.opacity(0.72), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!presentation.isEnabled || isResolvingTurn)
        .opacity(presentation.isEnabled ? 1 : 0.55)
        .accessibilityHint(presentation.disabledReason ?? "切換待命副將，並消耗本回合")
    }

    private var eventBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "compass.drawing")
                .font(.headline)
                .foregroundStyle(Color.ink)

            Text(eventCopy)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(Color.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isResolvingTurn {
                ProgressView()
                    .tint(Color.ink)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Color.parchment.opacity(0.96))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.arcaneGold.opacity(0.78), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(eventCopy)
    }

    private func commandHand(availableWidth: CGFloat) -> some View {
        let cardWidth = min(98, (availableWidth + 4) / 4)

        return HStack(alignment: .bottom, spacing: -8) {
            commandCard(.attack, tint: Color(red: 0.45, green: 0.24, blue: 0.04), angle: -4)
                .frame(width: cardWidth)
            commandCard(.skill, tint: Color(red: 0.48, green: 0.06, blue: 0.08), angle: -1, isPrimary: true)
                .frame(width: cardWidth)
                .offset(y: -7)
                .zIndex(2)
            commandCard(.defend, tint: Color(red: 0.04, green: 0.18, blue: 0.36), angle: 1)
                .frame(width: cardWidth)
            commandCard(.swap, tint: Color(red: 0.04, green: 0.27, blue: 0.14), angle: 4)
                .frame(width: cardWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.58), .black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func commandCard(_ action: BattleAction, tint: Color, angle: Double, isPrimary: Bool = false) -> some View {
        let presentation = battle.actionPresentation(for: action)

        return Button {
            Task { await handlePlayerAction(action) }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 30, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                Text(action.title)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .lineLimit(1)
                Rectangle()
                    .fill(Color.arcaneGold.opacity(0.6))
                    .frame(height: 1)
                Text(shortSubtitle(for: action))
                    .font(.system(size: 10, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(Color.parchment)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
            .background(tint)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isPrimary ? Color.orange : Color.arcaneGold.opacity(0.85), lineWidth: isPrimary ? 3 : 1.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    .padding(4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: isPrimary ? .orange.opacity(0.75) : .black.opacity(0.65), radius: isPrimary ? 10 : 5, y: 3)
        }
        .buttonStyle(.plain)
        .rotationEffect(.degrees(angle), anchor: .bottom)
        .disabled(!presentation.isEnabled || isResolvingTurn)
        .opacity((presentation.isEnabled && !battle.isFinished) ? 1 : 0.48)
        .accessibilityLabel(action.title)
        .accessibilityHint(presentation.disabledReason ?? action.subtitle)
    }

    private func handlePlayerAction(_ action: BattleAction) async {
        guard !isResolvingTurn else { return }
        guard let result = battle.performPlayerAction(action) else { return }

        isResolvingTurn = true
        await present(result)

        if await finishBattleIfNeeded() {
            isResolvingTurn = false
            return
        }

        try? await Task.sleep(nanoseconds: 320_000_000)

        let aiAction = battle.chooseOpponentAction()
        if let aiResult = battle.performOpponentAction(aiAction) {
            await present(aiResult)
        }

        _ = await finishBattleIfNeeded()
        isResolvingTurn = false
    }

    private enum Target { case m1, m2 }

    private func present(_ result: BattleResolvedAction) async {
        if let skillEffect = result.skillEffect {
            await showSkillEffect(skillEffect)
        }

        guard result.damage > 0, let target = result.target else { return }
        await showDamage(amount: result.damage, target: target == .player ? .m1 : .m2)
    }

    private func showSkillEffect(_ effect: BattleSkillEffect) async {
        activeSkillEffect = effect
        try? await Task.sleep(nanoseconds: UInt64(effectDuration(for: effect.tier) * 1_000_000_000))
        activeSkillEffect = nil
    }

    private func finishBattleIfNeeded() async -> Bool {
        guard battle.isFinished, !hasReportedBattleEnd, let winner = battle.winner else { return false }

        hasReportedBattleEnd = true
        battle.markSettlementEvent()
        try? await Task.sleep(nanoseconds: 240_000_000)
        onBattleEnd(winner)
        return true
    }

    private func showDamage(amount: Int, target: Target) async {
        let text = "-\(amount)"
        switch target {
        case .m1:
            m1DamageText = text
            withAnimation(.spring(response: 0.1, dampingFraction: 0.2)) { m1Shake = true }
            withAnimation(.easeIn(duration: 0.6)) { m1DamageOpacity = 1 }
            try? await Task.sleep(nanoseconds: 400_000_000)
            withAnimation { m1Shake = false }
            withAnimation(.easeOut(duration: 0.4)) { m1DamageOpacity = 0 }
            m1DamageText = nil
        case .m2:
            m2DamageText = text
            withAnimation(.spring(response: 0.1, dampingFraction: 0.2)) { m2Shake = true }
            withAnimation(.easeIn(duration: 0.6)) { m2DamageOpacity = 1 }
            try? await Task.sleep(nanoseconds: 400_000_000)
            withAnimation { m2Shake = false }
            withAnimation(.easeOut(duration: 0.4)) { m2DamageOpacity = 0 }
            m2DamageText = nil
        }
    }

    private var battleTitle: String {
        switch battle.presentationTone {
        case .player: return "你的回合"
        case .opponent: return "敵方回合"
        case .finished: return "戰鬥結束"
        }
    }

    private var eventCopy: String {
        if let detail = battle.latestEvent.detail, !detail.isEmpty {
            return "\(battle.latestEvent.title)，\(detail)"
        }
        return battle.latestEvent.title
    }

    private func hpProgress(for monster: Monster) -> CGFloat {
        CGFloat(monster.currentHp) / CGFloat(max(monster.hp, 1))
    }

    private func shortSubtitle(for action: BattleAction) -> String {
        switch action {
        case .attack: return "穩定輸出"
        case .skill: return battle.playerSkillCooldownRemaining > 0 ? "冷卻 \(battle.playerSkillCooldownRemaining)" : battle.player.elementalSkillDisplayText
        case .defend: return "下次減傷"
        case .swap: return "消耗回合"
        }
    }

    private func displayArtwork(for monster: Monster) -> UIImage {
        if let artwork = monster.displayArtwork {
            return artwork
        }

        let assetName: String
        switch monster.element {
        case .fire:
            assetName = "FlameLampKnight"
        case .water, .grass:
            assetName = "TideBottleGuardian"
        case .electric, .dark, .normal:
            assetName = "ThunderBellKnight"
        }

        return UIImage(named: assetName) ?? UIImage()
    }

    private func elementIcon(for element: Element) -> String {
        switch element {
        case .fire: return "flame.fill"
        case .water: return "drop.fill"
        case .grass: return "leaf.fill"
        case .electric: return "bolt.fill"
        case .dark: return "moon.stars.fill"
        case .normal: return "circle.hexagongrid.fill"
        }
    }

    private func elementColor(for element: Element) -> Color {
        Color(hex: element.gradientColors[0])
    }

    private func effectDuration(for tier: ElementalSkillTier) -> Double {
        switch tier {
        case .low: return 0.9
        case .medium: return 1.05
        case .high: return 1.22
        }
    }
}

private extension Color {
    static let arcaneGold = Color(red: 0.82, green: 0.66, blue: 0.33)
    static let parchment = Color(red: 0.94, green: 0.88, blue: 0.72)
    static let ink = Color(red: 0.12, green: 0.09, blue: 0.09)
    static let cyanMagic = Color(red: 0.16, green: 0.82, blue: 0.86)
    static let ember = Color(red: 0.95, green: 0.28, blue: 0.12)
}
