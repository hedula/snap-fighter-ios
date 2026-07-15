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

    var subtitle: String {
        switch self {
        case .attack:
            return "穩定輸出，適合一般回合壓血。"
        case .skill:
            return "依技能類型觸發，可能偏爆發、防禦或吸收。"
        case .defend:
            return "減少下一次受擊傷害，適合撐過敵方強攻。"
        case .swap:
            return "切換待命副將，並消耗你的本回合。"
        }
    }
}

struct BattleResolvedAction: Equatable {
    let actor: BattleActor
    let action: BattleAction
    let target: BattleActor?
    let damage: Int
    let message: String
    let skillEffect: BattleSkillEffect?

    init(
        actor: BattleActor,
        action: BattleAction,
        target: BattleActor?,
        damage: Int,
        message: String,
        skillEffect: BattleSkillEffect? = nil
    ) {
        self.actor = actor
        self.action = action
        self.target = target
        self.damage = damage
        self.message = message
        self.skillEffect = skillEffect
    }
}

struct BattleSkillEffect: Equatable {
    let actor: BattleActor
    let element: Element
    let tier: ElementalSkillTier
    let skillName: String
    let useCountAfterActivation: Int
}

struct BattleEventPresentation: Equatable {
    let title: String
    let detail: String?
}

enum BattlePresentationTone: Equatable {
    case player
    case opponent
    case finished
}

struct BattleActionPresentation: Equatable {
    let action: BattleAction
    let isEnabled: Bool
    let disabledReason: String?
}

struct BattleSession {
    private enum BattleDamageProfile {
        case attack
        case skill

        var pressureFloorRatio: Double {
            switch self {
            case .attack:
                return 0.12
            case .skill:
                return 0.18
            }
        }
    }

    private(set) var player: Monster
    private(set) var opponent: Monster
    private(set) var reservePlayer: Monster?
    private(set) var turn: BattleTurn
    private(set) var statusText: String
    private(set) var winner: Monster?
    private(set) var latestEvent: BattleEventPresentation
    private(set) var roundNumber = 1

    private(set) var playerDefenseActive = false
    private(set) var opponentDefenseActive = false
    private(set) var playerAttackBonus = 0
    private(set) var playerSkillCooldownRemaining = 0
    private(set) var reservePlayerSkillCooldownRemaining = 0
    private(set) var opponentSkillCooldownRemaining = 0

