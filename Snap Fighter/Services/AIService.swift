import UIKit
import Foundation

struct AIDiagnostics: Equatable {
    let provider: String
    let model: String
}

struct AnalysisResult {
    let monster: Monster
    let diagnostics: AIDiagnostics?
}

@MainActor
final class AIService {
    static let shared = AIService()
    static let uploadMaxPixelSize: CGFloat = 1_536
    static let uploadCompressionQuality: CGFloat = 0.72

    typealias ForegroundIsolator = (UIImage) async -> UIImage?

    private let isolateForeground: ForegroundIsolator

    init(
        isolateForeground: @escaping ForegroundIsolator = { image in
            await ForegroundIsolationService.shared.isolateSubject(from: image)
        }
    ) {
        self.isolateForeground = isolateForeground
    }

    func analyze(image: UIImage) async throws -> AnalysisResult {
        guard let imageData = Self.makeUploadImageData(from: image) else {
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
            let diagnostics = Self.extractDiagnostics(from: httpResponse)
            let cardImage = await isolateForeground(image)
            return AnalysisResult(
                monster: Monster(from: monsterResponse, capturedImage: image, cardImage: cardImage),
                diagnostics: diagnostics
            )
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

    static func makeUploadImageData(from image: UIImage) -> Data? {
        let preparedImage = image.resizedForUpload(maxPixelSize: uploadMaxPixelSize)
        return preparedImage.jpegData(compressionQuality: uploadCompressionQuality)
    }

    func analyzeMock(image: UIImage) async -> AnalysisResult {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let response = MonsterResponse(
            name: "神秘馬克杯",
            element: "火",
            hp: 75,
            atk: 60,
            def: 35,
            skill: "沸騰之力：發動時使對方陷入灼燒狀態",
            skillType: BattleSkillType.powerStrike.rawValue
        )
        let cardImage = await isolateForeground(image)
        return AnalysisResult(
            monster: Monster(from: response, capturedImage: image, cardImage: cardImage),
            diagnostics: AIDiagnostics(provider: "mock", model: "local-preview")
        )
    }

    private static func extractDiagnostics(from response: HTTPURLResponse) -> AIDiagnostics? {
        guard
            let provider = response.value(forHTTPHeaderField: "X-AI-Provider"),
            let model = response.value(forHTTPHeaderField: "X-AI-Model")
        else {
            return nil
        }

        return AIDiagnostics(provider: provider, model: model)
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

private extension UIImage {
    func resizedForUpload(maxPixelSize: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxPixelSize, longestSide > 0 else {
            return self
        }

        let scale = maxPixelSize / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
