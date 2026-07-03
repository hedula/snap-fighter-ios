//
//  Snap_FighterTests.swift
//  Snap FighterTests
//
//  Created by Hedula Lee on 2026/5/4.
//

import Testing
import UIKit
@testable import Snap_Fighter

@MainActor
struct Snap_FighterTests {

    @Test func captureMonsterShowsCardThenReadyToBattle() async throws {
        let firstMonster = Monster(from: .init(name: "火杯獸", element: "火", hp: 70, atk: 55, def: 35, skill: "火焰衝撞"))
        let secondMonster = Monster(from: .init(name: "草箱獸", element: "草", hp: 66, atk: 48, def: 42, skill: "藤蔓拍擊"))
        var callCount = 0
        let viewModel = GameViewModel { _ in
            defer { callCount += 1 }
            let monster = callCount == 0 ? firstMonster : secondMonster
            return AnalysisResult(
                monster: monster,
                diagnostics: AIDiagnostics(provider: "workers-ai", model: "@cf/meta/llama-3.2-11b-vision-instruct")
            )
        }
        let image = UIImage()

        await viewModel.captureMonster(from: image)

        #expect(viewModel.monsters.count == 1)
        if case .showCard(let monster) = viewModel.state {
            #expect(monster.name == "火杯獸")
        } else {
            Issue.record("Expected showCard state after first capture")
        }

        await viewModel.captureMonster(from: image)

        #expect(viewModel.monsters.count == 2)
        #expect(viewModel.diagnostics?.provider == "workers-ai")
        if case .readyToBattle = viewModel.state {
        } else {
            Issue.record("Expected readyToBattle state after second capture")
        }
        #expect(viewModel.isLoading == false)
    }

    @Test func captureMonsterFailureResetsStateAndStoresError() async throws {
        struct SampleError: LocalizedError {
            var errorDescription: String? { "分析失敗" }
        }

        let viewModel = GameViewModel { _ in
            throw SampleError()
        }

        await viewModel.captureMonster(from: UIImage())

        if case .idle = viewModel.state {
        } else {
            Issue.record("Expected idle state after capture failure")
        }
        #expect(viewModel.errorMessage == "分析失敗")
        #expect(viewModel.monsters.isEmpty)
        #expect(viewModel.diagnostics == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test func resetMonstersClearsBattleProgress() {
        let monster = Monster(from: .init(name: "雷貓", element: "電", hp: 60, atk: 58, def: 30, skill: "電光衝刺"))
        let viewModel = GameViewModel { _ in
            AnalysisResult(
                monster: monster,
                diagnostics: AIDiagnostics(provider: "workers-ai", model: "@cf/meta/llama-3.2-11b-vision-instruct")
            )
        }
        viewModel.monsters = [monster, monster]
        viewModel.diagnostics = AIDiagnostics(provider: "workers-ai", model: "@cf/meta/llama-3.2-11b-vision-instruct")
        viewModel.state = .result(monster)

        viewModel.resetMonsters()

        #expect(viewModel.monsters.isEmpty)
        #expect(viewModel.diagnostics == nil)
        if case .idle = viewModel.state {
        } else {
            Issue.record("Expected idle state after reset")
        }
    }

    @Test func deckStorePersistsSavedWinner() {
        let suiteName = "Snap_FighterTests.deckStorePersistsSavedWinner"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let monster = Monster(
            name: "冠軍貓",
            element: .electric,
            hp: 88,
            atk: 74,
            def: 41,
            skill: "雷光爪擊",
            capturedImage: UIImage(),
            preferredArtwork: .original,
            level: 3,
            experience: 45,
        )

        let store = DeckStore(userDefaults: defaults, storageKey: "deck")
        #expect(store.addToDeck(monster) == true)

        let reloadedStore = DeckStore(userDefaults: defaults, storageKey: "deck")
        #expect(reloadedStore.deck.count == 1)
        #expect(reloadedStore.deck.first?.name == "冠軍貓")
        #expect(reloadedStore.deck.first?.element == .electric)
        #expect(reloadedStore.deck.first?.preferredArtwork == .original)
        #expect(reloadedStore.deck.first?.level == 3)
        #expect(reloadedStore.deck.first?.experience == 45)
    }

    @Test func deckStoreRejectsDuplicateWinner() {
        let suiteName = "Snap_FighterTests.deckStoreRejectsDuplicateWinner"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let monster = Monster(
            name: "雙冠王",
            element: .fire,
            hp: 90,
            atk: 80,
            def: 50,
            skill: "烈焰連勝"
        )

        let store = DeckStore(userDefaults: defaults, storageKey: "deck")

        #expect(store.addToDeck(monster) == true)
        #expect(store.addToDeck(monster) == false)
        #expect(store.deck.count == 1)
    }

