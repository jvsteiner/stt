import AVFoundation
import ArgumentParser
import FluidAudio
import Foundation

struct STTCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "stt",
        abstract:
            "A macOS CLI utility for speech-to-text with speaker diarization using Parakeet v3",
        discussion:
            "Processes MP3 files and outputs diarized transcripts with speaker identification."
    )

    @Argument(help: "Input MP3 file path")
    var inputFile: String

    @Option(name: .shortAndLong, help: "Output directory for results (default: same as input file)")
    var output: String?

    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose: Bool = false

    @Flag(name: .long, help: "Skip diarization and only perform transcription")
    var transcribeOnly: Bool = false

    @Option(help: "Diarization clustering threshold (0.0-1.0, default: 0.8)")
    var threshold: Double = 0.8

    func run() throws {
        let processor = AudioProcessor(verbose: verbose)

        // Use a synchronous wrapper for the async operations
        let semaphore = DispatchSemaphore(value: 0)
        var processingResult: ProcessingResult?
        var processingError: Error?

        Task {
            do {
                let result = try await processor.processAudioFile(
                    inputPath: inputFile,
                    outputDirectory: output,
                    transcribeOnly: transcribeOnly,
                    threshold: threshold
                )
                processingResult = result
            } catch {
                processingError = error
            }
            semaphore.signal()
        }

        semaphore.wait()

        if let error = processingError {
            print("❌ Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        if let result = processingResult {
            print("✅ Processing complete!")
            print("📄 Transcript: \(result.transcriptFile)")
            if let diarizationFile = result.diarizationFile {
                print("👥 Diarization: \(diarizationFile)")
            }
            if let combinedFile = result.combinedFile {
                print("🔗 Combined: \(combinedFile)")
            }
        }
    }
}

STTCommand.main()

struct ProcessingResult {
    let transcriptFile: String
    let diarizationFile: String?
    let combinedFile: String?
}

class AudioProcessor {
    private let verbose: Bool

    init(verbose: Bool = false) {
        self.verbose = verbose
    }

    func processAudioFile(
        inputPath: String,
        outputDirectory: String?,
        transcribeOnly: Bool,
        threshold: Double
    ) async throws -> ProcessingResult {

        let inputURL = URL(fileURLWithPath: inputPath)

        // Validate input file exists
        guard FileManager.default.fileExists(atPath: inputPath) else {
            throw ProcessingError.fileNotFound(inputPath)
        }

        verboseLog("🎵 Loading audio file: \(inputURL.lastPathComponent)")

        // Convert audio to 16kHz mono samples
        let samples = try await loadAudioSamples(from: inputURL)
        verboseLog("📊 Loaded \(samples.count) samples (\(Double(samples.count) / 16000.0) seconds)")

        // Determine output directory
        let outputDir = outputDirectory ?? inputURL.deletingLastPathComponent().path
        let baseName = inputURL.deletingPathExtension().lastPathComponent

        // Ensure output directory exists
        try FileManager.default.createDirectory(
            atPath: outputDir, withIntermediateDirectories: true)

        let transcriptPath = "\(outputDir)/\(baseName)_transcript.txt"
        var diarizationPath: String? = nil
        var combinedPath: String? = nil

        // Perform transcription
        verboseLog("🗣️ Starting transcription with Parakeet v3...")
        let transcription = try await transcribeAudio(samples: samples)

        // Save transcript
        try transcription.write(
            to: URL(fileURLWithPath: transcriptPath), atomically: true, encoding: .utf8)
        verboseLog("💾 Saved transcript to: \(transcriptPath)")

        if !transcribeOnly {
            // Perform speaker diarization
            verboseLog("👥 Starting speaker diarization...")
            let diarization = try await diarizeAudio(samples: samples, threshold: threshold)

            diarizationPath = "\(outputDir)/\(baseName)_diarization.txt"
            try diarization.write(
                to: URL(fileURLWithPath: diarizationPath!), atomically: true, encoding: .utf8)
            verboseLog("💾 Saved diarization to: \(diarizationPath!)")

            // Combine transcription with diarization
            verboseLog("🔗 Combining transcription with speaker information...")
            let combined = try combineTranscriptionWithDiarization(
                transcription: transcription,
                diarization: diarization,
                samples: samples
            )

            combinedPath = "\(outputDir)/\(baseName)_combined.txt"
            try combined.write(
                to: URL(fileURLWithPath: combinedPath!), atomically: true, encoding: .utf8)
            verboseLog("💾 Saved combined result to: \(combinedPath!)")
        }

        return ProcessingResult(
            transcriptFile: transcriptPath,
            diarizationFile: diarizationPath,
            combinedFile: combinedPath
        )
    }

    func verboseLog(_ message: String) {
        if verbose {
            print(message)
        }
    }
}

enum ProcessingError: LocalizedError {
    case fileNotFound(String)
    case unsupportedFormat
    case transcriptionFailed
    case diarizationFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .unsupportedFormat:
            return "Unsupported audio format"
        case .transcriptionFailed:
            return "Transcription failed"
        case .diarizationFailed:
            return "Speaker diarization failed"
        }
    }
}
