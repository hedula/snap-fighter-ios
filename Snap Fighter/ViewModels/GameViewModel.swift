import SwiftUI
import Combine

@MainActor
class GameViewModel: ObservableObject {

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
    @Published var isLoading = false

    func captureMonster(from image: UIImage) async {
        isLoading = true
        state = .analyzing
        do {
            let monster = try await AIService.shared.analyze(image: image)
            monsters.append(monster)
            state = monsters.count >= 2 ? .readyToBattle : .showCard(monster)
        } catch {
            errorMessage = error.localizedDescription
            state = .idle
        }
        isLoading = false
    }

    func startBattle() {
        state = .battling
    }

    func endBattle(winner: Monster) {
        state = .result(winner)
    }

    func resetMonsters() {
        monsters = []
        state = .idle
    }
}
