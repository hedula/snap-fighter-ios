import SwiftUI
import Combine

@MainActor
class GameViewModel: ObservableObject {
    typealias MonsterAnalyzer = (UIImage) async throws -> AnalysisResult
    typealias ProgressiveMonsterAnalyzer = (
        UIImage,
        @escaping AIService.ProgressHandler
    ) async throws -> AnalysisResult
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
    @Published var analysisProgress: MonsterAnalysisProgress? = nil
    @Published private(set) var lastCaptureImage: UIImage? = nil
    @Published private(set) var battleReward: BattleReward? = nil
    @Published private(set) var reserveMonster: Monster? = nil
    private let analyzeMonster: ProgressiveMonsterAnalyzer
    private let generateAIOpponent: AIOpponentGenerator
    private let makeStarterDeck: StarterDeckFactory
    private var battleContext: BattleContext = .none
    private var deckBattleParticipantIDs: Set<Monster.ID> = []
    private let playerVictoryExperience = 40
    private var activeCaptureAttemptID = UUID()
    private var manualCutoutImage: UIImage? = nil

    init(
        progressiveAnalyzeMonster: @escaping ProgressiveMonsterAnalyzer = { image, onProgress in
            try await AIService.shared.analyze(image: image, onProgress: onProgress)
        },
        generateAIOpponent: AIOpponentGenerator? = nil,
        makeStarterDeck: StarterDeckFactory? = nil
    ) {
        self.analyzeMonster = progressiveAnalyzeMonster
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

    convenience init(
        analyzeMonster: @escaping MonsterAnalyzer,
        generateAIOpponent: AIOpponentGenerator? = nil,
        makeStarterDeck: StarterDeckFactory? = nil
    ) {
        self.init(
            progressiveAnalyzeMonster: { image, _ in
                try await analyzeMonster(image)
            },
            generateAIOpponent: generateAIOpponent,
            makeStarterDeck: makeStarterDeck
        )
    }

    func captureMonster(from image: UIImage) async {
        let attemptID = UUID()
        activeCaptureAttemptID = attemptID
        lastCaptureImage = image
        manualCutoutImage = nil
        isLoading = true
        errorMessage = nil
        battleReward = nil
        analysisProgress = .init(phase: .preparing, sourceImage: image, cutoutImage: nil)
        state = .analyzing
        do {
            let result = try await analyzeMonster(image) { [weak self] progress in
                guard let self, self.activeCaptureAttemptID == attemptID else { return }
                self.analysisProgress = .init(
                    phase: progress.phase,
                    sourceImage: progress.sourceImage,
                    cutoutImage: progress.cutoutImage ?? self.manualCutoutImage
                )
            }
            guard activeCaptureAttemptID == attemptID else { return }
            diagnostics = result.diagnostics
            let resolvedMonster = manualCutoutImage.map { result.monster.replacingCardImage($0) } ?? result.monster
            monsters.append(resolvedMonster)
            battleContext = .captured
            reserveMonster = nil
            deckBattleParticipantIDs = []
            state = monsters.count >= 2 ? .readyToBattle : .showCard(resolvedMonster)
        } catch {
            guard activeCaptureAttemptID == attemptID else { return }
            errorMessage = error.localizedDescription
            state = .idle
        }
        if activeCaptureAttemptID == attemptID {
            isLoading = false
        }
    }

    func retryLastCapture() async {
        guard let lastCaptureImage else { return }
        await captureMonster(from: lastCaptureImage)
    }

    func cancelAnalysis() {
        activeCaptureAttemptID = UUID()
        analysisProgress = nil
        lastCaptureImage = nil
        isLoading = false
        state = .idle
    }

    func applyManualCutout(_ image: UIImage) {
        manualCutoutImage = image

        if let progress = analysisProgress {
            analysisProgress = .init(
                phase: progress.phase,
                sourceImage: progress.sourceImage,
                cutoutImage: image
            )
        }

        guard let lastIndex = monsters.indices.last else { return }
        let updatedMonster = monsters[lastIndex].replacingCardImage(image)
        monsters[lastIndex] = updatedMonster

        switch state {
        case .showCard(let monster) where monster.id == updatedMonster.id:
            state = .showCard(updatedMonster)
        case .readyToBattle:
            break
        default:
            break
        }
    }

    func startBattle() {
        state = .battling
    }

    func prepareBattle(with monsters: [Monster]) {
        guard monsters.count == 2 else { return }
        self.monsters = monsters.map { $0.resetForBattle() }
        diagnostics = nil
        analysisProgress = nil
        lastCaptureImage = nil
        manualCutoutImage = nil
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
        analysisProgress = nil
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
        analysisProgress = nil
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
        analysisProgress = nil
        lastCaptureImage = nil
        battleReward = nil
        reserveMonster = nil
        battleContext = .none
        deckBattleParticipantIDs = []
        state = .idle
    }
}