    @Test func deckStoreRemovesSavedWinnerPersistently() {
        let suiteName = "Snap_FighterTests.deckStoreRemovesSavedWinnerPersistently"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let monster = Monster(
            name: "退役王者",
            element: .water,
            hp: 77,
            atk: 62,
            def: 58,
            skill: "潮汐守備"
        )

        let store = DeckStore(userDefaults: defaults, storageKey: "deck")
        #expect(store.addToDeck(monster) == true)

        store.removeFromDeck(id: monster.id)
        #expect(store.deck.isEmpty)

        let reloadedStore = DeckStore(userDefaults: defaults, storageKey: "deck")
        #expect(reloadedStore.deck.isEmpty)
    }

    @Test func deckStoreLimitsActiveBattleDeckToTwoCards() {
        let suiteName = "Snap_FighterTests.deckStoreLimitsActiveBattleDeckToTwoCards"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let first = Monster(name: "一號", element: .fire, hp: 60, atk: 50, def: 30, skill: "火")
        let second = Monster(name: "二號", element: .water, hp: 62, atk: 48, def: 35, skill: "水")
        let third = Monster(name: "三號", element: .grass, hp: 64, atk: 46, def: 38, skill: "草")

        let store = DeckStore(userDefaults: defaults, storageKey: "deck", activeDeckStorageKey: "active_deck")
        _ = store.addToDeck(first)
        _ = store.addToDeck(second)
        _ = store.addToDeck(third)

        #expect(store.toggleActiveBattleDeck(first) == true)
        #expect(store.toggleActiveBattleDeck(second) == true)
        #expect(store.toggleActiveBattleDeck(third) == false)
        #expect(store.activeBattleDeck.map(\.name) == ["一號", "二號"])
    }

    @Test func deckStoreRemovingCardAlsoRemovesItFromActiveBattleDeck() {
        let suiteName = "Snap_FighterTests.deckStoreRemovingCardAlsoRemovesItFromActiveBattleDeck"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let first = Monster(name: "先鋒", element: .electric, hp: 70, atk: 65, def: 42, skill: "雷")
        let second = Monster(name: "後衛", element: .dark, hp: 72, atk: 58, def: 48, skill: "暗")

        let store = DeckStore(userDefaults: defaults, storageKey: "deck", activeDeckStorageKey: "active_deck")
        _ = store.addToDeck(first)
        _ = store.addToDeck(second)
        _ = store.toggleActiveBattleDeck(first)
        _ = store.toggleActiveBattleDeck(second)

        store.removeFromDeck(id: first.id)

        #expect(store.activeBattleDeck.map(\.name) == ["後衛"])

        let reloadedStore = DeckStore(userDefaults: defaults, storageKey: "deck", activeDeckStorageKey: "active_deck")
        #expect(reloadedStore.activeBattleDeck.map(\.name) == ["後衛"])
    }

    @Test func prepareBattleUsesDeckMonstersAndResetsHP() {
        let first = Monster(
            name: "先發火貓",
            element: .fire,
            hp: 80,
            atk: 70,
            def: 35,
            skill: "火尾擊",
            currentHp: 12
        )
        let second = Monster(
            name: "先發水龜",
            element: .water,
            hp: 90,
            atk: 55,
            def: 60,
            skill: "潮汐盾",
            currentHp: 5
        )
        let viewModel = GameViewModel { _ in
            AnalysisResult(
                monster: first,
                diagnostics: AIDiagnostics(provider: "mock", model: "preview")
            )
        }
        viewModel.diagnostics = AIDiagnostics(provider: "workers-ai", model: "temp")

        viewModel.prepareBattle(with: [first, second])

        #expect(viewModel.monsters.map(\.currentHp) == [80, 90])
        #expect(viewModel.diagnostics == nil)
        if case .readyToBattle = viewModel.state {
        } else {
            Issue.record("Expected readyToBattle state after preparing battle deck")
        }
    }

