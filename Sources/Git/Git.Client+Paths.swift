public import Git_Standard
public import Path

extension Git.Client {
    public func paths(at directory: Path::Path) throws(Error) -> [Swift.String] {
        let output = try bytes(
            ["ls-files", "-z", "--cached", "--others", "--exclude-standard"],
            at: directory
        )
        var paths: [Swift.String] = []
        var start = output.startIndex
        while start < output.endIndex {
            guard let end = output[start...].firstIndex(of: 0) else {
                throw .paths("unterminated Git path record")
            }
            let bytes = output[start..<end]
            guard let path = Swift.String(validating: bytes, as: Swift.UTF8.self), !path.isEmpty
            else {
                throw .paths("invalid Git path")
            }
            paths.append(path)
            start = output.index(after: end)
        }
        guard Set(paths).count == paths.count else { throw .paths("duplicate Git path") }
        return paths.sorted()
    }
}
