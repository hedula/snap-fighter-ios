import Foundation

enum AIProvider: String {
    case auto
    case appleLocal = "apple-local"
    case worker
    case mock

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .appleLocal: return "Apple Local"
        case .worker: return "Worker"
        case .mock: return "Mock"
        }
    }
}

struct AIProviderSelection: Equatable {
    let provider: AIProvider
    let source: String
}

enum Config {
    // Set via Info.plist key `WORKER_ANALYZE_ENDPOINT` from build settings.
    static var workerAnalyzeEndpoint: String {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "WORKER_ANALYZE_ENDPOINT") as? String {
            let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        // Fallback for local development only.
        return "https://snap-fighter-ai.hedula.workers.dev/analyze"
    }

    static var aiProviderSelection: AIProviderSelection {
        resolveAIProvider(
            arguments: ProcessInfo.processInfo.arguments,
            infoValue: Bundle.main.object(forInfoDictionaryKey: "AI_PROVIDER") as? String
        )
    }

    static var aiProvider: AIProvider {
        aiProviderSelection.provider
    }

    static func resolveAIProvider(arguments: [String], infoValue: String?) -> AIProviderSelection {
        if let argumentValue = aiProviderArgumentValue(in: arguments),
           let provider = AIProvider(rawValue: argumentValue) {
            return AIProviderSelection(provider: provider, source: "Launch Argument")
        }

        if let configured = infoValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           let provider = AIProvider(rawValue: configured) {
            return AIProviderSelection(provider: provider, source: "Info.plist")
        }

        return AIProviderSelection(provider: .auto, source: "Default")
    }

    private static func aiProviderArgumentValue(in arguments: [String]) -> String? {
        for (index, argument) in arguments.enumerated() {
            if argument.hasPrefix("--ai-provider=") {
                return String(argument.dropFirst("--ai-provider=".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if argument == "--ai-provider", arguments.indices.contains(index + 1) {
                return arguments[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }
}
