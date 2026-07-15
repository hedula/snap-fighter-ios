import Foundation
import UIKit
import Combine

enum ArtworkPreference: String, Codable {
    case original
    case cutout
}

enum BattleSkillType: String, Codable, CaseIterable {
    case powerStrike
    case fortify
    case siphonStrike

    init(apiValue: String?, skillName: String) {
        if let apiValue, let type = BattleSkillType(rawValue: apiValue) {
            self = type
            return
        }

        let defensiveKeywords = ["盾", "守", "護", "障", "壁"]
        if defensiveKeywords.contains(where: { skillName.contains($0) }) {
            self = .fortify
            return
        }

        let siphonKeywords = ["吸", "癒", "治", "生", "根", "潮"]
        if siphonKeywords.contains(where: { skillName.contains($0) }) {
            self = .siphonStrike
            return
        }

        self = .powerStrike
    }

    var reserveEntryHint: String {
        switch self {
        case .powerStrike:
            return "進場增傷"
        case .fortify:
            return "進場防禦"
        case .siphonStrike:
            return "進場回復"
        }
    }
}

struct Monster: Identifiable {
    let id: UUID
    let name: String
    let element: Element
    let hp: Int
    let atk: Int
    let def: Int
    let skill: String
    let skillType: BattleSkillType
    let capturedImage: UIImage?
    let cardImage: UIImage?
    let preferredArtwork: ArtworkPreference
    let level: Int
    let experience: Int
    var currentHp: Int

    init(
        id: UUID = UUID(),
        name: String,
        element: Element,
        hp: Int,
        atk: Int,
        def: Int,
        skill: String,
        skillType: BattleSkillType? = nil,
        capturedImage: UIImage? = nil,
        cardImage: UIImage? = nil,
        preferredArtwork: ArtworkPreference? = nil,
        level: Int = 1,
        experience: Int = 0,
        currentHp: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.element = element
        self.hp = hp
        self.atk = atk
        self.def = def
        self.skill = skill
        self.skillType = skillType ?? BattleSkillType(apiValue: nil, skillName: skill)
        self.capturedImage = capturedImage
        self.cardImage = cardImage
        self.preferredArtwork = preferredArtwork ?? (cardImage != nil ? .cutout : .original)
        self.level = max(1, level)
        self.experience = max(0, experience)
        self.currentHp = currentHp ?? hp
    }

    init(from decoded: MonsterResponse, capturedImage: UIImage? = nil, cardImage: UIImage? = nil) {
        self.init(
            name: decoded.name,
            element: Element(rawValue: decoded.element) ?? .normal,
            hp: decoded.hp,
            atk: decoded.atk,
            def: decoded.def,
            skill: decoded.skill,
            skillType: BattleSkillType(apiValue: decoded.skillType, skillName: decoded.skill),
            capturedImage: capturedImage,
            cardImage: cardImage
        )
    }

    var deckSignature: String {
        [name, element.rawValue, "\(hp)", "\(atk)", "\(def)", skill]
            .joined(separator: "|")
    }

    var experienceNeededForNextLevel: Int {
        100 + max(0, level - 1) * 40
    }

    var experienceProgressText: String {
        "\(experience)/\(experienceNeededForNextLevel)"
    }

    var displayArtwork: UIImage? {
        switch preferredArtwork {
        case .original:
            return capturedImage ?? cardImage
        case .cutout:
            return cardImage ?? capturedImage
        }
    }

    func awardingVictoryExperience(_ amount: Int) -> Monster {
        guard amount > 0 else { return self }

        var nextLevel = level
        var nextExperience = experience + amount
        var nextHP = hp
        var nextATK = atk
        var nextDEF = def

        while nextExperience >= (100 + max(0, nextLevel - 1) * 40) {
            let threshold = 100 + max(0, nextLevel - 1) * 40
            nextExperience -= threshold
            nextLevel += 1
            nextHP += 8
            nextATK += 4
            nextDEF += 3
        }

        return Monster(
            id: id,
            name: name,
            element: element,
            hp: nextHP,
            atk: nextATK,
            def: nextDEF,
            skill: skill,
            skillType: skillType,
            capturedImage: capturedImage,
            cardImage: cardImage,
            preferredArtwork: preferredArtwork,
            level: nextLevel,
            experience: nextExperience,
            currentHp: currentHp
        )
    }

    func preferringArtwork(_ preference: ArtworkPreference) -> Monster {
        Monster(
            id: id,
            name: name,
            element: element,
            hp: hp,
            atk: atk,
            def: def,
            skill: skill,
            skillType: skillType,
            capturedImage: capturedImage,
            cardImage: cardImage,
            preferredArtwork: preference,
            level: level,
            experience: experience,
            currentHp: currentHp
        )
    }
}

enum Element: String, Codable, CaseIterable {
    case fire = "火"
    case water = "水"
    case grass = "草"
    case electric = "電"
    case dark = "暗"
    case normal = "一般"

