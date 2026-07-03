import Foundation

enum BattleActor: Equatable {
    case player
    case opponent
}

enum BattleTurn: Equatable {
    case player
    case opponent
    case finished
}

enum BattleAction: CaseIterable, Equatable {
    case attack
    case skill
    case defend
    case swap

    var title: String {
        switch self {
        case .attack: return "普攻"
        case .skill: return "技能"
        case .defend: return "防禦"
        case .swap: return "換副將"
        }
    }

    var systemImage: String {
        switch self {
        case .attack: return "bolt.fill"
        case .skill: return "sparkles"
        case .defend: return "shield.fill"
        case .swap: return "arrow.triangle.2.circlepath"
        }
    }
}

struct BattleResolvedAction: Equatable {
    let actor: BattleActor
    let action: BattleAction
    let target: BattleActor?
    let damage: Int
    let message: String
}

struct BattleSession {
    private enum BattleSkillTemplate {
        case powerStrike
        case fortify
        case siphonStrike
    }

    private(set) var player: Monster
    private(set) var opponent: Monster
    private(set) var reservePlayer: Monster?
    private(set) var turn: BattleTurn
    private(set) var statusText: String
    private(set) var winner: Monster?

    private(set) var playerDefenseActive = false
    private(set) var opponentDefenseActive = false
    private(set) var playerAttackBonus = 0

    init(player: Monster, opponent: Monster, reservePlayer: Monster? = nil) {
        self.player = player
        self.opponent = opponent
        self.reservePlayer = reservePlayer
        self.turn = .player
        self.statusText = "輪到你了，選一個指令。"
    }

    var isFinished: Bool {
        turn == .finished
    }

    var canPlayerAct: Bool {
        turn == .player && !isFinished
    }

    var canSwap: Bool {
        canPlayerAct && reservePlayer != nil
    }

    mutating func performPlayerAction(_ action: BattleAction, damageRoll: Double = 1.0) -> BattleResolvedAction? {
        guard canPlayerAct else { return nil }
        return perform(action, actor: .player, damageRoll: damageRoll)
    }

    mutating func chooseOpponentAction(randomValue: Double = Double.random(in: 0...1)) -> BattleAction {
        guard turn == .opponent, !isFinished else { return .attack }
        let skillTemplate = skillTemplate(for: opponent)

        if opponent.currentHp <= max(18, opponent.hp / 3) {
            if skillTemplate == .fortify, randomValue < 0.6 {
                return .skill
            }

            if randomValue < 0.35 {
                return .defend
            }
        }

        return randomValue < 0.72 ? .attack : .skill
    }

    mutating func performOpponentAction(_ action: BattleAction, damageRoll: Double = 1.0) -> BattleResolvedAction? {
        guard turn == .opponent, !isFinished else { return nil }
        return perform(action, actor: .opponent, damageRoll: damageRoll)
    }

    private mutating func perform(_ action: BattleAction, actor: BattleActor, damageRoll: Double) -> BattleResolvedAction {
        switch action {
        case .attack:
            return dealDamage(
                from: actor,
                action: action,
                actionDisplayName: action.title,
                multiplier: 1.0,
                flatBonus: 0,
                damageRoll: damageRoll
            )
        case .skill:
            return performSkill(from: actor, damageRoll: damageRoll)
        case .defend:
            return activateDefense(for: actor)
        case .swap:
            return swapPlayer()
        }
    }

