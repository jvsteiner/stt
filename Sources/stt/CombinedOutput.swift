import FluidAudio
import Foundation

extension AudioProcessor {

    /// Combine transcription text with speaker diarization results
    func combineTranscriptionWithDiarization(
        transcription: String,
        diarization: String,
        samples: [Float]
    ) throws -> String {

        // Parse speaker segments from diarization text
        let speakerSegments = parseSpeakerSegments(from: diarization)

        if speakerSegments.isEmpty {
            verboseLog("⚠️ No speaker segments found, returning transcription only")
            return formatCombinedOutput(transcription: transcription, segments: [])
        }

        // Create combined output with speaker attribution
        verboseLog("🔗 Combining transcription with \(speakerSegments.count) speaker segments")

        return formatCombinedOutput(transcription: transcription, segments: speakerSegments)
    }

    private func parseSpeakerSegments(from diarizationText: String) -> [SpeakerSegment] {
        var segments: [SpeakerSegment] = []

        let lines = diarizationText.components(separatedBy: .newlines)

        verboseLog("🔍 Parsing diarization with \(lines.count) lines")

        for (index, line) in lines.enumerated() {
            // Look for lines like: "1: 00:00.000 - 00:06.243 (6.2s) [Quality: 47.5%]"
            if line.contains(":") && line.contains("-") && !line.contains("SPEAKER")
                && !line.contains("=")
            {
                verboseLog("🔍 Processing line \(index): '\(line)'")

                // Split only on the first colon to separate speaker number from timestamp
                if let firstColonIndex = line.firstIndex(of: ":") {
                    let speakerPart = String(line[..<firstColonIndex]).trimmingCharacters(
                        in: .whitespaces)
                    let timePart = String(line[line.index(after: firstColonIndex)...])
                        .trimmingCharacters(in: .whitespaces)

                    verboseLog("🔍 Speaker part: '\(speakerPart)', Time part: '\(timePart)'")

                    // Extract speaker ID - convert number to Speaker X format
                    if let speakerNumber = Int(speakerPart) {
                        let speakerId = "Speaker \(speakerNumber)"
                        verboseLog("🔍 Found speaker: \(speakerId)")

                        // Parse timestamps
                        if let (startTime, endTime) = parseTimestamps(from: timePart) {
                            verboseLog("🔍 Parsed times: \(startTime) - \(endTime)")
                            segments.append(
                                SpeakerSegment(
                                    speakerId: speakerId,
                                    startTime: startTime,
                                    endTime: endTime
                                ))
                        } else {
                            verboseLog("⚠️ Failed to parse timestamps from: '\(timePart)'")
                        }
                    } else {
                        verboseLog("⚠️ Failed to parse speaker number from: '\(speakerPart)'")
                    }
                }
            }
        }

        verboseLog("🔍 Parsed \(segments.count) speaker segments")
        let sortedSegments = segments.sorted { $0.startTime < $1.startTime }

        // Post-process to filter out very short segments that cause fragmentation
        let filteredSegments = filterShortSegments(sortedSegments)
        verboseLog("🔍 After filtering short segments: \(filteredSegments.count) segments")

        return filteredSegments
    }

    private func parseTimestamps(from timePart: String) -> (Double, Double)? {
        // Parse format like " 00:00.000 - 00:06.243 (6.2s) [Quality: 47.5%]"
        let components = timePart.components(separatedBy: " - ")
        guard components.count == 2 else { return nil }

        let startString = components[0].trimmingCharacters(in: .whitespaces)
        let endPart = components[1].trimmingCharacters(in: .whitespaces)
        // Extract just the timestamp before the space and parentheses
        let endString = endPart.components(separatedBy: " ")[0]

        guard let startTime = parseTimestamp(startString),
            let endTime = parseTimestamp(endString)
        else {
            return nil
        }

        return (startTime, endTime)
    }

    private func parseTimestamp(_ timestamp: String) -> Double? {
        // Parse format like "00:15.234" (mm:ss.fff)
        let parts = timestamp.components(separatedBy: ":")
        guard parts.count == 2 else { return nil }

        guard let minutes = Int(parts[0]) else { return nil }

        let secondParts = parts[1].components(separatedBy: ".")
        guard secondParts.count == 2,
            let seconds = Int(secondParts[0]),
            let milliseconds = Int(secondParts[1])
        else { return nil }

        return Double(minutes * 60 + seconds) + Double(milliseconds) / 1000.0
    }

