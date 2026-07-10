import SwiftUI
import Combine

@MainActor
class GameViewModel: ObservableObject {
    typealias MonsterAnalyzer = (UIImage) async throws -> AnalysisResult
    typealias AIOpponentGenerator = ([Monster]) -> Monster
    typealias StarterDeckFactory = () -> [Monster]
    private enum BattleContext {
        case none
        case captured
        case deckVersusAI
        case starterTrial
    }

    struct BattleReward: Equatable {
        let monsterID: Monster.ID
        let experienceGained: Int
        let levelsGained: Int
    }

    enum AppState {
        case idle
        case capturing
        case analyzing
        case showCard(Monster)
        case readyToBattle
        case battling
        case result(Monster)
    }

    @Published var state: AppState = .idle
    @Published var monsters: [Monster] = []
    @Published var errorMessage: String? = nil
    @Published var diagnostics: AIDiagnostics? = nil
    @Published var isLoading = false
    @Published private(set) var battleReward: BattleReward? = nil
    @Published private(set) var reserveMonster: Monster? = nil
    private let analyzeMonster: MonsterAnalyzer
    private let generateAIOpponent: AIOpponentGenerator
    private let makeStarterDeck: StarterDeckFactory
    private var battleContext: BattleContext = .none
    private var deckBattleParticipantIDs: Set<Monster.ID> = []
    private let playerVictoryExperience = 40

    init(
        analyzeMonster: @escaping MonsterAnalyzer = { image in
            try await AIService.shared.analyze(image: image)
        },
        generateAIOpponent: AIOpponentGenerator? = nil,
        makeStarterDeck: StarterDeckFactory? = nil
    ) {
        self.analyzeMonster = analyzeMonster
        self.generateAIOpponent = generateAIOpponent ?? { deck in
            AIOpponentFactory.makeOpponent(against: deck)
        }
        self.makeStarterDeck = makeStarterDeck ?? {
            [
                Monster(
                    name: "閃焰新兵",
                    element: .fire,
                    hp: 78,
                    atk: 62,
                    def: 34,
                    skill: "烈焰突進"
                ),
                Monster(
                    name: "潮壁見習生",
                    element: .water,
                    hp: 88,
                    atk: 48,
                    def: 56,
                    skill: "潮盾守備"
                )
            ]
        }
    }

    func captureMonster(from image: UIImage) async {
        isLoading = true
        battleReward = nil
        state = .analyzing
        do {
            let result = try await analyzeMonster(image)
            diagnostics = result.diagnostics
            monsters.append(result.monster)
            battleContext = .captured
            reserveMonster = nil
            deckBattleParticipantIDs = []
            state = monsters.count >= 2 ? .readyToBattle : .showCard(result.monster)
        } catch {
            errorMessage = error.localizedDescription
            state = .idle
        }
        isLoading = false
    }

    func startBattle() {
        state = .battling
    }

    func prepareBattle(with monsters: [Monster]) {
        guard monsters.count == 2 else { return }
        self.monsters = monsters.map { $0.resetForBattle() }
        diagnostics = nil
        battleReward = nil
        reserveMonster = nil
        battleContext = .captured
        deckBattleParticipantIDs = []
        state = .readyToBattle
    }

    func prepareBattleAgainstAI(with deck: [Monster]) {
        guard !deck.isEmpty else { return }
        let player = deck[0].resetForBattle()
        let opponent = generateAIOpponent(deck).resetForBattle()
        monsters = [player, opponent]
        reserveMonster = deck.count > 1 ? deck[1].resetForBattle() : nil
        diagnostics = nil
        battleReward = nil
        battleContext = .deckVersusAI
        deckBattleParticipantIDs = Set([player.id, reserveMonster?.id].compactMap { $0 })
        state = .readyToBattle
    }

    func prepareStarterBattle() {
        let starterDeck = makeStarterDeck()
        guard !starterDeck.isEmpty else { return }

        let player = starterDeck[0].resetForBattle()
        let opponent = generateAIOpponent(starterDeck).resetForBattle()
        monsters = [player, opponent]
        reserveMonster = starterDeck.count > 1 ? starterDeck[1].resetForBattle() : nil
        diagnostics = nil
        battleReward = nil
        battleContext = .starterTrial
        deckBattleParticipantIDs = []
        state = .readyToBattle
    }

    func endBattle(winner: Monster, deckStore: DeckStore? = nil) {
        var resolvedWinner = winner
        battleReward = nil

        if battleContext == .deckVersusAI,
           deckBattleParticipantIDs.contains(winner.id) {
            let upgradedMonster = winner.awardingVictoryExperience(playerVictoryExperience)
            _ = deckStore?.updateMonster(upgradedMonster)
            if monsters.first?.id == upgradedMonster.id {
                monsters[0] = upgradedMonster
            }
            if reserveMonster?.id == upgradedMonster.id {
                reserveMonster = upgradedMonster
            }
            resolvedWinner = upgradedMonster
            battleReward = BattleReward(
                monsterID: upgradedMonster.id,
                experienceGained: playerVictoryExperience,
                levelsGained: upgradedMonster.level - winner.level
            )
        }

        state = .result(resolvedWinner)
    }

    func updateArtworkPreference(_ preference: ArtworkPreference, for monsterID: Monster.ID) {
        guard let index = monsters.firstIndex(where: { $0.id == monsterID }) else { return }

        let updatedMonster = monsters[index].preferringArtwork(preference)
        monsters[index] = updatedMonster

        if reserveMonster?.id == monsterID {
            reserveMonster = updatedMonster
        }

        switch state {
        case .showCard(let monster) where monster.id == monsterID:
            state = .showCard(updatedMonster)
        case .result(let monster) where monster.id == monsterID:
            state = .result(updatedMonster)
        default:
            break
        }
    }

    func resetMonsters() {
        monsters = []
        diagnostics = nil
        battleReward = nil
        reserveMonster = nil
        battleContext = .none
        deckBattleParticipantIDs = []
        state = .idle
    }
}
