import AVFoundation
import Foundation
import Observation
import Speech

@Observable
@MainActor
final class DictationService {
  enum State: Equatable {
    case idle
    case preparing
    case downloading(Double)
    case listening
    case error(String)
    case permissionRequired(PermissionError)
  }

  enum PermissionError: String, Equatable, Error, LocalizedError {
    case microphone
    case speech

    var errorDescription: String? { message }

    var title: String {
      switch self {
      case .microphone: "Microphone Access Needed"
      case .speech: "Speech Recognition Access Needed"
      }
    }

    var message: String {
      switch self {
      case .microphone: "macOS isn't delivering microphone audio. Open Privacy & Security → Microphone and enable Wagent (and Bitrig Mac, if it's listed)."
      case .speech: "Wagent needs Speech Recognition access. Open Privacy & Security → Speech Recognition and enable Wagent."
      }
    }

    var settingsURL: URL {
      switch self {
      case .microphone: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
      case .speech: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!
      }
    }
  }

  var state: State = .idle
  var partialText: String = ""

  var isListening: Bool {
    if case .listening = state { return true }
    return false
  }

  private var analyzer: SpeechAnalyzer?
  private var transcriber: SpeechTranscriber?
  private var audioEngine: AVAudioEngine?
  private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
  private var resultsTask: Task<Void, Never>?
  private var analyzerTask: Task<Void, Never>?
  private var watchdogTask: Task<Void, Never>?
  private var sender: AudioSender?

  private var committedText: String = ""
  private var onUpdate: ((String) -> Void)?

  func start(initialText: String, onUpdate: @escaping (String) -> Void) async {
    guard !isListening else { return }
    self.onUpdate = onUpdate
    committedText = initialText
    partialText = ""
    state = .preparing

    do {
      try await ensureSpeechPermission()

      let locale = await Self.preferredLocale()
      let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
      self.transcriber = transcriber

      try await ensureAssets(for: [transcriber])

      let analyzer = SpeechAnalyzer(modules: [transcriber])
      self.analyzer = analyzer

      let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        ?? AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

      let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream(bufferingPolicy: .unbounded)
      inputContinuation = continuation

      resultsTask = Task { [weak self] in
        guard let transcriber = self?.transcriber else { return }
        do {
          for try await result in transcriber.results {
            await self?.handle(result: result)
          }
        } catch {
          await self?.handleStreamError(error)
        }
      }

      analyzerTask = Task { [weak self] in
        do {
          _ = try await analyzer.analyzeSequence(stream)
        } catch {
          await self?.handleStreamError(error)
        }
      }

      _ = await AVCaptureDevice.requestAccess(for: .audio)

      try startAudio(targetFormat: analyzerFormat, continuation: continuation)
      state = .listening
      startMicWatchdog()
    } catch let permission as PermissionError {
      state = .permissionRequired(permission)
      await cleanup()
    } catch {
      state = .error(error.localizedDescription)
      await cleanup()
    }
  }

  func stop() async {
    watchdogTask?.cancel()
    watchdogTask = nil
    inputContinuation?.finish()
    inputContinuation = nil
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine?.stop()
    audioEngine = nil
    sender = nil

    do {
      try await analyzer?.finalizeAndFinishThroughEndOfInput()
    } catch {
      await analyzer?.cancelAndFinishNow()
    }

    resultsTask?.cancel()
    analyzerTask?.cancel()
    resultsTask = nil
    analyzerTask = nil
    analyzer = nil
    transcriber = nil

    if !partialText.isEmpty {
      commit(partialText)
    }
    partialText = ""
    onUpdate = nil
    state = .idle
  }

  private func cleanup() async {
    watchdogTask?.cancel()
    watchdogTask = nil
    inputContinuation?.finish()
    inputContinuation = nil
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine?.stop()
    audioEngine = nil
    sender = nil
    resultsTask?.cancel()
    analyzerTask?.cancel()
    resultsTask = nil
    analyzerTask = nil
    analyzer = nil
    transcriber = nil
  }

  private func handle(result: SpeechTranscriber.Result) {
    let text = String(result.text.characters).trimmingCharacters(in: .whitespaces)
    if result.isFinal {
      commit(text)
      partialText = ""
    } else {
      partialText = text
      onUpdate?(merged(committed: committedText, partial: text))
    }
  }

  private func commit(_ text: String) {
    guard !text.isEmpty else { return }
    committedText = merged(committed: committedText, partial: text)
    onUpdate?(committedText)
  }

  private func merged(committed: String, partial: String) -> String {
    if committed.isEmpty { return partial }
    let needsSeparator = !committed.hasSuffix(" ") && !committed.hasSuffix("\n")
    return committed + (needsSeparator ? " " : "") + partial
  }

  private func handleStreamError(_ error: Error) {
    state = .error(error.localizedDescription)
  }