    private mutating func dealDamage(
        from actor: BattleActor,
        action: BattleAction,
        actionDisplayName: String,
        multiplier: Double,
        flatBonus: Int,
        damageRoll: Double
    ) -> BattleResolvedAction {
        let attacker = actor == .player ? player : opponent
        let targetActor: BattleActor = actor == .player ? .opponent : .player
        let defender = targetActor == .player ? player : opponent
        let defenseActive = targetActor == .player ? playerDefenseActive : opponentDefenseActive
        let elementMultiplier = attacker.element.battleMultiplier(against: defender.element)
        let attackBonus = actor == .player ? playerAttackBonus : 0

        let baseDamage = max(
            1,
            Int((Double(attacker.atk + flatBonus + attackBonus) * multiplier * damageRoll * elementMultiplier).rounded(.down)) - defender.def
        )
        let finalDamage = defenseActive ? max(1, baseDamage / 2) : baseDamage

        if actor == .player {
            playerAttackBonus = 0
        }

        if targetActor == .player {
            player.currentHp = max(0, player.currentHp - finalDamage)
            playerDefenseActive = false
        } else {
            opponent.currentHp = max(0, opponent.currentHp - finalDamage)
            opponentDefenseActive = false
        }

        var message = "\(attacker.name) 使用\(actionDisplayName)，造成 \(finalDamage) 點傷害。"

        if defenseActive {
            message += " 防禦生效，傷害被減少。"
        }

        if let effectivenessText = attacker.element.effectivenessText(against: defender.element) {
            message += " \(effectivenessText)"
        }

        if targetActor == .opponent, opponent.currentHp <= 0 {
            winner = player
            turn = .finished
            statusText = "\(player.name) 獲勝！"
            message += " \(opponent.name) 倒下了。"
        } else if targetActor == .player, player.currentHp <= 0 {
            if let reserve = reservePlayer {
                let fallenName = player.name
                player = reserve
                reservePlayer = nil
                playerDefenseActive = false
                turn = .player
                statusText = "\(player.name) 已接替上場，輪到你了。"
                message += " \(fallenName) 倒下，\(player.name) 接替上場。"
                message += " \(applyReserveEntryEffect())"
            } else {
                winner = opponent
                turn = .finished
                statusText = "\(opponent.name) 獲勝！"
                message += " \(player.name) 倒下了。"
            }
        } else {
            turn = actor == .player ? .opponent : .player
            statusText = turn == .player ? "輪到你了，選一個指令。" : "敵方行動中..."
        }

        return BattleResolvedAction(
            actor: actor,
            action: action,
            target: targetActor,
            damage: finalDamage,
            message: message
        )
    }

    private mutating func performSkill(from actor: BattleActor, damageRoll: Double) -> BattleResolvedAction {
        let attacker = actor == .player ? player : opponent
        let template = skillTemplate(for: attacker)

        switch template {
        case .powerStrike:
            return dealDamage(
                from: actor,
                action: .skill,
                actionDisplayName: attacker.skill,
                multiplier: 1.3,
                flatBonus: 8,
                damageRoll: damageRoll
            )
        case .fortify:
            return fortify(from: actor)
        case .siphonStrike:
            return siphonStrike(from: actor, damageRoll: damageRoll)
        }
    }

    private mutating func activateDefense(for actor: BattleActor) -> BattleResolvedAction {
        switch actor {
        case .player:
            playerDefenseActive = true
            turn = .opponent
            statusText = "敵方行動中..."
            return BattleResolvedAction(
                actor: actor,
                action: .defend,
                target: nil,
                damage: 0,
                message: "\(player.name) 進入防禦姿態，下一次受擊傷害會降低。"
            )
        case .opponent:
            opponentDefenseActive = true
            turn = .player
            statusText = "輪到你了，選一個指令。"
            return BattleResolvedAction(
                actor: actor,
                action: .defend,
                target: nil,
                damage: 0,
                message: "\(opponent.name) 進入防禦姿態。"
            )
        }
    }

    private mutating func fortify(from actor: BattleActor) -> BattleResolvedAction {
        let attacker = actor == .player ? player : opponent
        let healAmount: Int

        switch actor {
        case .player:
            playerDefenseActive = true
            healAmount = min(max(6, player.hp / 10), player.hp - player.currentHp)
            player.currentHp += healAmount
            turn = .opponent
            statusText = "敵方行動中..."
        case .opponent:
            opponentDefenseActive = true
            healAmount = min(max(6, opponent.hp / 10), opponent.hp - opponent.currentHp)
            opponent.currentHp += healAmount
            turn = .player
            statusText = "輪到你了，選一個指令。"
        }

        let healText = healAmount > 0 ? " 並回復 \(healAmount) HP。" : " 但 HP 已滿。"
        return BattleResolvedAction(
            actor: actor,
            action: .skill,
            target: nil,
            damage: 0,
            message: "\(attacker.name) 使用\(attacker.skill)，進入防禦姿態\(healText)"
        )
    }

