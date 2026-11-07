public import Git_Standard
internal import Path
private import Process

extension Git {

    public struct Client: Sendable {
        public let executable: Swift.String

        public init(executable: Swift.String = Git.Client.installed) {
            self.executable = executable
        }
    }
}

extension Git.Client {
    private func execute(
        _ arguments: [Swift.String],
        at directory: Path::Path? = nil
    ) throws(Error) -> Process.Output {
        do throws(Process.Error) {
            return try Process.Spawn.run(
                .init(
                    executable: executable,
                    arguments: arguments,
                    stdout: .pipe,
                    stderr: .pipe,
                    directory: directory
                )
            )
        } catch {
            throw .execution(executable: executable, reason: "\(error)")
        }
    }

    internal func bytes(
        _ arguments: [Swift.String],
        at directory: Path::Path? = nil
    ) throws(Error) -> [UInt8] {
        let output = try execute(arguments, at: directory)
        guard output.status == .exited(code: 0) else {
            throw .command(
                arguments: arguments,
                termination: termination(output.status),
                stdout: output.stdout ?? [],
                stderr: output.stderr ?? []
            )
        }
        return output.stdout ?? []
    }

    private func termination(_ status: Process.Status) -> Termination {
        switch status {
        case .exited(let code):
            return .exited(code: code)

        case .signaled(let signal):
            return .signaled(signal: signal)

        case .stopped(let signal):
            return .stopped(signal: signal)
        }
    }

    internal func result(
        _ arguments: [Swift.String],
        at directory: Path::Path? = nil
    ) throws(Error) -> (termination: Termination, stdout: [UInt8], stderr: [UInt8]) {
        let output = try execute(arguments, at: directory)
        return (
            termination: termination(output.status),
            stdout: output.stdout ?? [],
            stderr: output.stderr ?? []
        )
    }

    internal func text(
        _ arguments: [Swift.String],
        at directory: Path::Path? = nil
    ) throws(Error) -> Swift.String {
        let bytes = try bytes(arguments, at: directory)
        var start = bytes.startIndex
        var end = bytes.endIndex
        while start < end, [9, 10, 13, 32].contains(bytes[start]) {
            start = bytes.index(after: start)
        }
        while start < end, [9, 10, 13, 32].contains(bytes[bytes.index(before: end)]) {
            end = bytes.index(before: end)
        }
        return Swift.String(decoding: bytes[start..<end], as: UTF8.self)
    }
}

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

#if canImport(Darwin)
    private import Darwin
#elseif canImport(Glibc)
    private import Glibc
#elseif canImport(Musl)
    private import Musl
#elseif canImport(WinSDK)
    private import WinSDK
#endif

extension Git.Client {

    public static var installed: Swift.String {
        for directory in searchDirectories() {
            for name in executableNames {
                let candidate = "\(directory)\(separator)\(name)"
                if isExecutable(candidate) { return candidate }
            }
        }
        return conventionalPath
    }

    #if os(Windows)
        static let executableNames = ["git.exe"]
    #else
        static let executableNames = ["git"]
    #endif

    #if os(Windows)
        static let conventionalPath = #"C:\Program Files\Git\cmd\git.exe"#
    #else
        static let conventionalPath = "/usr/bin/git"
    #endif

    #if os(Windows)
        static let separator: Swift.String = #"\"#
    #else
        static let separator: Swift.String = "/"
    #endif

    #if os(Windows)
        static let pathListSeparator: Swift.Character = ";"
    #else
        static let pathListSeparator: Swift.Character = ":"
    #endif

    static func searchDirectories() -> [Swift.String] {
        guard let path = environmentValue("PATH") else { return [] }
        return
            path
            .split(separator: pathListSeparator, omittingEmptySubsequences: true)
            .map(Swift.String.init)
    }

