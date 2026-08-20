import CoreAudio
import Foundation
import MacGlowCore

enum SystemAudioCaptureState: Equatable {
    case stopped
    case starting
    case running
    case failed(String)
}

enum SystemAudioCaptureError: LocalizedError {
    case unsupportedSystem
    case createTap(OSStatus)
    case readTapFormat(OSStatus)
    case unsupportedFormat
    case createAggregateDevice(OSStatus)
    case createIOProc(OSStatus)
    case startDevice(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unsupportedSystem:
            "System audio capture requires macOS 14.2 or newer."
        case let .createTap(status):
            "Could not create the system audio tap (\(status.fourCharacterCode)). Check System Audio Recording permission."
        case let .readTapFormat(status):
            "Could not read the audio tap format (\(status.fourCharacterCode))."
        case .unsupportedFormat:
            "The system audio tap returned an unsupported PCM format."
        case let .createAggregateDevice(status):
            "Could not create the private audio device (\(status.fourCharacterCode))."
        case let .createIOProc(status):
            "Could not configure audio processing (\(status.fourCharacterCode))."
        case let .startDevice(status):
            "Could not start system audio capture (\(status.fourCharacterCode))."
        }
    }
}

/// Captures a private, unmuted global system-audio mix with public CoreAudio APIs.
/// Raw sample buffers are analyzed synchronously and are never retained.
@available(macOS 14.2, *)
final class SystemAudioCapture: @unchecked Sendable {
    typealias FeaturesHandler = @Sendable (AudioFeatures) -> Void
    typealias StateHandler = @Sendable (SystemAudioCaptureState) -> Void

    var onFeatures: FeaturesHandler?
    var onStateChange: StateHandler?

    private let audioQueue = DispatchQueue(
        label: "org.macglow.audio-analysis",
        qos: .userInteractive
    )
    private let pipeline = AudioAnalysisPipeline()

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var tapUID = ""
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    private(set) var state: SystemAudioCaptureState = .stopped {
        didSet { onStateChange?(state) }
    }

    func start() throws {
        guard state == .stopped else { return }
        state = .starting

        do {
            try createTap()
            let format = try readTapFormat()
            guard format.isFloatPCM else {
                throw SystemAudioCaptureError.unsupportedFormat
            }
            try createAggregateDevice()
            try createIOProc()

            let status = AudioDeviceStart(aggregateDeviceID, ioProcID)
            guard status == noErr else {
                throw SystemAudioCaptureError.startDevice(status)
            }

            state = .running
        } catch {
            tearDownResources()
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    func stop() {
        tearDownResources()
        pipeline.reset()
        state = .stopped
    }

    func updateResponse(_ response: AudioResponseSettings) {
        audioQueue.async { [pipeline] in
            pipeline.updateResponse(response)
        }
    }

    private func createTap() throws {
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.name = "MacGlow System Audio"
        let uuid = UUID()
        description.uuid = uuid
        tapUID = uuid.uuidString
        description.isPrivate = true
        description.muteBehavior = .unmuted

        let status = AudioHardwareCreateProcessTap(description, &tapID)
        guard status == noErr else {
            tapID = AudioObjectID(kAudioObjectUnknown)
            throw SystemAudioCaptureError.createTap(status)
        }
    }

    private func readTapFormat() throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(
            tapID,
            &address,
            0,
            nil,
            &size,
            &format
        )
        guard status == noErr else {
            throw SystemAudioCaptureError.readTapFormat(status)
        }
        return format
    }

    private func createAggregateDevice() throws {
        let aggregateUID = "org.macglow.audio-device.\(UUID().uuidString)"
        let description: [String: Any] = [
            "name": "MacGlow Private Audio Device",
            "uid": aggregateUID,
            "private": true,
            "taps": [
                [
                    "uid": tapUID,
                    "drift": true
                ]
            ]
        ]

        let status = AudioHardwareCreateAggregateDevice(
            description as CFDictionary,
            &aggregateDeviceID
        )
        guard status == noErr else {
            aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
            throw SystemAudioCaptureError.createAggregateDevice(status)
        }
    }

    private func createIOProc() throws {
        let pipeline = pipeline
        let featuresHandler = { [weak self] (features: AudioFeatures) in
            self?.onFeatures?(features)
        }

        let status = AudioDeviceCreateIOProcIDWithBlock(
            &ioProcID,
            aggregateDeviceID,
            audioQueue
        ) { _, inputData, _, _, _ in
            guard let features = pipeline.consume(inputData) else { return }
            featuresHandler(features)
        }

        guard status == noErr else {
            ioProcID = nil
            throw SystemAudioCaptureError.createIOProc(status)
        }
    }

    private func tearDownResources() {
        if aggregateDeviceID != kAudioObjectUnknown, let ioProcID {
            AudioDeviceStop(aggregateDeviceID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
            self.ioProcID = nil
        }

        if aggregateDeviceID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        }

        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
            tapUID = ""
        }
    }
}

@available(macOS 14.2, *)
private final class AudioAnalysisPipeline: @unchecked Sendable {
    private var analyzer = AudioFrameAnalyzer()

    func consume(_ audioBufferList: UnsafePointer<AudioBufferList>) -> AudioFeatures? {
        let buffers = UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer(mutating: audioBufferList)
        )
        var squaredSum: Float = 0
        var peak: Float = 0
        var sampleCount = 0

        for buffer in buffers {
            guard let data = buffer.mData else { continue }
            let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
            let samples = data.assumingMemoryBound(to: Float.self)

            for index in 0..<count {
                let magnitude = min(abs(samples[index]), 1)
                squaredSum += magnitude * magnitude
                peak = max(peak, magnitude)
            }
            sampleCount += count
        }

        guard sampleCount > 0 else { return nil }
        let rms = sqrt(squaredSum / Float(sampleCount))
        return analyzer.analyze(rms: rms, peak: peak)
    }

    func reset() {
        analyzer.reset()
    }

    func updateResponse(_ response: AudioResponseSettings) {
        analyzer.attack = min(max(response.attack, 0), 1)
        analyzer.release = min(max(response.release, 0), 1)
        analyzer.gain = max(response.gain, 0)
    }
}

private extension AudioStreamBasicDescription {
    var isFloatPCM: Bool {
        mFormatID == kAudioFormatLinearPCM
            && (mFormatFlags & kAudioFormatFlagIsFloat) != 0
            && mBitsPerChannel == 32
    }
}

private extension OSStatus {
    var fourCharacterCode: String {
        let characters: [UInt8] = [
            UInt8((UInt32(bitPattern: self) >> 24) & 0xff),
            UInt8((UInt32(bitPattern: self) >> 16) & 0xff),
            UInt8((UInt32(bitPattern: self) >> 8) & 0xff),
            UInt8(UInt32(bitPattern: self) & 0xff)
        ]
        let readable = characters.allSatisfy { $0 >= 32 && $0 <= 126 }
        return readable ? String(bytes: characters, encoding: .ascii) ?? "\(self)" : "\(self)"
    }
}
