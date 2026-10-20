import Foundation

enum GitFixture {
    static func makeRoot() throws -> String {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.path
    }

    static func remove(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    static func path(_ base: String, _ component: String) -> String {
        URL(fileURLWithPath: base).appending(path: component).path
    }

    static func write(_ contents: String, to path: String) throws {
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func read(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
            .replacingOccurrences(of: "\r\n", with: "\n")
    }

    static func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    static func unique(_ prefix: String, _ suffix: String) -> String {
        "\(prefix)\(UUID().uuidString)\(suffix)"
    }
}
