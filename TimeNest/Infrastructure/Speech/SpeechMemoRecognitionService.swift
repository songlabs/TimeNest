import AVFAudio
import Foundation
import Speech

enum SpeechMemoRecognitionStatus: Equatable {
    case idle
    case recording
    case unavailable
    case denied
}

enum SpeechMemoRecognitionFailure: Equatable {
    case permissionDenied
    case unavailable
    case recognitionFailed
}

final class SpeechMemoRecognitionService: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var isInputTapInstalled = false
    private var didStopIntentionally = false

    deinit {
        stopRecognition()
    }

    func startRecognition(
        language: DisplayLanguage,
        onTranscription: @escaping @MainActor (String, Bool) -> Void,
        onCompletion: @escaping @MainActor (SpeechMemoRecognitionFailure?) -> Void
    ) async -> SpeechMemoRecognitionStatus {
        stopRecognition()
        didStopIntentionally = false

        let locale = Self.locale(for: language)
        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition
        else {
            return .unavailable
        }

        guard await requestPermissions() else {
            return .denied
        }

        speechRecognizer = recognizer

        do {
            try startAudioRecognition(
                recognizer: recognizer,
                onTranscription: onTranscription,
                onCompletion: onCompletion
            )
            return .recording
        } catch {
            cleanupRecognition()
            return .unavailable
        }
    }

    func stopRecognition() {
        didStopIntentionally = true

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if isInputTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isInputTapInstalled = false
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        cleanupRecognition()
    }

    private func startAudioRecognition(
        recognizer: SFSpeechRecognizer,
        onTranscription: @escaping @MainActor (String, Bool) -> Void,
        onCompletion: @escaping @MainActor (SpeechMemoRecognitionFailure?) -> Void
    ) throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        isInputTapInstalled = true

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let transcript = result.bestTranscription.formattedString
                Task { @MainActor in
                    onTranscription(transcript, result.isFinal)
                }
            }

            if error != nil || result?.isFinal == true {
                let stoppedIntentionally = self.didStopIntentionally
                self.cleanupRecognition()

                Task { @MainActor in
                    if stoppedIntentionally {
                        onCompletion(nil)
                    } else if error != nil {
                        onCompletion(.recognitionFailed)
                    } else {
                        onCompletion(nil)
                    }
                }
            }
        }
    }

    private func requestPermissions() async -> Bool {
        guard await requestSpeechAuthorization() else {
            return false
        }
        return await requestMicrophoneAuthorization()
    }

    private func requestSpeechAuthorization() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func cleanupRecognition() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if isInputTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isInputTapInstalled = false
        }

        recognitionRequest = nil
        recognitionTask = nil
        speechRecognizer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func locale(for language: DisplayLanguage) -> Locale {
        switch language {
        case .system:
            return .current
        case .zhHans:
            return Locale(identifier: "zh_CN")
        case .zhHant:
            return Locale(identifier: "zh_TW")
        case .ja:
            return Locale(identifier: "ja_JP")
        case .ko:
            return Locale(identifier: "ko_KR")
        case .enUS:
            return Locale(identifier: "en_US")
        }
    }
}