    static func isExecutable(_ path: Swift.String) -> Swift.Bool {
        #if os(Windows)
            return path.withCString(encodedAs: UTF16.self) { wide in
                let attributes = unsafe GetFileAttributesW(wide)
                guard attributes != DWORD.max else { return false }
                return attributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) == 0
            }
        #else
            return path.withCString { unsafe access($0, X_OK) == 0 }
        #endif
    }

    static func environmentValue(_ name: Swift.String) -> Swift.String? {
        #if os(Windows)
            return name.withCString(encodedAs: UTF16.self) { wide -> Swift.String? in

                let capacity = unsafe GetEnvironmentVariableW(wide, nil, 0)
                guard capacity > 0 else { return nil }
                var buffer = [WCHAR](repeating: 0, count: Swift.Int(capacity))
                let written = unsafe GetEnvironmentVariableW(wide, &buffer, capacity)
                guard written > 0, written < capacity else { return nil }
                return Swift.String(decoding: buffer[..<Swift.Int(written)], as: UTF16.self)
            }
        #else
            guard let value = unsafe getenv(name) else { return nil }
            return unsafe Swift.String(cString: value)
        #endif
    }
}

extension Git.Client {
    public func initialize(at directory: Path::Path, bare: Swift.Bool) throws(Error) {
        var arguments = ["init"]
        if bare {
            arguments.append("--bare")
        }
        arguments.append(directory.string)
        _ = try bytes(arguments)
    }

    public func fetch(
        _ remote: Swift.String,
        ref: Git.Ref.Name,
        into destination: Git.Ref.Name? = nil,
        at directory: Path::Path
    ) throws(Error) {
        let specification = destination.map { "\(ref.rawValue):\($0.rawValue)" } ?? ref.rawValue
        _ = try bytes(["fetch", "--no-tags", remote, specification], at: directory)
    }

    public func fetch(
        _ remote: Swift.String,
        object: Git.Object.ID,
        into destination: Git.Ref.Name,
        at directory: Path::Path
    ) throws(Error) {
        let specification = "\(object.rawValue):\(destination.rawValue)"
        _ = try bytes(["fetch", "--no-tags", remote, specification], at: directory)
    }

    public func merge(
        _ reference: Swift.String,
        mode: Git.Merge.Mode,
        at directory: Path::Path
    ) throws(Error) {
        var arguments = ["merge"]
        if mode == .fast {
            arguments.append("--ff-only")
        }
        arguments.append(reference)
        _ = try bytes(arguments, at: directory)
    }

    /// Clones `remote` into `directory`.
    ///
    /// A `depth` truncates history to that many commits of the cloned
    /// branch (`--depth`, which implies `--single-branch`). Git honours it
    /// only for a transport remote: a plain local path ignores it, so a
    /// local shallow clone spells its remote `file://<path>`.
    public func clone(
        _ remote: Swift.String,
        branch: Swift.String? = nil,
        depth: Swift.Int? = nil,
        bare: Swift.Bool = false,
        checkout: Swift.Bool = true,
        to directory: Path::Path
    ) throws(Error) {
        var arguments = ["clone", "--origin", "origin", "--no-tags"]
        if let branch {
            arguments += ["--single-branch", "--branch", branch]
        }
        if let depth {
            arguments += ["--depth", "\(depth)"]
        }
        if bare {
            arguments.append("--bare")
        }
        if !checkout {
            arguments.append("--no-checkout")
        }
        arguments += [remote, directory.string]
        _ = try bytes(arguments)
    }

    public func checkout(
        detached object: Git.Object.ID,
        at directory: Path::Path
    ) throws(Error) {
        _ = try bytes(["checkout", "--detach", object.rawValue], at: directory)
    }

    public func `switch`(_ branch: Swift.String, at directory: Path::Path) throws(Error) {
        _ = try bytes(["switch", branch], at: directory)
    }

    public func track(
        _ branch: Swift.String,
        upstream: Swift.String,
        at directory: Path::Path
    ) throws(Error) {
        _ = try bytes(["branch", "--set-upstream-to=\(upstream)", branch], at: directory)
    }

    /// Stages exactly `paths` (relative to `directory`) for the next commit.
    public func add(_ paths: [Swift.String], at directory: Path::Path) throws(Error) {
        _ = try bytes(["add", "--"] + paths, at: directory)
    }

    /// Records the staged changes as one commit with `message` under the
    /// configured identity, and returns the new `HEAD`.
    ///
    /// Only what is staged is committed; nothing is staged implicitly.
    public func commit(
        message: Swift.String,
        at directory: Path::Path
    ) throws(Error)
        -> Git.Object.ID
    {
        _ = try bytes(["commit", "--quiet", "--message", message], at: directory)
        return try head(at: directory)
    }
}

