import SwiftUI

struct BattleView: View {
    @State private var m1: Monster
    @State private var m2: Monster
    let onBattleEnd: (Monster) -> Void

    @State private var isBattling = false
    @State private var m1Shake = false
    @State private var m2Shake = false
    @State private var m1DamageText: String? = nil
    @State private var m2DamageText: String? = nil
    @State private var m1DamageOpacity: Double = 0
    @State private var m2DamageOpacity: Double = 0
    @State private var winner: Monster? = nil

    init(player1: Monster, player2: Monster, onBattleEnd: @escaping (Monster) -> Void) {
        _m1 = State(initialValue: player1)
        _m2 = State(initialValue: player2)
        self.onBattleEnd = onBattleEnd
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("⚔️ 對戰！")
                .font(.largeTitle)
                .bold()
                .padding(.top)

            HStack(spacing: 16) {
                monsterColumn(monster: m1, damageText: m1DamageText, damageOpacity: m1DamageOpacity)
                    .offset(x: m1Shake ? -8 : 0)

                Text("VS")
                    .font(.title)
                    .bold()
                    .foregroundColor(.secondary)

                monsterColumn(monster: m2, damageText: m2DamageText, damageOpacity: m2DamageOpacity)
                    .offset(x: m2Shake ? 8 : 0)
            }
            .padding(.horizontal, 8)

            if !isBattling {
                Button {
                    Task { await runBattle() }
                } label: {
                    Text("對戰！")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                .padding(.bottom)
            }
        }
    }

    @ViewBuilder
    private func monsterColumn(monster: Monster, damageText: String?, damageOpacity: Double) -> some View {
        ZStack(alignment: .top) {
            CardView(monster: monster)
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

    private func runBattle() async {
        isBattling = true
        var turn = 0

        while m1.currentHp > 0 && m2.currentHp > 0 && turn < 10 {
            try? await Task.sleep(nanoseconds: 800_000_000)

            if turn % 2 == 0 {
                let dmg = calcDamage(atk: m1.atk, def: m2.def)
                m2.currentHp = max(0, m2.currentHp - dmg)
                await showDamage(amount: dmg, target: .m2)
            } else {
                let dmg = calcDamage(atk: m2.atk, def: m1.def)
                m1.currentHp = max(0, m1.currentHp - dmg)
                await showDamage(amount: dmg, target: .m1)
            }
            turn += 1
        }

        let result: Monster
        if m1.currentHp <= 0 {
            result = m2
        } else if m2.currentHp <= 0 {
            result = m1
        } else {
            result = m1.atk >= m2.atk ? m1 : m2
        }

        winner = result
        onBattleEnd(result)
    }

    private func calcDamage(atk: Int, def: Int) -> Int {
        max(1, Int(Double(atk) * Double.random(in: 0.8...1.2)) - def)
    }

    private enum Target { case m1, m2 }

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
        case .m2:
            m2DamageText = text
            withAnimation(.spring(response: 0.1, dampingFraction: 0.2)) { m2Shake = true }
            withAnimation(.easeIn(duration: 0.6)) { m2DamageOpacity = 1 }
            try? await Task.sleep(nanoseconds: 400_000_000)
            withAnimation { m2Shake = false }
            withAnimation(.easeOut(duration: 0.4)) { m2DamageOpacity = 0 }
        }
    }
}