    var gradientColors: [String] {
        switch self {
        case .fire:     return ["FF4500", "FF8C00"]
        case .water:    return ["1E90FF", "00CED1"]
        case .grass:    return ["228B22", "7CFC00"]
        case .electric: return ["FFD700", "FFA500"]
        case .dark:     return ["2D1B4E", "6A0DAD"]
        case .normal:   return ["708090", "A9A9A9"]
        }
    }

    func battleMultiplier(against defender: Element) -> Double {
        if hasAdvantage(over: defender) {
            return 1.25
        }

        if defender.hasAdvantage(over: self) {
            return 0.85
        }

        return 1.0
    }

    func effectivenessText(against defender: Element) -> String? {
        if hasAdvantage(over: defender) {
            return "效果絕佳。"
        }

        if defender.hasAdvantage(over: self) {
            return "效果普通偏弱。"
        }

        return nil
    }

    private func hasAdvantage(over defender: Element) -> Bool {
        switch (self, defender) {
        case (.fire, .grass),
             (.water, .fire),
             (.grass, .water),
             (.electric, .water),
             (.dark, .normal):
            return true
        default:
            return false
        }
    }
}

struct AIOpponentFactory {
    static func makeOpponent(against deck: [Monster]) -> Monster {
        let anchor = deck.max(by: { ($0.atk + $0.def + $0.hp) < ($1.atk + $1.def + $1.hp) }) ?? Monster(
            name: "預設訓練體",
            element: .normal,
            hp: 70,
            atk: 55,
            def: 40,
            skill: "基礎衝撞"
        )

        let elements = Element.allCases.filter { $0 != anchor.element }
        let chosenElement = elements.randomElement() ?? .dark
        let hp = min(99, max(50, anchor.hp + Int.random(in: -8...12)))
        let atk = min(95, max(35, anchor.atk + Int.random(in: -6...10)))
        let def = min(95, max(30, anchor.def + Int.random(in: -6...10)))

        return Monster(
            name: opponentName(for: chosenElement),
            element: chosenElement,
            hp: hp,
            atk: atk,
            def: def,
            skill: opponentSkill(for: chosenElement)
        )
    }

    private static func opponentName(for element: Element) -> String {
        switch element {
        case .fire: return "炎燈先鋒"
        case .water: return "潮瓶守衛"
        case .grass: return "苔瓶獵手"
        case .electric: return "雷鎧兵"
        case .dark: return "夜鈴魔偶"
        case .normal: return "銀鈴守衛"
        }
    }

    private static func opponentSkill(for element: Element) -> String {
        switch element {
        case .fire: return "熔火爆裂"
        case .water: return "潮汐震盪"
        case .grass: return "纏根絞擊"
        case .electric: return "雷磁衝鋒"
        case .dark: return "月蝕干擾"
        case .normal: return "共鳴衝擊"
        }
    }
}

struct MonsterResponse: Codable {
    let name: String
    let element: String
    let hp: Int
    let atk: Int
    let def: Int
    let skill: String
    let skillType: String?

    init(
        name: String,
        element: String,
        hp: Int,
        atk: Int,
        def: Int,
        skill: String,
        skillType: String? = nil
    ) {
        self.name = name
        self.element = element
        self.hp = hp
        self.atk = atk
        self.def = def
        self.skill = skill
        self.skillType = skillType
    }
}

struct StoredMonster: Codable {
    let id: UUID
    let name: String
    let element: String
    let hp: Int
    let atk: Int
    let def: Int
    let skill: String
    let skillType: String
    let imageJPEGData: Data?
    let cardImageJPEGData: Data?
    let preferredArtwork: String
    let level: Int
    let experience: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case element
        case hp
        case atk
        case def
        case skill
        case skillType
        case imageJPEGData
        case cardImageJPEGData
        case preferredArtwork
        case level
        case experience
    }

    init(
        id: UUID,
        name: String,
        element: String,
        hp: Int,
        atk: Int,
        def: Int,
        skill: String,
        skillType: String,
        imageJPEGData: Data?,
        cardImageJPEGData: Data?,
        preferredArtwork: String,
        level: Int,
        experience: Int
    ) {
        self.id = id
        self.name = name
        self.element = element
        self.hp = hp
        self.atk = atk
        self.def = def
        self.skill = skill
        self.skillType = skillType
        self.imageJPEGData = imageJPEGData
        self.cardImageJPEGData = cardImageJPEGData
        self.preferredArtwork = preferredArtwork
        self.level = level
        self.experience = experience
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        element = try container.decode(String.self, forKey: .element)
        hp = try container.decode(Int.self, forKey: .hp)
        atk = try container.decode(Int.self, forKey: .atk)
        def = try container.decode(Int.self, forKey: .def)
        skill = try container.decode(String.self, forKey: .skill)
        skillType = try container.decodeIfPresent(String.self, forKey: .skillType)
            ?? BattleSkillType(apiValue: nil, skillName: skill).rawValue
        imageJPEGData = try container.decodeIfPresent(Data.self, forKey: .imageJPEGData)
        cardImageJPEGData = try container.decodeIfPresent(Data.self, forKey: .cardImageJPEGData)
        preferredArtwork = try container.decodeIfPresent(String.self, forKey: .preferredArtwork)
            ?? (cardImageJPEGData != nil ? ArtworkPreference.cutout.rawValue : ArtworkPreference.original.rawValue)
        level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 1
        experience = try container.decodeIfPresent(Int.self, forKey: .experience) ?? 0
    }
}

