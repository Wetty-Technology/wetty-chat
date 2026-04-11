import AVFoundation

/// Extracts normalized waveform peak samples from audio files.
///
/// Uses `AVAudioFile` for Apple-native formats (M4A, AAC, MP3, WAV)
/// and `OGGDecoder` for OGG/Opus files.
enum WaveformExtractor {

    enum WaveformError: Error {
        case failedToCreateBuffer
        case noChannelData
    }

    /// Extract waveform peaks from an audio file.
    ///
    /// Returns an array of `samplesCount` values, each normalized to 0–255.
    static func extract(path: String, samplesCount: Int) throws -> [Int] {
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()

        let rawSamples: [Float]
        if ext == "ogg" || ext == "opus" {
            rawSamples = try extractFromOgg(url: url)
        } else {
            rawSamples = try extractFromAVAudioFile(url: url)
        }

        return downsampleAndNormalize(rawSamples, to: samplesCount)
    }

    // MARK: - AVAudioFile (M4A, AAC, MP3, WAV, etc.)

    private static func extractFromAVAudioFile(url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: file.fileFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw WaveformError.failedToCreateBuffer
        }

        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw WaveformError.failedToCreateBuffer
        }

        try file.read(into: buffer)
        guard let floatData = buffer.floatChannelData?[0] else {
            throw WaveformError.noChannelData
        }

        return Array(UnsafeBufferPointer(start: floatData, count: Int(buffer.frameLength)))
    }

    // MARK: - OGG/Opus via OGGDecoder

    private static func extractFromOgg(url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        let decoder = try OGGDecoder(audioData: data)
        let pcmData = decoder.pcmData

        // OGGDecoder produces interleaved Float32 PCM
        let floatCount = pcmData.count / MemoryLayout<Float>.stride
        return pcmData.withUnsafeBytes { rawBuffer in
            let floatBuffer = rawBuffer.bindMemory(to: Float.self)
            return Array(floatBuffer.prefix(floatCount))
        }
    }

    // MARK: - Downsample + Normalize

    /// Compresses raw PCM samples into `targetCount` peak bars, normalized to 0–255.
    ///
    /// Mirrors the algorithm from `audio_waveform_cache_service.dart`:
    /// divide samples into equal chunks, find the absolute peak in each chunk,
    /// then scale the global maximum to 255.
    private static func downsampleAndNormalize(_ samples: [Float], to targetCount: Int) -> [Int] {
        guard !samples.isEmpty, targetCount > 0 else {
            return Array(repeating: 0, count: targetCount)
        }

        let chunkSize = Double(samples.count) / Double(targetCount)
        var peaks = [Float]()
        peaks.reserveCapacity(targetCount)

        for i in 0..<targetCount {
            let start = Int(Double(i) * chunkSize)
            let end = min(Int(Double(i + 1) * chunkSize), samples.count)
            var peak: Float = 0
            for j in start..<max(start + 1, end) {
                let absVal = Swift.abs(samples[j])
                if absVal > peak { peak = absVal }
            }
            peaks.append(peak)
        }

        // Find global peak for normalization
        let globalPeak = peaks.max() ?? 0
        guard globalPeak > 0 else {
            return Array(repeating: 0, count: targetCount)
        }

        return peaks.map { peak in
            Int((peak / globalPeak * 255).rounded()).clamped(to: 0...255)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
