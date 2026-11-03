import Foundation
import CryptoKit
import AVFoundation

struct SoundAsset: Codable, Hashable {
    let path: String
    let sha256: String
    let bytes: Int
}
struct SoundPack: Codable, Hashable {
    let id: String
    let version: Int
    let title: String
    let titleEN: String
    let detail: String
    let detailEN: String
    let mapping: String
    let sounds: [String: [SoundAsset]]
    var cacheKey: String { "\(id)-\(version)" }
}
struct SoundCatalog: Codable {
    let schema: Int
    let packs: [SoundPack]
    func validate() throws {
        guard schema == 1, packs.count <= 50, Set(packs.map(\.id)).count == packs.count else { throw LibraryError.invalid }
        guard packs.flatMap({ $0.sounds.values.flatMap { $0 } }).reduce(0, { $0 + min(max($1.bytes,0),1000001) }) <= 20000000 else { throw LibraryError.tooLarge }
        for p in packs {
            guard p.id.range(of: "^[a-z][a-z0-9-]{0,47}$", options: .regularExpression) != nil,
                  !BuiltinTheme.allCases.map(\.rawValue).contains(p.id), (1...1000000).contains(p.version),
                  ["standard", "voice"].contains(p.mapping), !p.title.isEmpty, !p.titleEN.isEmpty,
                  [p.title,p.titleEN,p.detail,p.detailEN].allSatisfy({ $0.count <= 400 }),
                  Set(p.sounds.keys) == Set(DropKind.allCases.map(\.rawValue)) else { throw LibraryError.invalid }
            let assets = p.sounds.values.flatMap { $0 }
            guard assets.count <= 20, p.sounds.values.allSatisfy({ !$0.isEmpty }), assets.reduce(0, { $0 + min(max($1.bytes,0),1000001) }) <= 5000000 else { throw LibraryError.invalid }
            for a in assets {
                guard (44...1000000).contains(a.bytes),
                      a.path.range(of: "^/sound-library/assets/[a-zA-Z0-9_-]+\\.wav$", options: .regularExpression) != nil,
                      a.sha256.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else { throw LibraryError.invalid }
            }
        }
    }
}
enum LibraryError: Error { case invalid, network, tooLarge, checksum }

// Downloads are limited while receiving data, accept HTTPS only, and reject redirects.
final class LimitedFetch: NSObject, URLSessionDataDelegate {
    private var data = Data()
    private let limit: Int
    private var continuation: CheckedContinuation<Data, Error>?
    private var session: URLSession?
    init(limit: Int) { self.limit = limit }
    static func get(_ url: URL, limit: Int) async throws -> Data {
        let fetch = LimitedFetch(limit: limit)
        return try await withCheckedThrowingContinuation { c in
            fetch.continuation = c
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 20; config.timeoutIntervalForResource = 45
            config.httpShouldSetCookies = false; config.urlCache = nil
            fetch.session = URLSession(configuration: config, delegate: fetch, delegateQueue: nil)
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.setValue("RainyDesk/1.5", forHTTPHeaderField: "User-Agent")
            fetch.session!.dataTask(with: request).resume()
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let r = response as? HTTPURLResponse, r.statusCode == 200, response.expectedContentLength <= limit else { completionHandler(.cancel); return }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard self.data.count + data.count <= limit else { dataTask.cancel(); return }
        self.data.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let c = continuation; continuation = nil
        if let error { c?.resume(throwing: error) } else { c?.resume(returning: data) }
        session.finishTasksAndInvalidate(); self.session = nil
    }
}

final class SoundLibrary {
    static let origin = URL(string: "https://rainy-desk-sounds.shankao1008.chatgpt.site")!
    let root: URL
    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RainyDesk/SoundLibrary", isDirectory: true)
    }
    func assetURL(_ asset: SoundAsset, pack: SoundPack) -> URL {
        root.appendingPathComponent(pack.cacheKey).appendingPathComponent(asset.sha256 + ".wav")
    }
    static func verify(_ data: Data, asset: SoundAsset) throws {
        guard data.count == asset.bytes, SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == asset.sha256 else { throw LibraryError.checksum }
    }
    static func verifyAudio(_ url: URL) throws {
        let f = try AVAudioFile(forReading: url)
        guard f.processingFormat.sampleRate == 44100, f.processingFormat.channelCount == 1,
              f.length > 0, f.length <= 441000,
              let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length)) else { throw LibraryError.invalid }
        try f.read(into: b)
        guard let values = b.floatChannelData?[0] else { throw LibraryError.invalid }
        for i in 0..<Int(b.frameLength) { guard values[i].isFinite, abs(values[i]) <= 0.601 else { throw LibraryError.invalid } }
    }
    func cached() -> [SoundPack] {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("catalog.json")), data.count <= 512000,
              let catalog = try? JSONDecoder().decode(SoundCatalog.self, from: data), (try? catalog.validate()) != nil else { return [] }
        return catalog.packs.filter { pack in
            pack.sounds.values.flatMap { $0 }.allSatisfy { a in
                guard let d = try? Data(contentsOf: assetURL(a, pack: pack)) else { return false }
                return (try? Self.verify(d, asset: a)) != nil
            }
        }
    }
    // Only switch the catalog after EVERY sample succeeds. Old sounds survive offline/failure.
    func sync(fetch: (URL, Int) async throws -> Data = { try await LimitedFetch.get($0, limit: $1) }) async throws -> [SoundPack] {
        let data = try await fetch(Self.origin.appendingPathComponent("sound-library/catalog.json"), 512000)
        guard data.count <= 512000 else { throw LibraryError.tooLarge }
        let incoming = try JSONDecoder().decode(SoundCatalog.self, from: data)
        try incoming.validate()
        var merged = Dictionary(uniqueKeysWithValues: cached().map { ($0.id,$0) })
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for pack in incoming.packs {
            if let old = merged[pack.id], old.version > pack.version { continue }
            if let old = merged[pack.id], old.version == pack.version, old != pack { throw LibraryError.invalid }
            let folder = root.appendingPathComponent(pack.cacheKey)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for a in Set(pack.sounds.values.flatMap { $0 }) {
                let file = assetURL(a, pack: pack)
                if let existing = try? Data(contentsOf: file), (try? Self.verify(existing, asset: a)) != nil { continue }
                let bytes = try await fetch(Self.origin.appendingPathComponent(String(a.path.dropFirst())), a.bytes)
                try Self.verify(bytes, asset: a)
                let temporary = root.appendingPathComponent(UUID().uuidString + ".wav")
                defer { try? FileManager.default.removeItem(at: temporary) }
                try bytes.write(to: temporary, options: .atomic)
                try Self.verifyAudio(temporary)
                try bytes.write(to: file, options: .atomic)
            }
            merged[pack.id] = pack
        }
        guard merged.count <= 50 else { throw LibraryError.tooLarge }
        let catalog = SoundCatalog(schema: 1, packs: merged.values.sorted { $0.id < $1.id })
        try catalog.validate()
        try JSONEncoder().encode(catalog).write(to: root.appendingPathComponent("catalog.json"), options: .atomic)
        return catalog.packs
    }
}
