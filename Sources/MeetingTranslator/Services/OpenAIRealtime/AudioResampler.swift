import Foundation

enum AudioResampler {
    static func resamplePCM16Mono(_ pcmData: Data, fromSampleRate: Int, toSampleRate: Int) -> Data {
        guard fromSampleRate > 0, toSampleRate > 0, !pcmData.isEmpty else { return Data() }
        guard fromSampleRate != toSampleRate else { return pcmData }

        let inputSampleCount = pcmData.count / MemoryLayout<Int16>.size
        guard inputSampleCount > 0 else { return Data() }

        let outputSampleCount = Int((Double(inputSampleCount) * Double(toSampleRate) / Double(fromSampleRate)).rounded())
        var output = Data(count: outputSampleCount * MemoryLayout<Int16>.size)

        pcmData.withUnsafeBytes { inputRaw in
            output.withUnsafeMutableBytes { outputRaw in
                let input = inputRaw.bindMemory(to: Int16.self)
                let out = outputRaw.bindMemory(to: Int16.self)

                for outputIndex in 0..<outputSampleCount {
                    let sourcePosition = Double(outputIndex) * Double(fromSampleRate) / Double(toSampleRate)
                    let lowerIndex = min(Int(sourcePosition), inputSampleCount - 1)
                    let upperIndex = min(lowerIndex + 1, inputSampleCount - 1)
                    let fraction = sourcePosition - Double(lowerIndex)

                    let lower = Double(input[lowerIndex])
                    let upper = Double(input[upperIndex])
                    let interpolated = lower + (upper - lower) * fraction
                    out[outputIndex] = Int16(max(Double(Int16.min), min(Double(Int16.max), interpolated.rounded())))
                }
            }
        }

        return output
    }
}