    private func filterShortSegments(_ segments: [SpeakerSegment]) -> [SpeakerSegment] {
        var filtered: [SpeakerSegment] = []
        let minimumDuration: Double = 1.5  // Filter out segments shorter than 1.5 seconds

        for segment in segments {
            let duration = segment.endTime - segment.startTime

            // Keep longer segments
            if duration >= minimumDuration {
                filtered.append(segment)
            } else {
                // For very short segments, try to merge with adjacent segment of same speaker
                if let lastSegment = filtered.last,
                    lastSegment.speakerId == segment.speakerId,
                    segment.startTime - lastSegment.endTime < 2.0
                {  // Close in time

                    // Extend the last segment to include this short one
                    let extendedSegment = SpeakerSegment(
                        speakerId: lastSegment.speakerId,
                        startTime: lastSegment.startTime,
                        endTime: segment.endTime
                    )
                    filtered[filtered.count - 1] = extendedSegment
                    verboseLog(
                        "🔗 Merged short segment (\(String(format: "%.1f", duration))s) with previous segment"
                    )
                } else {
                    // Can't merge, skip this short segment
                    verboseLog(
                        "⏭️ Skipping short segment (\(String(format: "%.1f", duration))s) from \(segment.speakerId)"
                    )
                }
            }
        }

        return filtered
    }

    private func formatCombinedOutput(transcription: String, segments: [SpeakerSegment]) -> String {
        if segments.isEmpty {
            return transcription
        }

        // Create a mapping of unique speakers to clean speaker labels
        let uniqueSpeakers = Array(Set(segments.map { $0.speakerId })).sorted()
        let speakerMapping = Dictionary(
            uniqueKeysWithValues:
                uniqueSpeakers.enumerated().map { (index, speaker) in
                    (speaker, "Speaker \(Character(UnicodeScalar(65 + index)!))")
                }
        )

        // Split transcription into words
        let words = transcription.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // Create speaker turns by grouping consecutive segments of the same speaker
        var speakerTurns: [(speaker: String, segments: [SpeakerSegment])] = []
        var currentTurnSpeaker: String? = nil
        var currentTurnSegments: [SpeakerSegment] = []

        for segment in segments {
            let speakerLabel = speakerMapping[segment.speakerId] ?? segment.speakerId

            if currentTurnSpeaker != speakerLabel {
                // New speaker turn - save previous turn if exists
                if let prevSpeaker = currentTurnSpeaker, !currentTurnSegments.isEmpty {
                    speakerTurns.append((speaker: prevSpeaker, segments: currentTurnSegments))
                }
                // Start new turn
                currentTurnSpeaker = speakerLabel
                currentTurnSegments = [segment]
            } else {
                // Same speaker continues
                currentTurnSegments.append(segment)
            }
        }

        // Add final turn
        if let speaker = currentTurnSpeaker, !currentTurnSegments.isEmpty {
            speakerTurns.append((speaker: speaker, segments: currentTurnSegments))
        }

        // Now distribute words across speaker turns based on total duration
        let totalDuration = segments.last?.endTime ?? 0
        var output = ""
        var currentWordIndex = 0

        for turn in speakerTurns {
            // Calculate total duration for this speaker turn
            let turnDuration = turn.segments.reduce(0.0) { total, segment in
                total + (segment.endTime - segment.startTime)
            }

            // Estimate words for this turn based on duration
            let wordsPerSecond = totalDuration > 0 ? Double(words.count) / totalDuration : 1.0
            let estimatedWords = max(1, Int(turnDuration * wordsPerSecond))

            let endWordIndex = min(currentWordIndex + estimatedWords, words.count)
            let turnWords = Array(words[currentWordIndex..<endWordIndex])

            if !turnWords.isEmpty {
                if !output.isEmpty {
                    output += "\n"
                }
                output += "\(turn.speaker): \(turnWords.joined(separator: " "))"
            }

            currentWordIndex = endWordIndex
        }

        // Add any remaining words to the last speaker
        if currentWordIndex < words.count {
            let remainingWords = Array(words[currentWordIndex...])
            if !remainingWords.isEmpty {
                output += " \(remainingWords.joined(separator: " "))"
            }
        }

        return output
    }
}

struct SpeakerSegment {
    let speakerId: String
    let startTime: Double
    let endTime: Double
}
