import UIKit
import Foundation
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AIDiagnostics: Equatable {
    let provider: String
    let model: String
}

struct AnalysisResult {
    let monster: Monster
    let diagnostics: AIDiagnostics?
}

enum MonsterAnalysisPhase: Int, CaseIterable, Equatable {
    case preparing
    case detectingSubject
    case removingBackground
    case generatingCard

    var title: String {
        switch self {
        case .preparing: return "校準召喚影像"
        case .detectingSubject: return "鎖定物件輪廓"
        case .removingBackground: return "移除影像背景"
        case .generatingCard: return "生成戰鬥卡牌"
        }
    }

    var detail: String {
        switch self {
        case .preparing: return "正在調整尺寸與方向"
        case .detectingSubject: return "Vision 正在辨識前景物件"
        case .removingBackground: return "建立透明遮罩並保留主體"
        case .generatingCard: return "同步怪物資料與卡面內容"
        }
    }

    var progress: Double {
        switch self {
        case .preparing: return 0.12
        case .detectingSubject: return 0.34
        case .removingBackground: return 0.62
        case .generatingCard: return 0.86
        }
    }

    var systemImage: String {
        switch self {
        case .preparing: return "camera.filters"
        case .detectingSubject: return "viewfinder"
        case .removingBackground: return "person.crop.rectangle"
        case .generatingCard: return "rectangle.stack.badge.plus"
        }
    }
}

struct MonsterAnalysisProgress {
    let phase: MonsterAnalysisPhase
    let sourceImage: UIImage
    let cutoutImage: UIImage?
}

typealias MonsterAnalysisProgressHandler = @MainActor (MonsterAnalysisProgress) -> Void

@MainActor
protocol MonsterAnalyzing {
    func analyze(image: UIImage, onProgress: @escaping MonsterAnalysisProgressHandler) async throws -> AnalysisResult
}

@MainActor
final class AIService {
    static let shared = AIService()
    static let uploadMaxPixelSize: CGFloat = 1_536
    static let uploadCompressionQuality: CGFloat = 0.72

    typealias ForegroundIsolator = (UIImage) async -> UIImage?
    typealias ProgressHandler = MonsterAnalysisProgressHandler

    private let isolateForeground: ForegroundIsolator
    private let providerMode: AIProvider

    init(
        providerMode: AIProvider? = nil,
        isolateForeground: @escaping ForegroundIsolator = { image in
            await ForegroundIsolationService.shared.isolateSubject(from: image)
        }
    ) {
        self.providerMode = providerMode ?? Config.aiProvider
        self.isolateForeground = isolateForeground
    }

    func analyze(image: UIImage) async throws -> AnalysisResult {
        try await analyze(image: image, onProgress: { _ in })
    }

    func analyze(
        image: UIImage,
        onProgress: @escaping ProgressHandler
    ) async throws -> AnalysisResult {
        switch providerMode {
        case .auto:
            if AppleLocalMonsterAnalyzer.isAvailable {
                do {
                    return try await AppleLocalMonsterAnalyzer(isolateForeground: isolateForeground)
                        .analyze(image: image, onProgress: onProgress)
                } catch AIError.localModelUnavailable(_) {
                    do {
                        return try await WorkerMonsterAnalyzer(isolateForeground: isolateForeground)
                            .analyze(image: image, onProgress: onProgress)
                    } catch AIError.accessProtected {
                        return try await MockMonsterAnalyzer(isolateForeground: isolateForeground)
                            .analyze(image: image, onProgress: onProgress)
                    }
                }
            }

            do {
                return try await WorkerMonsterAnalyzer(isolateForeground: isolateForeground)
                    .analyze(image: image, onProgress: onProgress)
            } catch AIError.accessProtected {
                return try await MockMonsterAnalyzer(isolateForeground: isolateForeground)
                    .analyze(image: image, onProgress: onProgress)
            }
        case .appleLocal:
            return try await AppleLocalMonsterAnalyzer(isolateForeground: isolateForeground)
                .analyze(image: image, onProgress: onProgress)
        case .worker:
            return try await WorkerMonsterAnalyzer(isolateForeground: isolateForeground)
                .analyze(image: image, onProgress: onProgress)
        case .mock:
            return try await MockMonsterAnalyzer(isolateForeground: isolateForeground)
                .analyze(image: image, onProgress: onProgress)
        }
    }

    func analyzeMock(image: UIImage) async -> AnalysisResult {
        (try? await MockMonsterAnalyzer(isolateForeground: isolateForeground).analyze(image: image, onProgress: { _ in })) ?? AnalysisResult(
            monster: Monster(
                name: "熔核馬克杯魔將",
                element: .fire,
                hp: 75,
                atk: 60,
                def: 35,
                skill: "沸騰杯焰衝擊",
                skillType: .powerStrike,
                capturedImage: image
            ),
            diagnostics: AIDiagnostics(provider: "mock", model: "local-preview")
        )
    }