    @Test func prepareBattleAgainstAIUsesFirstDeckMonsterAndGeneratedOpponent() {
        let first = Monster(
            name: "主將貓",
            element: .fire,
            hp: 81,
            atk: 68,
            def: 37,
            skill: "火環突進",
            currentHp: 3
        )
        let second = Monster(
            name: "副將龜",
            element: .water,
            hp: 92,
            atk: 50,
            def: 61,
            skill: "冰潮護盾",
            currentHp: 11
        )
        let aiOpponent = Monster(
            name: "競技場機兵",
            element: .electric,
            hp: 88,
            atk: 66,
            def: 44,
            skill: "磁暴轟擊",
            currentHp: 22
        )
        let viewModel = GameViewModel(
            analyzeMonster: { _ in
                AnalysisResult(
                    monster: first,
                    diagnostics: AIDiagnostics(provider: "mock", model: "preview")
                )
            },
            generateAIOpponent: { deck in
                #expect(deck.map(\.name) == ["主將貓", "副將龜"])
                return aiOpponent
            }
        )

        viewModel.prepareBattleAgainstAI(with: [first, second])

        #expect(viewModel.monsters.map(\.name) == ["主將貓", "競技場機兵"])
        #expect(viewModel.monsters.map(\.currentHp) == [81, 88])
        #expect(viewModel.reserveMonster?.name == "副將龜")
        if case .readyToBattle = viewModel.state {
        } else {
            Issue.record("Expected readyToBattle state after preparing battle against AI")
        }
    }

    @Test func updateArtworkPreferenceRefreshesShowCardState() async throws {
        let analyzedMonster = Monster(
            name: "切圖貓",
            element: .electric,
            hp: 63,
            atk: 57,
            def: 39,
            skill: "光爪",
            capturedImage: UIImage(),
            cardImage: UIImage(),
            preferredArtwork: .cutout
        )
        let viewModel = GameViewModel { _ in
            AnalysisResult(
                monster: analyzedMonster,
                diagnostics: AIDiagnostics(provider: "mock", model: "preview")
            )
        }

        await viewModel.captureMonster(from: UIImage())
        viewModel.updateArtworkPreference(.original, for: analyzedMonster.id)

        if case .showCard(let monster) = viewModel.state {
            #expect(monster.preferredArtwork == .original)
        } else {
            Issue.record("Expected showCard state after artwork preference update")
        }
        #expect(viewModel.monsters.first?.preferredArtwork == .original)
    }

    @Test func deckBattleVictoryAwardsExperienceAndPersistsGrowth() {
        let suiteName = "Snap_FighterTests.deckBattleVictoryAwardsExperienceAndPersistsGrowth"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let player = Monster(
            name: "成長貓",
            element: .fire,
            hp: 80,
            atk: 70,
            def: 35,
            skill: "烈焰突擊",
            level: 1,
            experience: 70
        )
        let reserve = Monster(
            name: "後備龜",
            element: .water,
            hp: 92,
            atk: 50,
            def: 61,
            skill: "冰潮護盾"
        )
        let aiOpponent = Monster(
            name: "場館守衛",
            element: .grass,
            hp: 76,
            atk: 46,
            def: 33,
            skill: "蔓生壓制"
        )
        let store = DeckStore(userDefaults: defaults, storageKey: "deck", activeDeckStorageKey: "active_deck")
        _ = store.addToDeck(player)
        _ = store.addToDeck(reserve)
        let viewModel = GameViewModel(
            analyzeMonster: { _ in
                AnalysisResult(
                    monster: player,
                    diagnostics: AIDiagnostics(provider: "mock", model: "preview")
                )
            },
            generateAIOpponent: { _ in aiOpponent }
        )

        viewModel.prepareBattleAgainstAI(with: [player, reserve])
        viewModel.endBattle(winner: viewModel.monsters[0], deckStore: store)

        if case .result(let winner) = viewModel.state {
            #expect(winner.level == 2)
            #expect(winner.experience == 10)
            #expect(winner.hp == 88)
            #expect(winner.atk == 74)
            #expect(winner.def == 38)
        } else {
            Issue.record("Expected result state after battle reward resolution")
        }

        #expect(viewModel.battleReward == .init(monsterID: player.id, experienceGained: 40, levelsGained: 1))
        #expect(store.deck.first(where: { $0.id == player.id })?.level == 2)
        #expect(store.deck.first(where: { $0.id == player.id })?.experience == 10)
    }

