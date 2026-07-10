import SwiftUI

struct BattleView: View {
    @State private var battle: BattleSession
    @StateObject private var sceneLocation = BattleSceneLocationController()
    let onBattleEnd: (Monster) -> Void

    @State private var isResolvingTurn = false
    @State private var hasReportedBattleEnd = false
    @State private var m1Shake = false
    @State private var m2Shake = false
    @State private var m1DamageText: String? = nil
    @State private var m2DamageText: String? = nil
    @State private var m1DamageOpacity: Double = 0
    @State private var m2DamageOpacity: Double = 0

    init(player1: Monster, player2: Monster, reservePlayer: Monster? = nil, onBattleEnd: @escaping (Monster) -> Void) {
        let session = BattleSession(player: player1, opponent: player2, reservePlayer: reservePlayer)
        _battle = State(initialValue: session)
        self.onBattleEnd = onBattleEnd
    }

    var body: some View {
        ZStack {
            BattleArenaBackdropView(
                coordinate: sceneLocation.coordinate,
                lookAroundSnapshot: sceneLocation.lookAroundSnapshot,
                isUsingLiveArena: sceneLocation.isUsingLiveArena
            )

            ScrollView {
                VStack(spacing: 16) {
                    battleHeader
                    arenaControlPanel
                    combatantPanel(
                        title: "敵方前線",
                        monster: battle.opponent,
                        isPlayerSide: false,
                        isActiveTurn: battle.presentationTone == .opponent,
                        statusTags: battle.opponentStatusTags,
                        damageText: m2DamageText,
                        damageOpacity: m2DamageOpacity
                    )
                    .offset(x: m2Shake ? 8 : 0)

                    eventBanner

                    combatantPanel(
                        title: "我方前線",
                        monster: battle.player,
                        isPlayerSide: true,
                        isActiveTurn: battle.presentationTone == .player,
                        statusTags: battle.playerStatusTags,
                        damageText: m1DamageText,
                        damageOpacity: m1DamageOpacity
                    )
                    .offset(x: m1Shake ? -8 : 0)

                    reservePanel
                    actionPanel
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
    }

    private var arenaControlPanel: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("BATTLEFIELD LINK")
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundStyle(.white.opacity(0.55))
                Text(sceneLocation.arenaTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(sceneLocation.arenaSubtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button {
                sceneLocation.toggleLiveArena()
            } label: {
                HStack(spacing: 8) {
                    if sceneLocation.isLoadingLocation {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: sceneLocation.isUsingLiveArena ? "location.slash.fill" : "location.fill")
                    }

                    Text(sceneLocation.actionTitle)
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(sceneLocation.isUsingLiveArena ? .white.opacity(0.12) : .orange.opacity(0.42))
                .clipShape(Capsule())
            }
            .disabled(sceneLocation.isLoadingLocation)
        }
        .padding(16)
        .background(.black.opacity(0.22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var battleHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SNAP FIGHT")
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundStyle(.white.opacity(0.75))
                Text(battle.headerTitle)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                statusCapsule(label: battle.turnLabel, tint: turnTint, emphasis: true)

                HStack(spacing: 8) {
                    ForEach(battle.headerTags, id: \.self) { tag in
                        statusCapsule(label: tag, tint: .white.opacity(0.18))
                    }
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var eventBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("本回合事件", systemImage: "text.bubble.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if isResolvingTurn {
                    ProgressView()
                        .tint(.white)
                }
            }

            Text(battle.latestEvent.title)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            if let detail = battle.latestEvent.detail, !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(red: 0.19, green: 0.10, blue: 0.09).opacity(0.88))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.orange.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var reservePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("待命副將")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if battle.reservePlayer != nil {
                    statusCapsule(label: battle.reservePlayerStatusHint, tint: .green.opacity(0.28))
                } else {
                    statusCapsule(label: "不可換人", tint: .white.opacity(0.14))
                }
            }

            if let reserve = battle.reservePlayer {
                HStack(spacing: 12) {
                    artworkThumbnail(for: reserve)
                        .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(reserve.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        HStack(spacing: 8) {
                            statusCapsule(label: reserve.element.rawValue, tint: Color(hex: reserve.element.gradientColors[0]).opacity(0.35))
                            statusCapsule(label: "Lv. \(reserve.level)", tint: .white.opacity(0.14))
                        }
                        Text("\(battle.reservePlayerStatusHint ?? "待命支援")，換人會消耗本回合。")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("目前沒有副將")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.82))
                    Text("這一戰無法使用換副將，請以當前前線角色完成戰鬥。")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本回合指令")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(actionPanelHint)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            let columns = [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]

            LazyVGrid(columns: columns, spacing: 12) {
                actionButton(.attack, tint: .orange)
                actionButton(.skill, tint: .pink)
                actionButton(.defend, tint: .blue)
                actionButton(.swap, tint: .green)
            }

            if let unavailableReason = battle.actionPresentation(for: .swap).disabledReason ?? resolvingUnavailableReason {
                Text(unavailableReason)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(.white.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .opacity(battle.isFinished ? 0.72 : 1)
    }

    @ViewBuilder
    private func combatantPanel(
        title: String,
        monster: Monster,
        isPlayerSide: Bool,
        isActiveTurn: Bool,
        statusTags: [String],
        damageText: String?,
        damageOpacity: Double
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .top, spacing: 14) {
                artworkThumbnail(for: monster)
                    .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title.uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white.opacity(0.55))
                            Text(monster.name)
                                .font(.title3)
                                .bold()
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Text(monster.skill)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            statusCapsule(label: monster.element.rawValue, tint: elementTint(for: monster))
                            statusCapsule(label: "Lv. \(monster.level)", tint: .white.opacity(0.14))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("HP")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white.opacity(0.72))
                            Spacer()
                            Text("\(monster.currentHp) / \(monster.hp)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }

                        ProgressView(value: Double(monster.currentHp), total: Double(max(monster.hp, 1)))
                            .tint(isPlayerSide ? .orange : .mint)
                            .scaleEffect(x: 1, y: 1.4, anchor: .center)
                    }

                    HStack(spacing: 10) {
                        statPill(label: "ATK", value: monster.atk)
                        statPill(label: "DEF", value: monster.def)
                    }

                    if !statusTags.isEmpty {
                        statusTagWrap(tags: statusTags)
                    }
                }
            }
            .padding(16)
            .background(combatantBackground(isPlayerSide: isPlayerSide))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isActiveTurn ? turnTint.opacity(0.7) : .white.opacity(0.1), lineWidth: isActiveTurn ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))

            if let damageText {
                Text(damageText)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.red)
                    .opacity(damageOpacity)
                    .padding(.top, -14)
                    .padding(.trailing, 10)
            }
        }
    }

    private func artworkThumbnail(for monster: Monster) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: monster.element.gradientColors.map { Color(hex: $0).opacity(0.85) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let artwork = monster.displayArtwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func statusTagWrap(tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    statusCapsule(label: tag, tint: .white.opacity(0.14))
                }
            }
        }
    }

    private func statPill(label: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.7))
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.1))
        .clipShape(Capsule())
    }

    private func statusCapsule(label: String?, tint: Color, emphasis: Bool = false) -> some View {
        Group {
            if let label, !label.isEmpty {
                Text(label)
                    .font(emphasis ? .subheadline : .caption)
                    .fontWeight(emphasis ? .bold : .semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, emphasis ? 12 : 10)
                    .padding(.vertical, emphasis ? 8 : 6)
                    .background(tint)
                    .clipShape(Capsule())
            }
        }
    }

    private func actionButton(_ action: BattleAction, tint: Color) -> some View {
        let presentation = battle.actionPresentation(for: action)
        return Button {
            Task { await handlePlayerAction(action) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label(action.title, systemImage: action.systemImage)
                    .font(.headline)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(action.subtitle)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(!presentation.isEnabled || isResolvingTurn)
        .opacity((!presentation.isEnabled || battle.isFinished) ? 0.7 : 1)
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
        guard result.damage > 0, let target = result.target else { return }
        await showDamage(amount: result.damage, target: target == .player ? .m1 : .m2)
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

    private var turnTint: Color {
        switch battle.presentationTone {
        case .player:
            return .orange.opacity(0.82)
        case .opponent:
            return .blue.opacity(0.76)
        case .finished:
            return .white.opacity(0.3)
        }
    }

    private var actionPanelHint: String {
        if isResolvingTurn {
            return "正在結算本回合"
        }

        return battle.actionPanelHint
    }

    private var resolvingUnavailableReason: String? {
        isResolvingTurn ? "本回合正在結算中。" : nil
    }

    private func elementTint(for monster: Monster) -> Color {
        Color(hex: monster.element.gradientColors[0]).opacity(0.38)
    }

    private func combatantBackground(isPlayerSide: Bool) -> some ShapeStyle {
        LinearGradient(
            colors: isPlayerSide
                ? [
                    Color(red: 0.36, green: 0.21, blue: 0.14).opacity(0.95),
                    Color(red: 0.20, green: 0.12, blue: 0.12).opacity(0.92)
                ]
                : [
                    Color(red: 0.10, green: 0.18, blue: 0.24).opacity(0.96),
                    Color(red: 0.11, green: 0.11, blue: 0.16).opacity(0.92)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
