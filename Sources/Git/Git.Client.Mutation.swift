public import Git_Standard

extension Git.Client {
    public func initialize(at directory: Swift.String, bare: Swift.Bool) throws(Error) {
        var arguments = ["init"]
        if bare {
            arguments.append("--bare")
        }
        arguments.append(directory)
        _ = try bytes(arguments)
    }

    public func fetch(
        _ remote: Swift.String,
        ref: Git.Ref.Name,
        into destination: Git.Ref.Name? = nil,
        at directory: Swift.String
    ) throws(Error) {
        let specification = destination.map { "\(ref.rawValue):\($0.rawValue)" } ?? ref.rawValue
        _ = try bytes(["fetch", "--no-tags", remote, specification], at: directory)
    }

    public func fetch(
        _ remote: Swift.String,
        object: Git.Object.ID,
        into destination: Git.Ref.Name,
        at directory: Swift.String
    ) throws(Error) {
        let specification = "\(object.rawValue):\(destination.rawValue)"
        _ = try bytes(["fetch", "--no-tags", remote, specification], at: directory)
    }

    public func merge(
        _ reference: Swift.String,
        mode: Git.Merge.Mode,
        at directory: Swift.String
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
        to directory: Swift.String
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
        arguments += [remote, directory]
        _ = try bytes(arguments)
    }

    public func checkout(
        detached object: Git.Object.ID,
        at directory: Swift.String
    ) throws(Error) {
        _ = try bytes(["checkout", "--detach", object.rawValue], at: directory)
    }

    public func `switch`(_ branch: Swift.String, at directory: Swift.String) throws(Error) {
        _ = try bytes(["switch", branch], at: directory)
    }

    public func track(
        _ branch: Swift.String,
        upstream: Swift.String,
        at directory: Swift.String
    ) throws(Error) {
        _ = try bytes(["branch", "--set-upstream-to=\(upstream)", branch], at: directory)
    }

    /// Stages exactly `paths` (relative to `directory`) for the next commit.
    public func add(_ paths: [Swift.String], at directory: Swift.String) throws(Error) {
        _ = try bytes(["add", "--"] + paths, at: directory)
    }

    /// Records the staged changes as one commit with `message` under the
    /// configured identity, and returns the new `HEAD`.
    ///
    /// Only what is staged is committed; nothing is staged implicitly.
    public func commit(message: Swift.String, at directory: Swift.String) throws(Error)
        -> Git.Object.ID
    {
        _ = try bytes(["commit", "--quiet", "--message", message], at: directory)
        return try head(at: directory)
    }
}