    static func extractErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = json["error"] as? String
        else {
            return nil
        }
        return message
    }

    static func isCloudflareAccessPayload(
        data: Data,
        contentType: String?,
        authenticateHeader: String?
    ) -> Bool {
        if authenticateHeader?.localizedCaseInsensitiveContains("cloudflare-access") == true {
            return true
        }

        let isHTML = contentType?.localizedCaseInsensitiveContains("text/html") == true
        guard isHTML, let text = String(data: data, encoding: .utf8) else {
            return false
        }

        return text.localizedCaseInsensitiveContains("Cloudflare Access")
            || text.localizedCaseInsensitiveContains("/cdn-cgi/access/login")
    }

    static func decodingFailureSummary(from data: Data, contentType: String?) -> String {
        if contentType?.localizedCaseInsensitiveContains("text/html") == true {
            return "伺服器回傳 HTML 頁面，不是怪物 JSON"
        }

        let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 payload>"
        let compact = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard compact.count > 240 else {
            return compact.isEmpty ? "空白回應" : compact
        }

        return "\(compact.prefix(240))..."
    }

    static func makeUploadImageData(from image: UIImage) -> Data? {
        let preparedImage = image.resizedForUpload(maxPixelSize: uploadMaxPixelSize)
        return preparedImage.jpegData(compressionQuality: uploadCompressionQuality)
    }

    fileprivate static func extractDiagnostics(from response: HTTPURLResponse) -> AIDiagnostics? {
        guard
            let provider = response.value(forHTTPHeaderField: "X-AI-Provider"),
            let model = response.value(forHTTPHeaderField: "X-AI-Model")
        else {
            return nil
        }

        return AIDiagnostics(provider: provider, model: model)
    }
}

@MainActor
private struct WorkerMonsterAnalyzer: MonsterAnalyzing {
    let isolateForeground: AIService.ForegroundIsolator

    func analyze(
        image: UIImage,
        onProgress: @escaping MonsterAnalysisProgressHandler
    ) async throws -> AnalysisResult {
        onProgress(.init(phase: .preparing, sourceImage: image, cutoutImage: nil))

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
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let networkRequest = request

        onProgress(.init(phase: .detectingSubject, sourceImage: image, cutoutImage: nil))
        async let foregroundImage = isolateForeground(image)
        async let networkResponse = URLSession.shared.data(for: networkRequest)

        await Task.yield()
        onProgress(.init(phase: .removingBackground, sourceImage: image, cutoutImage: nil))
        let cardImage = await foregroundImage
        onProgress(.init(phase: .generatingCard, sourceImage: image, cutoutImage: cardImage))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await networkResponse
        } catch let error as URLError where error.code == .timedOut {
            throw AIError.analysisTimedOut
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if Self.isCloudflareAccessResponse(data: data, response: httpResponse) {
                throw AIError.accessProtected
            }
            let message = Self.extractErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw AIError.apiError(message)
        }

        if Self.isCloudflareAccessResponse(data: data, response: httpResponse) {
            throw AIError.accessProtected
        }

        do {
            let monsterResponse = try JSONDecoder().decode(MonsterResponse.self, from: data)
            let diagnostics = Self.extractDiagnostics(from: httpResponse)
            return AnalysisResult(
                monster: Monster(from: monsterResponse, capturedImage: image, cardImage: cardImage),
                diagnostics: diagnostics
            )
        } catch {
            throw AIError.decodingFailed(Self.decodingFailureSummary(from: data, response: httpResponse))
        }
    }

    private static func makeUploadImageData(from image: UIImage) -> Data? {
        AIService.makeUploadImageData(from: image)
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        AIService.extractErrorMessage(from: data)
    }

    private static func isCloudflareAccessResponse(data: Data, response: HTTPURLResponse) -> Bool {
        AIService.isCloudflareAccessPayload(
            data: data,
            contentType: response.value(forHTTPHeaderField: "Content-Type"),
            authenticateHeader: response.value(forHTTPHeaderField: "WWW-Authenticate")
        )
    }

    private static func decodingFailureSummary(from data: Data, response: HTTPURLResponse) -> String {
        AIService.decodingFailureSummary(
            from: data,
            contentType: response.value(forHTTPHeaderField: "Content-Type")
        )
    }

    private static func extractDiagnostics(from response: HTTPURLResponse) -> AIDiagnostics? {
        AIService.extractDiagnostics(from: response)
    }
}

@MainActor
private struct MockMonsterAnalyzer: MonsterAnalyzing {
    let isolateForeground: AIService.ForegroundIsolator

    func analyze(
        image: UIImage,
        onProgress: @escaping MonsterAnalysisProgressHandler
    ) async throws -> AnalysisResult {
        onProgress(.init(phase: .preparing, sourceImage: image, cutoutImage: nil))
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        onProgress(.init(phase: .detectingSubject, sourceImage: image, cutoutImage: nil))
        let cardImage = await isolateForeground(image)
        onProgress(.init(phase: .generatingCard, sourceImage: image, cutoutImage: cardImage))

        let response = MonsterResponse(
            name: "熔核馬克杯魔將",
            element: "火",
            hp: 75,
            atk: 60,
            def: 35,
            skill: "沸騰杯焰衝擊",
            skillType: BattleSkillType.powerStrike.rawValue
        )

        return AnalysisResult(
            monster: Monster(from: response, capturedImage: image, cardImage: cardImage),
            diagnostics: AIDiagnostics(provider: "mock", model: "local-preview")
        )
    }
}

