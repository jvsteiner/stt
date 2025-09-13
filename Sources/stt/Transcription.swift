import FluidAudio
import Foundation

extension AudioProcessor {

    /// Transcribe audio samples using Parakeet v3 ASR model
    func transcribeAudio(samples: [Float]) async throws -> String {
        verboseLog("🤖 Initializing Parakeet v3 ASR model...")

        do {
            // Download and load ASR models
            let models = try await AsrModels.downloadAndLoad()
            verboseLog("✅ ASR models loaded successfully")

            // Initialize ASR manager with default config
            let asrManager = AsrManager(config: .default)
            try await asrManager.initialize(models: models)
            verboseLog("✅ ASR manager initialized")

            // Perform batch transcription
            verboseLog("🗣️ Transcribing \(Double(samples.count) / 16000.0) seconds of audio...")
            let result = try await asrManager.transcribe(samples, source: .system)

            verboseLog("✅ Transcription completed")
            verboseLog("📊 Confidence: \(String(format: "%.1f%%", result.confidence * 100))")
            verboseLog("⏱️ Processing time: \(String(format: "%.2fs", result.processingTime))")

            return result.text

        } catch {
            verboseLog("❌ Transcription failed: \(error.localizedDescription)")
            throw ProcessingError.transcriptionFailed
        }
    }
}