  private func ensureSpeechPermission() async throws {
    switch SFSpeechRecognizer.authorizationStatus() {
    case .authorized:
      return
    case .notDetermined:
      let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
        SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
      }
      guard status == .authorized else { throw PermissionError.speech }
    case .denied, .restricted:
      throw PermissionError.speech
    @unknown default:
      return
    }
  }

  private func startMicWatchdog() {
    watchdogTask?.cancel()
    watchdogTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(4))
      guard !Task.isCancelled, let self else { return }
      let frames = self.sender?.framesReceived ?? 0
      let voiced = self.sender?.hasDetectedVoice ?? false
      if frames == 0 || !voiced {
        await self.markMicPermissionRequired()
      }
    }
  }

  private func markMicPermissionRequired() async {
    await cleanup()
    state = .permissionRequired(.microphone)
  }

  private static func preferredLocale() async -> Locale {
    let current = Locale.current
    if let match = await SpeechTranscriber.supportedLocale(equivalentTo: current) {
      return match
    }
    let installed = await SpeechTranscriber.installedLocales
    if let first = installed.first {
      return first
    }
    return Locale(identifier: "en-US")
  }

  private func ensureAssets(for modules: [any SpeechModule]) async throws {
    let status = await AssetInventory.status(forModules: modules)
    switch status {
    case .installed:
      return
    case .supported, .downloading:
      if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
        state = .downloading(0)
        try await request.downloadAndInstall()
      }
    case .unsupported:
      throw NSError(domain: "Wagent.Dictation", code: 2, userInfo: [NSLocalizedDescriptionKey: "On-device transcription isn't supported for this language on this Mac."])
    @unknown default:
      return
    }
  }

  private func startAudio(targetFormat: AVAudioFormat, continuation: AsyncStream<AnalyzerInput>.Continuation) throws {
    let engine = AVAudioEngine()
    self.audioEngine = engine
    let input = engine.inputNode
    let sourceFormat = input.outputFormat(forBus: 0)

    guard sourceFormat.sampleRate > 0 else {
      throw NSError(domain: "Wagent.Dictation", code: 3, userInfo: [NSLocalizedDescriptionKey: "No microphone input is available."])
    }

    let converter: AVAudioConverter? = formatsMatch(sourceFormat, targetFormat) ? nil : AVAudioConverter(from: sourceFormat, to: targetFormat)

    let sender = AudioSender(target: targetFormat, sourceFormat: sourceFormat, converter: converter, continuation: continuation)
    self.sender = sender

    input.installTap(onBus: 0, bufferSize: 4096, format: sourceFormat) { buffer, _ in
      sender.send(buffer)
    }

    engine.prepare()
    try engine.start()
  }

  private func formatsMatch(_ lhs: AVAudioFormat, _ rhs: AVAudioFormat) -> Bool {
    lhs.sampleRate == rhs.sampleRate &&
    lhs.channelCount == rhs.channelCount &&
    lhs.commonFormat == rhs.commonFormat
  }
}

private final class AudioSender: @unchecked Sendable {
  let target: AVAudioFormat
  let sourceFormat: AVAudioFormat
  let converter: AVAudioConverter?
  let continuation: AsyncStream<AnalyzerInput>.Continuation

  private let lock = NSLock()
  private var _framesReceived: Int64 = 0
  private var _hasDetectedVoice: Bool = false

  var framesReceived: Int64 {
    lock.lock(); defer { lock.unlock() }
    return _framesReceived
  }

  var hasDetectedVoice: Bool {
    lock.lock(); defer { lock.unlock() }
    return _hasDetectedVoice
  }

  init(target: AVAudioFormat, sourceFormat: AVAudioFormat, converter: AVAudioConverter?, continuation: AsyncStream<AnalyzerInput>.Continuation) {
    self.target = target
    self.sourceFormat = sourceFormat
    self.converter = converter
    self.continuation = continuation
  }

  func send(_ buffer: AVAudioPCMBuffer) {
    recordStats(for: buffer)
    guard let converter else {
      continuation.yield(AnalyzerInput(buffer: buffer))
      return
    }
    let ratio = target.sampleRate / sourceFormat.sampleRate
    let capacity = AVAudioFrameCount(max(1, Double(buffer.frameLength) * ratio + 1024))
    guard let outBuffer = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
    var supplied = false
    var conversionError: NSError?
    let status = converter.convert(to: outBuffer, error: &conversionError) { _, inputStatus in
      if supplied {
        inputStatus.pointee = .noDataNow
        return nil
      }
      supplied = true
      inputStatus.pointee = .haveData
      return buffer
    }
    guard status != .error, outBuffer.frameLength > 0 else { return }
    continuation.yield(AnalyzerInput(buffer: outBuffer))
  }

  private func recordStats(for buffer: AVAudioPCMBuffer) {
    lock.lock()
    _framesReceived += Int64(buffer.frameLength)
    lock.unlock()
    guard let channelData = buffer.floatChannelData else { return }
    let frames = Int(buffer.frameLength)
    var peak: Float = 0
    for channel in 0..<Int(buffer.format.channelCount) {
      let ptr = channelData[channel]
      for index in 0..<frames {
        let value = abs(ptr[index])
        if value > peak { peak = value }
      }
    }
    if peak > 0.005 {
      lock.lock()
      _hasDetectedVoice = true
      lock.unlock()
    }
  }
}
