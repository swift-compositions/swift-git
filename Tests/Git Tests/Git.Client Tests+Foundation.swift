import Foundation
import Path

enum GitFixture {
    static func makeRoot() throws -> Path::Path {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return try Path::Path(validating: root.path)
    }

    static func remove(_ path: Path::Path) {
        try? FileManager.default.removeItem(atPath: path.string)
    }

    static func path(_ base: Path::Path, _ component: Swift.String) throws -> Path::Path {
        try Path::Path(validating: URL(fileURLWithPath: base.string).appending(path: component).path)
    }

    static func write(_ contents: Swift.String, to path: Path::Path) throws {
        try contents.write(toFile: path.string, atomically: true, encoding: .utf8)
    }

    static func read(_ path: Path::Path) throws -> Swift.String {
        try Swift.String(contentsOfFile: path.string, encoding: .utf8)
            .replacingOccurrences(of: "\r\n", with: "\n")
    }

    static func exists(_ path: Path::Path) -> Bool {
        FileManager.default.fileExists(atPath: path.string)
    }

    static func unique(_ prefix: Swift.String, _ suffix: Swift.String) -> Swift.String {
        "\(prefix)\(UUID().uuidString)\(suffix)"
    }
}