    init(player: Monster, opponent: Monster, reservePlayer: Monster? = nil) {
        self.player = player
        self.opponent = opponent
        self.reservePlayer = reservePlayer
        self.turn = .player
        self.statusText = "輪到你了，選一個指令。"
        self.latestEvent = BattleEventPresentation(title: "戰鬥開始", detail: "輪到你了，選一個指令。")
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

    var presentationTone: BattlePresentationTone {
        switch turn {
        case .player:
            return .player
        case .opponent:
            return .opponent
        case .finished:
            return .finished
        }
    }

    var headerTitle: String {
        if isFinished {
            return "戰鬥結束"
        }

        return turn == .player ? "你的行動回合" : "敵方出招中"
    }

    var turnLabel: String {
        if isFinished {
            return "戰鬥結束"
        }

        return turn == .player ? "輪到你了" : "敵方行動中"
    }

    var headerTags: [String] {
        var tags: [String] = []

        if player.element.hasBattleAdvantage(against: opponent.element) {
            tags.append("我方屬性佔優")
        } else if opponent.element.hasBattleAdvantage(against: player.element) {
            tags.append("敵方屬性佔優")
        }

        if reservePlayer != nil {
            tags.append("副將待命")
        }

        if playerDefenseActive || opponentDefenseActive {
            tags.append("有人防禦中")
        }

        return Array(tags.prefix(2))
    }

    var playerStatusTags: [String] {
        var tags: [String] = []

        if playerDefenseActive {
            tags.append("防禦中")
        }

        if playerAttackBonus > 0 {
            tags.append("下一擊增傷")
        }

        if playerSkillCooldownRemaining > 0 {
            tags.append("技能冷卻 \(playerSkillCooldownRemaining)")
        }

        if player.element.hasBattleAdvantage(against: opponent.element) {
            tags.append("剋制敵方")
        } else if opponent.element.hasBattleAdvantage(against: player.element) {
            tags.append("被敵方剋制")
        }

        return tags
    }

    var opponentStatusTags: [String] {
        var tags: [String] = []

        if opponentDefenseActive {
            tags.append("防禦中")
        }

        if opponentSkillCooldownRemaining > 0 {
            tags.append("技能冷卻 \(opponentSkillCooldownRemaining)")
        }

        if opponent.element.hasBattleAdvantage(against: player.element) {
            tags.append("剋制我方")
        } else if player.element.hasBattleAdvantage(against: opponent.element) {
            tags.append("被我方剋制")
        }

        return tags
    }

    var reservePlayerStatusHint: String? {
        guard let reservePlayer else { return nil }
        return "\(reservePlayer.skillType.reserveEntryHint) · \(reservePlayer.elementalSkillDisplayText)"
    }

    var actionPanelHint: String {
        if isFinished {
            return "等待結算"
        }

        return turn == .player ? "選一個指令後推進回合" : "目前不可輸入"
    }

    func actionPresentation(for action: BattleAction) -> BattleActionPresentation {
        let disabledReason: String?

        switch action {
        case .skill:
            if isFinished {
                disabledReason = "戰鬥已結束。"
            } else if turn != .player {
                disabledReason = "目前不可輸入。"
            } else if playerSkillCooldownRemaining > 0 {
                disabledReason = "技能冷卻中，還需 \(playerSkillCooldownRemaining) 回合。"
            } else {
                disabledReason = nil
            }
        case .swap:
            if reservePlayer == nil {
                disabledReason = "沒有待命副將可替換。"
            } else if turn != .player {
                disabledReason = "只有在你的回合才能換副將。"
            } else if isFinished {
                disabledReason = "戰鬥已結束。"
            } else {
                disabledReason = nil
            }
        default:
            if isFinished {
                disabledReason = "戰鬥已結束。"
            } else if turn != .player {
                disabledReason = "目前不可輸入。"
            } else {
                disabledReason = nil
            }
        }

        return BattleActionPresentation(
            action: action,
            isEnabled: disabledReason == nil,
            disabledReason: disabledReason
        )
    }

    mutating func performPlayerAction(_ action: BattleAction, damageRoll: Double = 1.0) -> BattleResolvedAction? {
        guard canPlayerAct else { return nil }
        let result = perform(action, actor: .player, damageRoll: damageRoll)
        latestEvent = eventPresentation(for: result)
        return result
    }

    mutating func chooseOpponentAction(randomValue: Double = Double.random(in: 0...1)) -> BattleAction {
        guard turn == .opponent, !isFinished else { return .attack }
        let canUseSkill = opponentSkillCooldownRemaining == 0

        if opponent.currentHp <= max(18, opponent.hp / 3) {
            if canUseSkill, opponent.skillType == .fortify, randomValue < 0.6 {
                return .skill
            }

            if randomValue < 0.35 {
                return .defend
            }
        }

        if !canUseSkill {
            return randomValue < 0.8 ? .attack : .defend
        }

        return randomValue < 0.72 ? .attack : .skill
    }

    mutating func performOpponentAction(_ action: BattleAction, damageRoll: Double = 1.0) -> BattleResolvedAction? {
        guard turn == .opponent, !isFinished else { return nil }
        let result = perform(action, actor: .opponent, damageRoll: damageRoll)
        if turn == .player {
            roundNumber += 1
        }
        latestEvent = eventPresentation(for: result)
        return result
    }

    var settlementEvent: BattleEventPresentation {
        BattleEventPresentation(
            title: statusText,
            detail: isFinished ? "戰鬥已結束，正在結算勝者。" : statusText
        )
    }

    mutating func markSettlementEvent() {
        latestEvent = settlementEvent
    }

    private mutating func perform(_ action: BattleAction, actor: BattleActor, damageRoll: Double) -> BattleResolvedAction {
        switch action {
        case .attack:
            return dealDamage(
                from: actor,
                action: action,
                actionDisplayName: action.title,
                profile: .attack,
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
        profile: BattleDamageProfile,
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

        let scaledAttack = Double(attacker.atk + flatBonus + attackBonus) * multiplier * damageRoll * elementMultiplier
        let softenedDefense = Double(defender.def) * 0.55
        let pressureFloor = max(4, Int(ceil(Double(defender.hp) * profile.pressureFloorRatio)))
        let baseDamage = max(pressureFloor, Int(scaledAttack.rounded(.down)) - Int(softenedDefense.rounded(.down)))
        let defendedFloor = max(2, Int(ceil(Double(defender.hp) * 0.06)))
        let finalDamage = defenseActive ? max(defendedFloor, Int((Double(baseDamage) * 0.6).rounded(.down))) : baseDamage

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
                playerSkillCooldownRemaining = reservePlayerSkillCooldownRemaining
                reservePlayerSkillCooldownRemaining = 0
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

        advanceCooldowns(after: action, actor: actor)

        return BattleResolvedAction(
            actor: actor,
            action: action,
            target: targetActor,
            damage: finalDamage,
            message: message
        )
    }

    private mutating func performSkill(from actor: BattleActor, damageRoll: Double) -> BattleResolvedAction {
        recordSkillUse(for: actor)
        let attacker = actor == .player ? player : opponent
        let template = attacker.skillType
        let skillEffect = BattleSkillEffect(
            actor: actor,
            element: attacker.element,
            tier: attacker.elementalSkillTier,
            skillName: attacker.skill,
            useCountAfterActivation: attacker.skillUsageCount
        )

        switch template {
        case .powerStrike:
            var result = dealDamage(
                from: actor,
                action: .skill,
                actionDisplayName: attacker.skill,
                profile: .skill,
                multiplier: 1.3 * attacker.elementalSkillTier.intensityMultiplier,
                flatBonus: 8,
                damageRoll: damageRoll
            )
            result = addingSkillEffect(skillEffect, to: result)
            startSkillCooldown(for: actor)
            result = refreshedEventResult(from: result, actor: actor)
            return result
        case .fortify:
            var result = fortify(from: actor)
            result = addingSkillEffect(skillEffect, to: result)
            startSkillCooldown(for: actor)
            return refreshedEventResult(from: result, actor: actor)
        case .siphonStrike:
            var result = siphonStrike(from: actor, damageRoll: damageRoll)
            result = addingSkillEffect(skillEffect, to: result)
            startSkillCooldown(for: actor)
            result = refreshedEventResult(from: result, actor: actor)
            return result
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
            profile: .skill,
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
        let previousPlayerCooldown = playerSkillCooldownRemaining
        player = reserve
        reservePlayer = previousPlayer
        playerSkillCooldownRemaining = reservePlayerSkillCooldownRemaining
        reservePlayerSkillCooldownRemaining = previousPlayerCooldown
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
        switch player.skillType {
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

    private mutating func recordSkillUse(for actor: BattleActor) {
        switch actor {
        case .player:
            player = player.recordingSkillUse()
        case .opponent:
            opponent = opponent.recordingSkillUse()
        }
    }

    private func addingSkillEffect(_ skillEffect: BattleSkillEffect, to result: BattleResolvedAction) -> BattleResolvedAction {
        BattleResolvedAction(
            actor: result.actor,
            action: result.action,
            target: result.target,
            damage: result.damage,
            message: result.message,
            skillEffect: skillEffect
        )
    }

    private func eventPresentation(for result: BattleResolvedAction) -> BattleEventPresentation {
        BattleEventPresentation(
            title: result.message,
            detail: statusText
        )
    }

    private mutating func startSkillCooldown(for actor: BattleActor) {
        switch actor {
        case .player:
            playerSkillCooldownRemaining = 1
        case .opponent:
            opponentSkillCooldownRemaining = 1
        }
    }

    private mutating func advanceCooldowns(after action: BattleAction, actor: BattleActor) {
        guard action != .skill else { return }

        switch actor {
        case .player:
            if playerSkillCooldownRemaining > 0 {
                playerSkillCooldownRemaining -= 1
            }
        case .opponent:
            if opponentSkillCooldownRemaining > 0 {
                opponentSkillCooldownRemaining -= 1
            }
        }
    }

    private mutating func refreshedEventResult(from result: BattleResolvedAction, actor: BattleActor) -> BattleResolvedAction {
        guard result.action == .skill else { return result }

        let cooldownRemaining = actor == .player ? playerSkillCooldownRemaining : opponentSkillCooldownRemaining
        guard cooldownRemaining > 0 else { return result }

        return BattleResolvedAction(
            actor: result.actor,
            action: result.action,
            target: result.target,
            damage: result.damage,
            message: "\(result.message) 技能將冷卻 \(cooldownRemaining) 回合。",
            skillEffect: result.skillEffect
        )
    }
}

private extension Element {
    func hasBattleAdvantage(against defender: Element) -> Bool {
        battleMultiplier(against: defender) > 1.0
    }
}
