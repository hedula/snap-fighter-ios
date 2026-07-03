import SwiftUI

struct BattleView: View {
    @State private var battle: BattleSession
    let onBattleEnd: (Monster) -> Void

    @State private var isResolvingTurn = false
    @State private var hasReportedBattleEnd = false
    @State private var m1Shake = false
    @State private var m2Shake = false
    @State private var m1DamageText: String? = nil
    @State private var m2DamageText: String? = nil
    @State private var m1DamageOpacity: Double = 0
    @State private var m2DamageOpacity: Double = 0
    @State private var battleStatusText: String

    init(player1: Monster, player2: Monster, reservePlayer: Monster? = nil, onBattleEnd: @escaping (Monster) -> Void) {
        let session = BattleSession(player: player1, opponent: player2, reservePlayer: reservePlayer)
        _battle = State(initialValue: session)
        _battleStatusText = State(initialValue: session.statusText)
        self.onBattleEnd = onBattleEnd
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("⚔️ 對戰！")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)

                GeometryReader { proxy in
                    let sidePadding: CGFloat = 24
                    let spacing: CGFloat = 12
                    let vsWidth: CGFloat = 28
                    let cardWidth = max(140, (proxy.size.width - sidePadding * 2 - spacing * 2 - vsWidth) / 2)

                    HStack(alignment: .top, spacing: spacing) {
                        monsterColumn(monster: battle.player, damageText: m1DamageText, damageOpacity: m1DamageOpacity)
                            .frame(width: cardWidth)
                            .offset(x: m1Shake ? -8 : 0)

                        Text("VS")
                            .font(.title3)
                            .bold()
                            .foregroundColor(.secondary)
                            .frame(width: vsWidth)
                            .padding(.top, 70)

                        monsterColumn(monster: battle.opponent, damageText: m2DamageText, damageOpacity: m2DamageOpacity)
                            .frame(width: cardWidth)
                            .offset(x: m2Shake ? 8 : 0)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 360)

                if let reserve = battle.reservePlayer {
                    VStack(spacing: 10) {
                        Text("副將待命")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        CardView(monster: reserve, layout: .compact)
                            .frame(maxWidth: 190)
                    }
                }

                if isResolvingTurn {
                    ProgressView("戰鬥處理中…")
                        .font(.headline)
                        .padding(.bottom)
                }

                Text(battleStatusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                actionPanel
                    .padding(.horizontal, 20)
                    .disabled(!battle.canPlayerAct || isResolvingTurn)
                    .opacity(battle.canPlayerAct && !isResolvingTurn ? 1 : 0.65)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private func monsterColumn(monster: Monster, damageText: String?, damageOpacity: Double) -> some View {
        ZStack(alignment: .top) {
            CardView(monster: monster, layout: .compact)
                .frame(maxWidth: .infinity)

            if let text = damageText {
                Text(text)
                    .font(.title)
                    .bold()
                    .foregroundColor(.red)
                    .opacity(damageOpacity)
                    .offset(y: -20)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var actionPanel: some View {
        VStack(spacing: 12) {
            Text(battle.turn == .player ? "輪到你了" : "等待下一回合")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            let columns = [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]

            LazyVGrid(columns: columns, spacing: 12) {
                actionButton(.attack, tint: .orange)
                actionButton(.skill, tint: .pink)
                actionButton(.defend, tint: .blue)
                actionButton(.swap, tint: .green, disabled: !battle.canSwap)
            }
        }
    }

    private func actionButton(_ action: BattleAction, tint: Color, disabled: Bool = false) -> some View {
        Button {
            Task { await handlePlayerAction(action) }
        } label: {
            Label(action.title, systemImage: action.systemImage)
                .font(.headline)
                .bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(disabled || !battle.canPlayerAct || isResolvingTurn)
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
        battleStatusText = "\(result.message)\n\(battle.statusText)"

        guard result.damage > 0, let target = result.target else { return }
        await showDamage(amount: result.damage, target: target == .player ? .m1 : .m2)
    }

    private func finishBattleIfNeeded() async -> Bool {
        guard battle.isFinished, !hasReportedBattleEnd, let winner = battle.winner else { return false }

        hasReportedBattleEnd = true
        battleStatusText = battle.statusText
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
}