extension Monster {
    func resetForBattle() -> Monster {
        Monster(
            id: id,
            name: name,
            element: element,
            hp: hp,
            atk: atk,
            def: def,
            skill: skill,
            skillType: skillType,
            capturedImage: capturedImage,
            cardImage: cardImage,
            preferredArtwork: preferredArtwork,
            level: level,
            experience: experience,
            currentHp: hp
        )
    }

    init(stored: StoredMonster) {
        self.init(
            id: stored.id,
            name: stored.name,
            element: Element(rawValue: stored.element) ?? .normal,
            hp: stored.hp,
            atk: stored.atk,
            def: stored.def,
            skill: stored.skill,
            skillType: BattleSkillType(apiValue: stored.skillType, skillName: stored.skill),
            capturedImage: stored.imageJPEGData.flatMap(UIImage.init(data:)),
            cardImage: stored.cardImageJPEGData.flatMap(UIImage.init(data:)),
            preferredArtwork: ArtworkPreference(rawValue: stored.preferredArtwork),
            level: stored.level,
            experience: stored.experience,
            currentHp: stored.hp
        )
    }

    var stored: StoredMonster {
        StoredMonster(
            id: id,
            name: name,
            element: element.rawValue,
            hp: hp,
            atk: atk,
            def: def,
            skill: skill,
            skillType: skillType.rawValue,
            imageJPEGData: capturedImage?.jpegData(compressionQuality: 0.82),
            cardImageJPEGData: cardImage?.jpegData(compressionQuality: 0.9),
            preferredArtwork: preferredArtwork.rawValue,
            level: level,
            experience: experience
        )
    }
}

@MainActor
final class DeckStore: ObservableObject {
    @Published private(set) var deck: [Monster] = []
    @Published private(set) var activeBattleDeckIDs: [Monster.ID] = []

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let activeDeckStorageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "snap_fighter.deck",
        activeDeckStorageKey: String = "snap_fighter.active_battle_deck"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.activeDeckStorageKey = activeDeckStorageKey
        load()
    }

    func contains(_ monster: Monster) -> Bool {
        deck.contains { $0.deckSignature == monster.deckSignature }
    }

    var activeBattleDeck: [Monster] {
        activeBattleDeckIDs.compactMap { id in
            deck.first(where: { $0.id == id })
        }
    }

    func isInActiveBattleDeck(_ monster: Monster) -> Bool {
        activeBattleDeckIDs.contains(monster.id)
    }

    @discardableResult
    func addToDeck(_ monster: Monster) -> Bool {
        guard !contains(monster) else { return false }
        deck.append(monster)
        persist()
        return true
    }

    func removeFromDeck(id: Monster.ID) {
        deck.removeAll { $0.id == id }
        activeBattleDeckIDs.removeAll { $0 == id }
        persist()
    }

    @discardableResult
    func updateMonster(_ monster: Monster) -> Bool {
        guard let index = deck.firstIndex(where: { $0.id == monster.id }) else { return false }
        deck[index] = monster
        persist()
        return true
    }

    @discardableResult
    func toggleActiveBattleDeck(_ monster: Monster) -> Bool {
        guard deck.contains(where: { $0.id == monster.id }) else { return false }

        if let index = activeBattleDeckIDs.firstIndex(of: monster.id) {
            activeBattleDeckIDs.remove(at: index)
            persist()
            return true
        }

        guard activeBattleDeckIDs.count < 2 else { return false }
        activeBattleDeckIDs.append(monster.id)
        persist()
        return true
    }

    private func load() {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let stored = try? decoder.decode([StoredMonster].self, from: data)
        else {
            deck = []
            activeBattleDeckIDs = []
            return
        }

        deck = stored.map(Monster.init(stored:))
        loadActiveBattleDeckIDs()
    }

    private func persist() {
        guard let data = try? encoder.encode(deck.map(\.stored)) else { return }
        userDefaults.set(data, forKey: storageKey)
        userDefaults.set(activeBattleDeckIDs.map(\.uuidString), forKey: activeDeckStorageKey)
    }

    private func loadActiveBattleDeckIDs() {
        let validIDs = Set(deck.map(\.id))
        let storedIDs = (userDefaults.array(forKey: activeDeckStorageKey) as? [String] ?? [])
            .compactMap(UUID.init(uuidString:))
            .filter { validIDs.contains($0) }
        activeBattleDeckIDs = Array(storedIDs.prefix(2))
    }
}
