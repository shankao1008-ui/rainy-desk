import Foundation
import CryptoKit

@main struct LibraryTests {
 static func main() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let library = SoundLibrary(root: root)
    let bytes = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let asset = SoundAsset(path: "/sound-library/assets/test.wav", sha256: SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(), bytes: bytes.count)
    func pack(_ id: String, _ version: Int = 1) -> SoundPack {
      SoundPack(id: id, version: version, title: id, titleEN: id, detail: "test", detailEN: "test", mapping: "voice", sounds: Dictionary(uniqueKeysWithValues: DropKind.allCases.map { ($0.rawValue,[asset]) }))
    }
    func encoded(_ packs: [SoundPack]) throws -> Data { try JSONEncoder().encode(SoundCatalog(schema: 1, packs: packs)) }
    let one = pack("first")
    var count = 0
    let initial = try await library.sync { url, _ in
        count += 1
        return url.path.hasSuffix("catalog.json") ? try encoded([one]) : bytes
    }
    assert(initial == [one] && count == 2)
    assert(SoundLibrary(root: root).cached() == [one])
    count = 0
    _ = try await library.sync { _, _ in count += 1; return try encoded([one]) }
    assert(count == 1) // Existing verified assets are not downloaded again.
    let two = pack("second")
    _ = try await library.sync { url, _ in url.path.hasSuffix("catalog.json") ? try encoded([one,two]) : bytes }
    assert(library.cached().count == 2) // A new option without a new app binary.
    do {
       _ = try await library.sync { _, _ in throw LibraryError.network }
       fatalError("offline should fail")
    } catch { assert(library.cached().count == 2) }
    do {
       _ = try await library.sync { url, _ in url.path.hasSuffix("catalog.json") ? try encoded([pack("third")]) : Data([0]) }
       fatalError("checksum should fail")
    } catch { assert(library.cached().count == 2) }
    _ = try await library.sync { _, _ in try encoded([]) }
    assert(library.cached().count == 2) // Removing a listing doesn't remove a user's sound.
    let next = pack("first",2)
    _ = try await library.sync { url, _ in url.path.hasSuffix("catalog.json") ? try encoded([next]) : bytes }
    _ = try await library.sync { _, _ in try encoded([one]) }
    assert(library.cached().first(where: { $0.id == "first" })?.version == 2)
    for badID in ["../escape", "voice", "https://evil", "UPPER"] {
       do { try SoundCatalog(schema: 1,packs:[pack(badID)]).validate(); fatalError("bad ID accepted") } catch {}
    }
    do { try SoundCatalog(schema: 2,packs:[]).validate(); fatalError("bad schema accepted") } catch {}
    do { try SoundCatalog(schema: 1,packs:[one,one]).validate(); fatalError("duplicate accepted") } catch {}
    let badAsset = SoundAsset(path:"/../evil.wav",sha256:asset.sha256,bytes:asset.bytes)
    let badPack = SoundPack(id:"bad",version:1,title:"bad",titleEN:"bad",detail:"",detailEN:"",mapping:"voice",sounds: Dictionary(uniqueKeysWithValues: DropKind.allCases.map { ($0.rawValue,[badAsset]) }))
    do { try SoundCatalog(schema:1,packs:[badPack]).validate(); fatalError("traversal accepted") } catch {}
    print("PASS: first download, later new sound, cache reuse, offline restart, failed update rollback, checksum rejection, removal retention, version downgrade protection, manifest validation")
 }
}