    @Test func reserveMonsterVictoryAlsoAwardsExperience() {
        let suiteName = "Snap_FighterTests.reserveMonsterVictoryAlsoAwardsExperience"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let main = Monster(
            name: "主將狼",
            element: .dark,
            hp: 84,
            atk: 72,
            def: 34,
            skill: "影襲"
        )
        let reserve = Monster(
            name: "副將鹿",
            element: .grass,
            hp: 78,
            atk: 64,
            def: 40,
            skill: "根鬚反擊",
            level: 2,
            experience: 120
        )
        let aiOpponent = Monster(
            name: "競技守門員",
            element: .fire,
            hp: 82,
            atk: 67,
            def: 39,
            skill: "炎矛突進"
        )
        let store = DeckStore(userDefaults: defaults, storageKey: "deck", activeDeckStorageKey: "active_deck")
        _ = store.addToDeck(main)
        _ = store.addToDeck(reserve)
        let viewModel = GameViewModel(
            analyzeMonster: { _ in
                AnalysisResult(
                    monster: main,
                    diagnostics: AIDiagnostics(provider: "mock", model: "preview")
                )
            },
            generateAIOpponent: { _ in aiOpponent }
        )

        viewModel.prepareBattleAgainstAI(with: [main, reserve])
        let reserveWinner = reserve.resetForBattle()
        viewModel.endBattle(winner: reserveWinner, deckStore: store)

        if case .result(let winner) = viewModel.state {
            #expect(winner.id == reserve.id)
            #expect(winner.level == 3)
            #expect(winner.experience == 20)
        } else {
            Issue.record("Expected reserve winner to resolve battle result")
        }

        #expect(viewModel.battleReward == .init(monsterID: reserve.id, experienceGained: 40, levelsGained: 1))
        #expect(store.deck.first(where: { $0.id == reserve.id })?.level == 3)
        #expect(store.deck.first(where: { $0.id == reserve.id })?.experience == 20)
    }

    @Test func aiServiceUsesForegroundCutoutWhenAvailable() async throws {
        let sourceImage = makeImage(color: .blue, size: CGSize(width: 40, height: 40))
        let cutoutImage = makeImage(color: .green, size: CGSize(width: 20, height: 20))
        let service = AIService(isolateForeground: { _ in cutoutImage })

        let result = await service.analyzeMock(image: sourceImage)

        #expect(result.monster.capturedImage?.pngData() == sourceImage.pngData())
        #expect(result.monster.cardImage?.pngData() == cutoutImage.pngData())
    }

    @Test func aiServiceKeepsOriginalImageWhenCutoutFails() async throws {
        let sourceImage = makeImage(color: .purple, size: CGSize(width: 32, height: 32))
        let service = AIService(isolateForeground: { _ in nil })

        let result = await service.analyzeMock(image: sourceImage)

        #expect(result.monster.capturedImage?.pngData() == sourceImage.pngData())
        #expect(result.monster.cardImage == nil)
    }

    @Test func battleSessionAttackHandsTurnToOpponent() {
        var session = BattleSession(
            player: Monster(name: "玩家貓", element: .fire, hp: 70, atk: 50, def: 20, skill: "火抓"),
            opponent: Monster(name: "敵方龜", element: .water, hp: 70, atk: 40, def: 10, skill: "水盾")
        )

        let result = session.performPlayerAction(.attack, damageRoll: 1.0)

        #expect(result?.action == .attack)
        #expect(result?.damage == 32)
        #expect(session.opponent.currentHp == 38)
        #expect(session.turn == .opponent)
    }

    @Test func battleSessionDefendReducesNextIncomingDamage() {
        var session = BattleSession(
            player: Monster(name: "玩家貓", element: .fire, hp: 80, atk: 48, def: 18, skill: "火抓"),
            opponent: Monster(name: "敵方狼", element: .dark, hp: 78, atk: 54, def: 12, skill: "影襲")
        )

        _ = session.performPlayerAction(.defend)
        let aiResult = session.performOpponentAction(.attack, damageRoll: 1.0)

        #expect(aiResult?.damage == 18)
        #expect(session.player.currentHp == 62)
        #expect(session.turn == .player)
    }

    @Test func battleSessionSwapMovesReserveIntoFrontLine() {
        let main = Monster(name: "主將", element: .fire, hp: 70, atk: 50, def: 20, skill: "火抓")
        let reserve = Monster(name: "副將", element: .water, hp: 90, atk: 44, def: 30, skill: "潮盾")
        var session = BattleSession(
            player: main,
            opponent: Monster(name: "敵方", element: .grass, hp: 60, atk: 42, def: 16, skill: "藤擊"),
            reservePlayer: reserve
        )

        let result = session.performPlayerAction(.swap)

        #expect(result?.action == .swap)
        #expect(session.player.name == "副將")
        #expect(session.reservePlayer?.name == "主將")
        #expect(session.turn == .opponent)
        #expect(session.playerDefenseActive == true)
    }

