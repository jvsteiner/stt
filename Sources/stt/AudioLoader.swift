import AVFoundation
import Foundation

extension AudioProcessor {

    /// Load audio file and convert to 16kHz mono samples required by FluidAudio
    func loadAudioSamples(from url: URL) async throws -> [Float] {
        return try await withCheckedThrowingContinuation { continuation in
            loadAudioSamplesSync(from: url) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func loadAudioSamplesSync(
        from url: URL,
        completion: @escaping (Result<[Float], Error>) -> Void
    ) {
        // Create AVAudioFile
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            completion(.failure(ProcessingError.unsupportedFormat))
            return
        }

        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)

        verboseLog("🎵 Original format: \(format.sampleRate)Hz, \(format.channelCount) channels")

        // Read the audio data
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            completion(.failure(ProcessingError.unsupportedFormat))
            return
        }

        do {
            try audioFile.read(into: buffer)
        } catch {
            completion(.failure(error))
            return
        }

        // Convert to 16kHz mono if necessary
        let targetSampleRate: Double = 16000
        let targetChannels: UInt32 = 1

        if format.sampleRate == targetSampleRate && format.channelCount == targetChannels {
            // Already in correct format
            guard let samples = buffer.floatChannelData?[0] else {
                completion(.failure(ProcessingError.unsupportedFormat))
                return
            }

            let sampleArray = Array(
                UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
            completion(.success(sampleArray))
        } else {
            // Need to convert
            convertAudioFormat(
                buffer: buffer,
                from: format,
                targetSampleRate: targetSampleRate,
                targetChannels: targetChannels,
                completion: completion
            )
        }
    }

    private func convertAudioFormat(
        buffer: AVAudioPCMBuffer,
        from sourceFormat: AVAudioFormat,
        targetSampleRate: Double,
        targetChannels: UInt32,
        completion: @escaping (Result<[Float], Error>) -> Void
    ) {
        // Create target format (16kHz mono)
        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: targetSampleRate,
                channels: targetChannels,
                interleaved: false
            )
        else {
            completion(.failure(ProcessingError.unsupportedFormat))
            return
        }

        verboseLog("🔄 Converting to 16kHz mono...")

        // Create converter
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            completion(.failure(ProcessingError.unsupportedFormat))
            return
        }

        // Calculate output buffer size
        let ratio = targetSampleRate / sourceFormat.sampleRate
        let outputFrameCount = UInt32(Double(buffer.frameLength) * ratio)

        guard
            let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: outputFrameCount
            )
        else {
            completion(.failure(ProcessingError.unsupportedFormat))
            return
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = AVAudioConverterInputStatus.haveData
            return buffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            completion(.failure(error))
            return
        }

        // Extract samples
        guard let samples = outputBuffer.floatChannelData?[0] else {
            completion(.failure(ProcessingError.unsupportedFormat))
            return
        }

        let sampleArray = Array(
            UnsafeBufferPointer(start: samples, count: Int(outputBuffer.frameLength)))
        verboseLog("✅ Converted to \(sampleArray.count) samples at 16kHz mono")

        completion(.success(sampleArray))
    }
}
