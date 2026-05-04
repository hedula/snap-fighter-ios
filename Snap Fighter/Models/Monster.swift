import Foundation
import UIKit

struct Monster: Identifiable {
    let id: UUID
    let name: String
    let element: Element
    let hp: Int
    let atk: Int
    let def: Int
    let skill: String
    let capturedImage: UIImage?
    var currentHp: Int

    init(from decoded: MonsterResponse, capturedImage: UIImage? = nil) {
        self.id = UUID()
        self.name = decoded.name
        self.element = Element(rawValue: decoded.element) ?? .normal
        self.hp = decoded.hp
        self.currentHp = decoded.hp
        self.atk = decoded.atk
        self.def = decoded.def
        self.skill = decoded.skill
        self.capturedImage = capturedImage
    }
}

enum Element: String, Codable {
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
}

struct MonsterResponse: Codable {
    let name: String
    let element: String
    let hp: Int
    let atk: Int
    let def: Int
    let skill: String
}
