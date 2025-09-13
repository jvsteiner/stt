import FluidAudio
import Foundation

extension AudioProcessor {

    /// Perform speaker diarization on audio samples
    func diarizeAudio(samples: [Float], threshold: Double) async throws -> String {
        verboseLog("👥 Initializing speaker diarization models...")

        do {
            // Download and load diarization models
            let models = try await DiarizerModels.downloadIfNeeded()
            verboseLog("✅ Diarization models loaded successfully")

            // Initialize diarizer manager with custom threshold
            let config = DiarizerConfig(
                clusteringThreshold: Float(threshold),
                minSpeechDuration: 0.5,  // Minimum speech segment duration
                minSilenceGap: 0.5  // Minimum gap between speakers
            )
            let diarizer = DiarizerManager(config: config)
            diarizer.initialize(models: models)
            verboseLog("✅ Diarizer initialized with threshold: \(threshold)")

            // Perform complete diarization
            verboseLog("👥 Performing speaker diarization...")
            let result = try diarizer.performCompleteDiarization(samples)

            verboseLog("✅ Diarization completed")

            // Calculate speaker count from unique speaker IDs
            let uniqueSpeakers = Set(result.segments.map { $0.speakerId })
            verboseLog(
                "🎯 Found \(uniqueSpeakers.count) speakers in \(result.segments.count) segments")

            // Calculate processing time from timings if available
            if let timings = result.timings {
                verboseLog(
                    "⏱️ Processing time: \(String(format: "%.2fs", timings.totalProcessingSeconds))")
            }

            // Format results as text
            return formatDiarizationResult(result)

        } catch {
            verboseLog("❌ Diarization failed: \(error.localizedDescription)")
            throw ProcessingError.diarizationFailed
        }
    }

    private func formatDiarizationResult(_ result: DiarizationResult) -> String {
        var output = "SPEAKER DIARIZATION RESULTS\n"
        output += "==========================\n\n"

        // Calculate audio duration from last segment
        let audioDuration = result.segments.last?.endTimeSeconds ?? 0
        output += "Audio Duration: \(String(format: "%.1f", audioDuration)) seconds\n"

        // Calculate speaker count from unique speaker IDs
        let uniqueSpeakers = Set(result.segments.map { $0.speakerId })
        output += "Speaker Count: \(uniqueSpeakers.count)\n"
        output += "Segments: \(result.segments.count)\n"

        // Include processing time if available
        if let timings = result.timings {
            output +=
                "Processing Time: \(String(format: "%.2f", timings.totalProcessingSeconds)) seconds\n"
            let rtf = audioDuration > 0 ? timings.totalInferenceSeconds / Double(audioDuration) : 0
            output += "Real-time Factor: \(String(format: "%.2fx", rtf))\n"
        }
        output += "\n"

        output += "SPEAKER SEGMENTS:\n"
        output += "-----------------\n"

        for segment in result.segments {
            let startTime = formatTimestamp(segment.startTimeSeconds)
            let endTime = formatTimestamp(segment.endTimeSeconds)
            let duration = segment.endTimeSeconds - segment.startTimeSeconds

            output += "\(segment.speakerId): \(startTime) - \(endTime) "
            output += "(\(String(format: "%.1f", duration))s)"

            if segment.qualityScore > 0 {
                output += " [Quality: \(String(format: "%.1f", segment.qualityScore * 100))%]"
            }

            output += "\n"
        }

        return output
    }

    private func formatTimestamp(_ seconds: Float) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        let milliseconds = Int((seconds - Float(totalSeconds)) * 1000)

        return String(format: "%02d:%02d.%03d", minutes, remainingSeconds, milliseconds)
    }
}