    @Test func battleSessionAutoSwapsReserveWhenFrontMonsterFalls() {
        let main = Monster(name: "主將", element: .fire, hp: 30, atk: 42, def: 10, skill: "火抓")
        let reserve = Monster(name: "副將", element: .water, hp: 65, atk: 44, def: 18, skill: "潮盾")
        var session = BattleSession(
            player: main,
            opponent: Monster(name: "敵方", element: .grass, hp: 90, atk: 55, def: 10, skill: "藤擊"),
            reservePlayer: reserve
        )

        _ = session.performPlayerAction(.attack, damageRoll: 1.0)
        let result = session.performOpponentAction(.skill, damageRoll: 1.0)

        #expect(result?.damage == 59)
        #expect(session.player.name == "副將")
        #expect(session.reservePlayer == nil)
        #expect(session.turn == .player)
        #expect(session.winner == nil)
        #expect(session.playerDefenseActive == true)
    }

    @Test func battleSessionReservePowerStrikeBoostsNextAttack() {
        let main = Monster(name: "主將", element: .water, hp: 74, atk: 40, def: 18, skill: "潮盾")
        let reserve = Monster(name: "副將", element: .fire, hp: 70, atk: 50, def: 22, skill: "烈焰突進")
        var session = BattleSession(
            player: main,
            opponent: Monster(name: "敵方", element: .grass, hp: 90, atk: 35, def: 10, skill: "藤擊"),
            reservePlayer: reserve
        )

        _ = session.performPlayerAction(.swap)
        _ = session.performOpponentAction(.attack, damageRoll: 1.0)
        let result = session.performPlayerAction(.attack, damageRoll: 1.0)

        #expect(session.player.name == "副將")
        #expect(result?.damage == 62)
        #expect(session.playerAttackBonus == 0)
    }

    @Test func battleSessionFortifySkillAddsDefenseAndHeal() {
        var session = BattleSession(
            player: Monster(name: "守護龜", element: .water, hp: 90, atk: 42, def: 28, skill: "冰潮護盾", currentHp: 60),
            opponent: Monster(name: "敵方狼", element: .dark, hp: 78, atk: 54, def: 12, skill: "影襲")
        )

        let result = session.performPlayerAction(.skill, damageRoll: 1.0)

        #expect(result?.action == .skill)
        #expect(result?.damage == 0)
        #expect(session.player.currentHp == 69)
        #expect(session.turn == .opponent)

        let followUp = session.performOpponentAction(.attack, damageRoll: 1.0)
        #expect(followUp?.damage == 13)
    }

    @Test func battleSessionSiphonSkillHealsAfterDamage() {
        var session = BattleSession(
            player: Monster(name: "藤冠獵手", element: .grass, hp: 85, atk: 52, def: 18, skill: "纏根絞擊", currentHp: 50),
            opponent: Monster(name: "敵方兵", element: .fire, hp: 80, atk: 45, def: 16, skill: "炎矛突進")
        )

        let result = session.performPlayerAction(.skill, damageRoll: 1.0)

        #expect(result?.action == .skill)
        #expect(result?.damage == 31)
        #expect(session.opponent.currentHp == 49)
        #expect(session.player.currentHp == 65)
        #expect(session.turn == .opponent)
    }

    @Test func battleSessionElementAdvantageIncreasesDamage() {
        var session = BattleSession(
            player: Monster(name: "火貓", element: .fire, hp: 70, atk: 50, def: 20, skill: "火抓"),
            opponent: Monster(name: "草獸", element: .grass, hp: 70, atk: 40, def: 10, skill: "藤擊")
        )

        let result = session.performPlayerAction(.attack, damageRoll: 1.0)

        #expect(result?.damage == 52)
        #expect(result?.message.contains("效果絕佳。") == true)
        #expect(session.opponent.currentHp == 18)
    }

    @Test func battleSessionElementDisadvantageReducesDamage() {
        var session = BattleSession(
            player: Monster(name: "火貓", element: .fire, hp: 70, atk: 50, def: 20, skill: "火抓"),
            opponent: Monster(name: "水龜", element: .water, hp: 70, atk: 40, def: 10, skill: "水盾")
        )

        let result = session.performPlayerAction(.attack, damageRoll: 1.0)

        #expect(result?.damage == 32)
        #expect(result?.message.contains("效果普通偏弱。") == true)
        #expect(session.opponent.currentHp == 38)
    }

    private func makeImage(color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

}
