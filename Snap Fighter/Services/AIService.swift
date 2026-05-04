import UIKit
import Foundation

@MainActor
final class AIService {
    static let shared = AIService()

    private let systemPrompt = """
        你是一個奇幻角色生成器。
        分析圖片中最明顯的物體，將它擬人化為一個戰鬥角色。
        只回傳 JSON，不要有任何其他文字、說明或 markdown 標記。
        JSON 格式如下：
        {
          "name": "角色名稱（中文，有創意，2~6字）",
          "element": "火｜水｜草｜電｜暗｜一般 其中一種",
          "hp": 整數 50 到 100,
          "atk": 整數 30 到 80,
          "def": 整數 20 到 60,
          "skill": "技能名稱與一句話描述（中文，10~20字）"
        }
        """

    func analyze(image: UIImage) async throws -> Monster {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AIError.imageConversionFailed
        }
        let base64Image = imageData.base64EncodedString()

        let requestBody: [String: Any] = [
            "model": Config.model,
            "max_tokens": 300,
            "temperature": 0.8,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        guard let url = URL(string: Config.openAIEndpoint) else {
            throw AIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let message = Self.extractAPIErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw AIError.apiError(message)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.invalidResponse
        }
        guard
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = Self.extractMessageContent(from: message)
        else {
            throw AIError.invalidResponse
        }

        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw AIError.decodingFailed(cleaned)
        }
        do {
            let monsterResponse = try JSONDecoder().decode(MonsterResponse.self, from: jsonData)
            return Monster(from: monsterResponse)
        } catch {
            throw AIError.decodingFailed(cleaned)
        }
    }

    private static func extractMessageContent(from message: [String: Any]) -> String? {
        if let text = message["content"] as? String {
            return text
        }
        if
            let blocks = message["content"] as? [[String: Any]],
            let firstText = blocks.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String
        {
            return firstText
        }
        return nil
    }

    private static func extractAPIErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = json["error"] as? [String: Any],
            let message = error["message"] as? String
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
        return Monster(from: response)
    }
}

enum AIError: LocalizedError {
    case imageConversionFailed
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:  return "圖片處理失敗"
        case .networkError(let e):    return "網路錯誤：\(e.localizedDescription)"
        case .invalidResponse:        return "API 回傳格式錯誤"
        case .apiError(let message):  return "API 錯誤：\(message)"
        case .decodingFailed(let s):  return "解析失敗：\(s)"
        }
    }
}
