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