    private mutating func siphonStrike(from actor: BattleActor, damageRoll: Double) -> BattleResolvedAction {
        let attackerBefore = actor == .player ? player : opponent
        var result = dealDamage(
            from: actor,
            action: .skill,
            actionDisplayName: attackerBefore.skill,
            multiplier: 1.0,
            flatBonus: 4,
            damageRoll: damageRoll
        )

        guard result.damage > 0 else { return result }

        let healAmount = max(1, result.damage / 2)
        switch actor {
        case .player:
            let actualHeal = min(healAmount, player.hp - player.currentHp)
            player.currentHp += actualHeal
            if actualHeal > 0 {
                result = BattleResolvedAction(
                    actor: result.actor,
                    action: result.action,
                    target: result.target,
                    damage: result.damage,
                    message: "\(result.message) \(player.name) 吸收了 \(actualHeal) HP。"
                )
            }
        case .opponent:
            let actualHeal = min(healAmount, opponent.hp - opponent.currentHp)
            opponent.currentHp += actualHeal
            if actualHeal > 0 {
                result = BattleResolvedAction(
                    actor: result.actor,
                    action: result.action,
                    target: result.target,
                    damage: result.damage,
                    message: "\(result.message) \(opponent.name) 吸收了 \(actualHeal) HP。"
                )
            }
        }

        return result
    }

    private mutating func swapPlayer() -> BattleResolvedAction {
        guard let reserve = reservePlayer else {
            return BattleResolvedAction(
                actor: .player,
                action: .swap,
                target: nil,
                damage: 0,
                message: "目前沒有副將可替換。"
            )
        }

        let previousPlayer = player
        player = reserve
        reservePlayer = previousPlayer
        playerDefenseActive = false
        turn = .opponent
        statusText = "敵方行動中..."
        let entryEffectMessage = applyReserveEntryEffect()

        return BattleResolvedAction(
            actor: .player,
            action: .swap,
            target: nil,
            damage: 0,
            message: "\(player.name) 接替上場，\(previousPlayer.name) 退到後方待命。 \(entryEffectMessage)"
        )
    }

    private mutating func applyReserveEntryEffect() -> String {
        switch skillTemplate(for: player) {
        case .powerStrike:
            playerAttackBonus += 8
            return "\(player.name) 的進場氣勢提升，下一次攻擊傷害上升。"
        case .fortify:
            playerDefenseActive = true
            let healAmount = min(max(6, player.hp / 10), player.hp - player.currentHp)
            player.currentHp += healAmount
            if healAmount > 0 {
                return "\(player.name) 進場後立刻展開防禦，並回復 \(healAmount) HP。"
            }
            return "\(player.name) 進場後立刻展開防禦。"
        case .siphonStrike:
            let healAmount = min(max(8, player.hp / 8), player.hp - player.currentHp)
            player.currentHp += healAmount
            if healAmount > 0 {
                return "\(player.name) 吸收戰意，進場回復 \(healAmount) HP。"
            }
            return "\(player.name) 吸收戰意，狀態維持全滿。"
        }
    }

    private func skillTemplate(for monster: Monster) -> BattleSkillTemplate {
        let defensiveKeywords = ["盾", "守", "護", "障", "壁"]
        if defensiveKeywords.contains(where: { monster.skill.contains($0) }) {
            return .fortify
        }

        let siphonKeywords = ["吸", "癒", "治", "生", "根", "潮"]
        if siphonKeywords.contains(where: { monster.skill.contains($0) }) {
            return .siphonStrike
        }

        return .powerStrike
    }
}