extension Git.Client {

    public func probe(
        _ remote: Swift.String,
        ref: Git.Ref.Name
    ) throws(Error) -> Git.Ref.Advertisement {
        let output = try bytes(["ls-remote", "--refs", "--exit-code", remote, ref.rawValue])
        let records: [Git.Ref.Advertisement]
        do throws(Git.Ref.Advertisement.Error) {
            records = try Git.Ref.Advertisement.parse(output)
        } catch {
            throw .advertisement(error)
        }
        guard let record = records.first(where: { $0.name == ref }) else {
            throw .missing(ref)
        }
        return record
    }
}

extension Git.Client {
    public func repository(at directory: Path::Path) throws(Error) -> Swift.Bool {
        do throws(Error) {
            return try text(["rev-parse", "--is-inside-work-tree"], at: directory) == "true"
        } catch {
            if case .command = error {
                return false
            }
            throw error
        }
    }

    public func top(at directory: Path::Path) throws(Error) -> Swift.String {
        try text(["rev-parse", "--show-toplevel"], at: directory)
    }

    public func remote(
        _ name: Swift.String,
        at directory: Path::Path
    ) throws(Error) -> Swift.String {
        try text(["remote", "get-url", name], at: directory)
    }

    public func branch(at directory: Path::Path) throws(Error) -> Swift.String {
        try text(["branch", "--show-current"], at: directory)
    }

    public func upstream(
        _ branch: Swift.String,
        at directory: Path::Path
    ) throws(Error) -> Swift.String {
        try text(
            ["for-each-ref", "--format=%(upstream:short)", "refs/heads/\(branch)"],
            at: directory
        )
    }

    public func head(
        _ reference: Swift.String = "HEAD",
        at directory: Path::Path
    ) throws(Error) -> Git.Object.ID {
        let value = try text(["rev-parse", reference], at: directory)
        guard let object = Git.Object.ID(rawValue: value) else {
            throw .object(value)
        }
        return object
    }

    public func contains(
        commit object: Git.Object.ID,
        at directory: Path::Path
    ) throws(Error) -> Swift.Bool {
        let arguments = ["cat-file", "-e", "\(object.rawValue)^{commit}"]
        let result = try result(arguments, at: directory)
        switch result.termination {
        case .exited(code: 0):
            return true

        case .exited(code: 1), .exited(code: 128):
            return false

        default:
            throw .command(
                arguments: arguments,
                termination: result.termination,
                stdout: result.stdout,
                stderr: result.stderr
            )
        }
    }

    public func tree(
        of object: Git.Object.ID,
        at directory: Path::Path
    ) throws(Error) -> Git.Object.ID {
        let value = try text(["rev-parse", "\(object.rawValue)^{tree}"], at: directory)
        guard let tree = Git.Object.ID(rawValue: value) else {
            throw .object(value)
        }
        return tree
    }

    public func count(_ range: Swift.String, at directory: Path::Path) throws(Error) -> Swift.Int {
        let value = try text(["rev-list", "--count", range], at: directory)
        guard let count = Swift.Int(value) else {
            throw .count(value)
        }
        return count
    }

    public func ancestor(
        _ ancestor: Git.Object.ID,
        of descendant: Git.Object.ID,
        at directory: Path::Path
    ) throws(Error) -> Swift.Bool {
        let arguments = ["merge-base", "--is-ancestor", ancestor.rawValue, descendant.rawValue]
        let result = try result(arguments, at: directory)
        switch result.termination {
        case .exited(code: 0):
            return true

        case .exited(code: 1):
            return false

        default:
            throw .command(
                arguments: arguments,
                termination: result.termination,
                stdout: result.stdout,
                stderr: result.stderr
            )
        }
    }

    public func status(at directory: Path::Path) throws(Error) -> [Git.Status.Entry] {
        let output = try bytes(
            ["status", "--porcelain=v1", "-z", "--untracked-files=normal"],
            at: directory
        )
        do throws(Git.Status.Error) {
            return try Git.Status.parse(output)
        } catch {
            throw .status(error)
        }
    }
}
