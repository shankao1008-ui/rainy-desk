import AVFoundation

final class DropAudio {
    private let queue = DispatchQueue(label: "RainyDesk.audio")
    private var engine = AVAudioEngine()
    private var nodes: [AVAudioPlayerNode] = []
    private var buffers: [SoundTheme: [DropKind: [AVAudioPCMBuffer]]] = [:]
    private var theme: SoundTheme = .rain
    private var last: [DropKind: Int] = [:]
    private var freeAt = Array(repeating: 0.0, count: 8)
    private var volume: Float = 0.35
    private var observer: NSObjectProtocol?
    var onError: ((String?) -> Void)?

    init() {
        queue.async { self.load() }
        observer = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: nil) { [weak self] note in
            guard let self, let changed = note.object as? AVAudioEngine else { return }
            self.queue.async {
                guard changed === self.engine else { return }
                self.reset()
            }
        }
    }
    private func load() {
        do {
            for theme in SoundTheme.allCases {
                var bank: [DropKind: [AVAudioPCMBuffer]] = [:]
                for kind in DropKind.allCases {
                let count = theme == .voice ? 1 : (kind == .letter ? 10 : 3)
                bank[kind] = try (0..<count).map { index in
                    guard let url = Bundle.main.url(forResource: "\(kind.rawValue)_\(index)", withExtension: "wav", subdirectory: "Sounds/\(theme.rawValue)") else {
                        throw NSError(domain: "Missing sound", code: 1)
                    }
                    let file = try AVAudioFile(forReading: url)
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { throw NSError(domain: "Audio buffer", code: 2) }
                    try file.read(into: buffer)
                    return buffer
                }
            }
                buffers[theme] = bank
            }
            setup()
        } catch { report("無法載入音效：\(error.localizedDescription)") }
    }
    private func setup() {
        guard let format = buffers[.rain]?[.letter]?.first?.format else { return }
        for _ in 0..<8 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            nodes.append(node)
        }
        engine.mainMixerNode.outputVolume = volume
        engine.prepare()
    }
    private func report(_ message: String?) { DispatchQueue.main.async { self.onError?(message) } }
    private func reset() {
        engine.stop()
        nodes.forEach { $0.stop() }
        nodes.removeAll()
        engine = AVAudioEngine()
        freeAt = Array(repeating: 0, count: 8)
        setup()
    }
    func register(_ themes: [SoundTheme]) {
        queue.async {
            for theme in themes {
                guard let pack = theme.pack, self.buffers[theme] == nil else { continue }
                do {
                    var bank: [DropKind: [AVAudioPCMBuffer]] = [:]
                    for kind in DropKind.allCases {
                        bank[kind] = try (pack.sounds[kind.rawValue] ?? []).map { asset in
                            let f = try AVAudioFile(forReading: SoundLibrary().assetURL(asset, pack: pack))
                            guard let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length)) else { throw LibraryError.invalid }
                            try f.read(into: b); return b
                        }
                    }
                    self.buffers = self.buffers.filter { $0.key.rawValue != theme.rawValue || $0.key == self.theme }
                    self.buffers[theme] = bank
                } catch { self.report("下載的音效暫時無法載入。") }
            }
        }
    }
    func setTheme(_ theme: SoundTheme) {
        queue.async {
            self.nodes.forEach { $0.stop() }
            self.freeAt = Array(repeating: 0, count: 8)
            self.theme = theme; self.last.removeAll()
        }
    }
    func setVolume(_ value: Double) {
        queue.async { self.volume = Float(value); self.engine.mainMixerNode.outputVolume = Float(value) }
    }
    func stop() { queue.async { self.nodes.forEach { $0.stop() }; self.engine.stop(); self.freeAt = Array(repeating: 0, count: 8) } }
    func recover() { queue.async { self.reset() } }
    func play(_ kind: DropKind) {
        queue.async {
            guard let samples = self.buffers[self.theme]?[kind], !samples.isEmpty, !self.nodes.isEmpty else { return }
            do {
                if !self.engine.isRunning { try self.engine.start() }
                // One voice at a time; every new press retriggers without a speech backlog.
                if self.theme.isVoice {
                    self.nodes.forEach { $0.stop() }
                    self.freeAt = Array(repeating: 0, count: 8)
                }
                let now = ProcessInfo.processInfo.systemUptime
                // Drop excess sounds instead of cutting a playing sample or creating a backlog.
                guard let slot = self.freeAt.firstIndex(where: { $0 <= now }) else { return }
                let choices = samples.indices.filter { $0 != self.last[kind] }
                let index = choices.randomElement() ?? 0
                self.last[kind] = index
                let buffer = samples[index]
                let active = self.freeAt.filter { $0 > now }.count
                let node = self.nodes[slot]
                // Keep the sum of active voice gains at 1.20: 0.60-peak samples
                // stay below 0.72 full scale, while isolated keys are six times louder.
                let gain = 1.20 / Float(active + 1)
                for index in self.nodes.indices where self.freeAt[index] > now {
                    self.nodes[index].volume = gain
                }
                node.volume = gain
                node.scheduleBuffer(buffer)
                if !node.isPlaying { node.play() }
                self.freeAt[slot] = now + Double(buffer.frameLength) / buffer.format.sampleRate + 0.015
                self.report(nil)
            } catch { self.report("音訊暫時無法播放，請檢查輸出裝置或重新啟用。") }
        }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
}
