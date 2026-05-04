import Foundation

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
}
