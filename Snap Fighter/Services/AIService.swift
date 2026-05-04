import UIKit
import Foundation

@MainActor
final class AIService {
    static let shared = AIService()

    func analyze(image: UIImage) async throws -> Monster {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AIError.imageConversionFailed
        }

        guard let url = URL(string: Config.workerAnalyzeEndpoint) else {
            throw AIError.invalidEndpoint
        }

        let payload: [String: Any] = [
            "imageBase64": imageData.base64EncodedString()
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let message = Self.extractErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw AIError.apiError(message)
        }

        do {
            let monsterResponse = try JSONDecoder().decode(MonsterResponse.self, from: data)
            return Monster(from: monsterResponse, capturedImage: image)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 payload>"
            throw AIError.decodingFailed(raw)
        }
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = json["error"] as? String
        else {
            return nil
        }
        return message
    }

    func analyzeMock(image: UIImage) async -> Monster {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let response = MonsterResponse(
            name: "神秘馬克杯",
            element: "火",
            hp: 75,
            atk: 60,
            def: 35,
            skill: "沸騰之力：發動時使對方陷入灼燒狀態"
        )
        return Monster(from: response, capturedImage: image)
    }
}

enum AIError: LocalizedError {
    case imageConversionFailed
    case invalidEndpoint
    case invalidResponse
    case apiError(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "圖片處理失敗"
        case .invalidEndpoint:       return "Worker API 位址設定錯誤"
        case .invalidResponse:       return "Worker 回傳格式錯誤"
        case .apiError(let message): return "API 錯誤：\(message)"
        case .decodingFailed(let s): return "解析失敗：\(s)"
        }
    }
}
