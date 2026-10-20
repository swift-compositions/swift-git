public import Git_Standard

extension Git.Client {
    public func repository(at directory: Swift.String) throws(Error) -> Swift.Bool {
        do throws(Error) {
            return try text(["rev-parse", "--is-inside-work-tree"], at: directory) == "true"
        } catch {
            if case .command = error {
                return false
            }
            throw error
        }
    }

    public func top(at directory: Swift.String) throws(Error) -> Swift.String {
        try text(["rev-parse", "--show-toplevel"], at: directory)
    }

    public func remote(
        _ name: Swift.String,
        at directory: Swift.String
    ) throws(Error) -> Swift.String {
        try text(["remote", "get-url", name], at: directory)
    }

    public func branch(at directory: Swift.String) throws(Error) -> Swift.String {
        try text(["branch", "--show-current"], at: directory)
    }

    public func upstream(
        _ branch: Swift.String,
        at directory: Swift.String
    ) throws(Error) -> Swift.String {
        try text(
            ["for-each-ref", "--format=%(upstream:short)", "refs/heads/\(branch)"],
            at: directory
        )
    }

    public func head(
        _ reference: Swift.String = "HEAD",
        at directory: Swift.String
    ) throws(Error) -> Git.Object.ID {
        let value = try text(["rev-parse", reference], at: directory)
        guard let object = Git.Object.ID(rawValue: value) else {
            throw .object(value)
        }
        return object
    }

    public func contains(
        commit object: Git.Object.ID,
        at directory: Swift.String
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
        at directory: Swift.String
    ) throws(Error) -> Git.Object.ID {
        let value = try text(["rev-parse", "\(object.rawValue)^{tree}"], at: directory)
        guard let tree = Git.Object.ID(rawValue: value) else {
            throw .object(value)
        }
        return tree
    }

    public func count(_ range: Swift.String, at directory: Swift.String) throws(Error) -> Swift.Int {
        let value = try text(["rev-list", "--count", range], at: directory)
        guard let count = Swift.Int(value) else {
            throw .count(value)
        }
        return count
    }

    public func ancestor(
        _ ancestor: Git.Object.ID,
        of descendant: Git.Object.ID,
        at directory: Swift.String
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

    public func status(at directory: Swift.String) throws(Error) -> [Git.Status.Entry] {
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