@MainActor
private struct AppleLocalMonsterAnalyzer: MonsterAnalyzing {
    let isolateForeground: AIService.ForegroundIsolator

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return AppleFoundationModelsMonsterGenerator.isAvailable
        }
        #endif
        return false
    }

    func analyze(
        image: UIImage,
        onProgress: @escaping MonsterAnalysisProgressHandler
    ) async throws -> AnalysisResult {
        guard Self.isAvailable else {
            throw AIError.localModelUnavailable("Apple Foundation Models is not available on this device.")
        }

        onProgress(.init(phase: .preparing, sourceImage: image, cutoutImage: nil))
        async let labels = Self.classifyImage(image)
        async let cardImage = isolateForeground(image)

        onProgress(.init(phase: .detectingSubject, sourceImage: image, cutoutImage: nil))
        let imageLabels = await labels
        onProgress(.init(phase: .removingBackground, sourceImage: image, cutoutImage: nil))
        let resolvedCardImage = await cardImage
        onProgress(.init(phase: .generatingCard, sourceImage: image, cutoutImage: resolvedCardImage))

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let response = try await AppleFoundationModelsMonsterGenerator.generateMonster(
                imageLabels: imageLabels
            )
            return AnalysisResult(
                monster: Monster(from: response, capturedImage: image, cardImage: resolvedCardImage),
                diagnostics: AIDiagnostics(provider: "apple-local", model: "FoundationModels+Vision")
            )
        }
        #endif

        throw AIError.localModelUnavailable("Apple Foundation Models is not available in this build.")
    }

    private static func classifyImage(_ image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return (request.results ?? [])
                .filter { $0.confidence >= 0.08 }
                .prefix(5)
                .map(\.identifier)
        } catch {
            return []
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private enum AppleFoundationModelsMonsterGenerator {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    static func generateMonster(imageLabels: [String]) async throws -> MonsterResponse {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AIError.localModelUnavailable(String(describing: model.availability))
        }

        let instructions = [
            "你是一個中二奇幻怪物卡牌命名師。",
            "依照圖片辨識線索，產生一張戰鬥怪物卡。",
            "name 必須是 4 到 8 字中文，保留物件線索並帶有 JRPG 戰鬥感。",
            "element 只能是：火、水、草、電、暗、一般。",
            "skillType 只能是：powerStrike、fortify、siphonStrike。",
            "你必須只輸出 JSON，且不得輸出 markdown 或額外說明。",
            "JSON schema:",
            "{\"name\":\"4~8字中文\",\"element\":\"火|水|草|電|暗|一般\",\"hp\":50~100,\"atk\":30~80,\"def\":20~60,\"skill\":\"8~16字中文\",\"skillType\":\"powerStrike|fortify|siphonStrike\"}"
        ].joined(separator: "\n")
        let prompt = [
            "圖片線索：\(imageLabels.isEmpty ? "未知物件" : imageLabels.joined(separator: ", "))",
            "請生成怪物名稱、屬性、能力值與招式，並只回傳 JSON。"
        ].joined(separator: "\n")

        let session = LanguageModelSession(model: model, instructions: instructions)
        let response = try await session.respond(to: prompt)
        return try parseMonsterResponse(from: response.content)
    }

    private static func parseMonsterResponse(from text: String) throws -> MonsterResponse {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let decoded = try JSONDecoder().decode(MonsterResponse.self, from: Data(cleaned.utf8))
        return MonsterResponse(
            name: String(decoded.name.prefix(8)),
            element: Element(rawValue: decoded.element)?.rawValue ?? Element.normal.rawValue,
            hp: min(100, max(50, decoded.hp)),
            atk: min(80, max(30, decoded.atk)),
            def: min(60, max(20, decoded.def)),
            skill: decoded.skill.isEmpty ? "靈光衝擊" : String(decoded.skill.prefix(16)),
            skillType: BattleSkillType(rawValue: decoded.skillType ?? "")?.rawValue
                ?? BattleSkillType(apiValue: nil, skillName: decoded.skill).rawValue
        )
    }
}
#endif

enum AIError: LocalizedError {
    case imageConversionFailed
    case invalidEndpoint
    case invalidResponse
    case analysisTimedOut
    case localModelUnavailable(String)
    case accessProtected
    case apiError(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "圖片處理失敗"
        case .invalidEndpoint:       return "Worker API 位址設定錯誤"
        case .invalidResponse:       return "Worker 回傳格式錯誤"
        case .analysisTimedOut:      return "怪物卡牌生成逾時，請檢查網路後再試一次"
        case .localModelUnavailable(let reason): return "本機 AI 不可用：\(reason)"
        case .accessProtected:       return "Worker API 目前被 Cloudflare Access 保護，請改用 mock、本機 AI，或解除 Access 後再試"
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
