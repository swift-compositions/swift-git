import Testing

@testable import Git_Foundation

extension Git.Client {
    @Suite
    struct Test {
        @Test
        func `repository state and status use typed operations`() throws {
            let root = try GitFixture.makeRoot()

            defer { GitFixture.remove(root) }

            let client = Git.Client()
            try client.initialize(at: root, bare: false)

            #expect(try client.repository(at: root))
            #expect(try client.status(at: root).isEmpty)

            let top = try client.top(at: root)

            let sentinel = GitFixture.unique("Sentinel-", ".txt")
            try GitFixture.write("sentinel\n", to: GitFixture.path(root, sentinel))
            #expect(GitFixture.exists("\(top)/\(sentinel)"))
        }

        @Test
        func `isolated fetch compares refs without changing source metadata`() throws {
            let root = try GitFixture.makeRoot()
            let source = GitFixture.path(root, "source.git")
            let probe = GitFixture.path(root, "probe.git")

            defer { GitFixture.remove(root) }

            let client = Git.Client()
            try client.initialize(at: source, bare: true)
            try client.initialize(at: probe, bare: true)

            let ref = try Git.Ref.Name("refs/heads/main")
            let destination = try Git.Ref.Name("refs/probe/local")
            let started = ContinuousClock.now
            var failure: Git.Client.Error?
            do throws(Git.Client.Error) {
                try client.fetch(source, ref: ref, into: destination, at: probe)
            } catch {
                failure = error
            }
            let elapsed = ContinuousClock.now - started
            #expect(elapsed < .seconds(10), "fetch took \(elapsed)")
            guard case .command(_, let termination, _, let stderr) = try #require(failure) else {
                Issue.record("expected a git command failure, got \(String(describing: failure))")
                return
            }
            #expect(termination == .exited(code: 128), "git ended with \(termination)")
            let diagnostics = Swift.String(decoding: stderr, as: UTF8.self)
            #expect(
                diagnostics.contains("couldn't find remote ref refs/heads/main"),
                "unexpected git stderr: \(diagnostics)"
            )
        }

        @Test
        func `isolated clone proves ancestry and exact object fetch`() throws {
            let root = try GitFixture.makeRoot()
            let source = GitFixture.path(root, "source")
            let remote = GitFixture.path(root, "remote.git")
            let probe = GitFixture.path(root, "probe.git")

            defer { GitFixture.remove(root) }

            let client = Git.Client()
            try client.initialize(at: source, bare: false)
            try command(client, ["config", "user.email", "workspace@swift.institute"], at: source)
            try command(client, ["config", "user.name", "Workspace Tests"], at: source)
            try command(client, ["branch", "-M", "main"], at: source)

            let fixture = GitFixture.path(source, "Fixture.txt")
            try GitFixture.write("first\n", to: fixture)
            try command(client, ["add", "Fixture.txt"], at: source)
            try command(client, ["commit", "-m", "first"], at: source)
            let first = try client.head(at: source)

            try GitFixture.write("second\n", to: fixture)
            try command(client, ["add", "Fixture.txt"], at: source)
            try command(client, ["commit", "-m", "second"], at: source)
            let second = try client.head(at: source)

            try client.clone(source, branch: "main", bare: true, to: remote)
            #expect(try client.ancestor(first, of: second, at: remote))

            try client.initialize(at: probe, bare: true)
            let destination = try Git.Ref.Name("refs/probe/main")
            try client.fetch(remote, object: second, into: destination, at: probe)
            #expect(try client.head(destination.rawValue, at: probe) == second)
        }

        @Test
        func `exact object primitives answer from the store, not from refs`() throws {
            let root = try GitFixture.makeRoot()
            let source = GitFixture.path(root, "source")
            let clone = GitFixture.path(root, "clone")

            defer { GitFixture.remove(root) }

            let client = Git.Client()
            try client.initialize(at: source, bare: false)
            try command(client, ["config", "user.email", "workspace@swift.institute"], at: source)
            try command(client, ["config", "user.name", "Workspace Tests"], at: source)
            try command(client, ["branch", "-M", "main"], at: source)

            let fixture = GitFixture.path(source, "Fixture.txt")
            try GitFixture.write("first\n", to: fixture)
            try command(client, ["add", "Fixture.txt"], at: source)
            try command(client, ["commit", "-m", "first"], at: source)
            let first = try client.head(at: source)

            try GitFixture.write("second\n", to: fixture)
            try command(client, ["add", "Fixture.txt"], at: source)
            try command(client, ["commit", "-m", "second"], at: source)
            let second = try client.head(at: source)

            #expect(try client.contains(commit: first, at: source))
            #expect(try client.contains(commit: second, at: source))
            let absent = try #require(
                Git.Object.ID(rawValue: Swift.String(repeating: "a", count: 40))
            )
            #expect(try !client.contains(commit: absent, at: source))

            let firstTree = try client.tree(of: first, at: source)
            let secondTree = try client.tree(of: second, at: source)
            #expect(firstTree != secondTree)

            try client.clone(source, branch: "main", checkout: false, to: clone)
            #expect(!GitFixture.exists(GitFixture.path(clone, "Fixture.txt")))
            try client.checkout(detached: first, at: clone)
            #expect(try client.head(at: clone) == first)
            #expect(try client.tree(of: first, at: clone) == firstTree)
            #expect(try client.status(at: clone).isEmpty)
            #expect(
                try GitFixture.read(GitFixture.path(clone, "Fixture.txt")) == "first\n"
            )

            try GitFixture.write("third\n", to: fixture)
            try command(client, ["add", "Fixture.txt"], at: source)
            try command(client, ["commit", "-m", "third"], at: source)
            #expect(try client.head(at: clone) == first)
        }

        @Test
        func `add and commit record exactly the staged paths`() throws {
            let root = try GitFixture.makeRoot()
            let source = GitFixture.path(root, "source")

            defer { GitFixture.remove(root) }

            let client = Git.Client()
            try client.initialize(at: source, bare: false)
            try command(client, ["config", "user.email", "workspace@swift.institute"], at: source)
            try command(client, ["config", "user.name", "Workspace Tests"], at: source)

            try GitFixture.write("staged\n", to: GitFixture.path(source, "Staged.txt"))
            try GitFixture.write("left\n", to: GitFixture.path(source, "Left.txt"))
            try client.add(["Staged.txt"], at: source)
            let first = try client.commit(message: "first", at: source)
            #expect(try client.head(at: source) == first)
            #expect(try client.count("HEAD", at: source) == 1)

            let remaining = try client.status(at: source)
            #expect(remaining.count == 1, "only the unstaged file remains: \(remaining)")

            try GitFixture.write("staged again\n", to: GitFixture.path(source, "Staged.txt"))
            try client.add(["Staged.txt"], at: source)
            let second = try client.commit(message: "second", at: source)
            #expect(second != first)
            #expect(try client.ancestor(first, of: second, at: source))
        }

        @Test
        func `a depth clone over a transport remote truncates history`() throws {
            let root = try GitFixture.makeRoot()
            let source = GitFixture.path(root, "source")
            let full = GitFixture.path(root, "full")
            let shallow = GitFixture.path(root, "shallow")

            defer { GitFixture.remove(root) }

            let client = Git.Client()
            try client.initialize(at: source, bare: false)
            try command(client, ["config", "user.email", "workspace@swift.institute"], at: source)
            try command(client, ["config", "user.name", "Workspace Tests"], at: source)
            let fixture = GitFixture.path(source, "Fixture.txt")
            for revision in ["first", "second", "third"] {
                try GitFixture.write("\(revision)\n", to: fixture)
                try client.add(["Fixture.txt"], at: source)
                _ = try client.commit(message: revision, at: source)
            }
            let head = try client.head(at: source)

            try client.clone("file://\(source)", to: full)
            #expect(try client.count("HEAD", at: full) == 3)

            try client.clone("file://\(source)", depth: 1, to: shallow)
            #expect(try client.head(at: shallow) == head)
            #expect(try client.count("HEAD", at: shallow) == 1)
            #expect(try GitFixture.read(GitFixture.path(shallow, "Fixture.txt")) == "third\n")
        }
    }
}

private func command(
    _ client: Git.Client,
    _ arguments: [Swift.String],
    at directory: Swift.String
) throws(Git.Client.Error) {
    _ = try client.bytes(arguments, at: directory)
}
