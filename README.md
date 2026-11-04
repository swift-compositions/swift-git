# swift-git

Use this package when a Swift tool needs to drive the installed `git` on a local repository: clone, fetch, commit, check out, and read back state such as the current commit, ancestry, status and file list as typed values. Start from `Git.Client`. If you only need to parse Git's own output formats, such as porcelain status or a ref advertisement, without running `git`, use swift-git-standard, which this package re-exports. For the GitHub API, use swift-github.

## Laws

- `Git.Client` runs `git` as a subprocess for every call, with no timeout. By default it uses the first executable `git` on `PATH` when the client is created, and falls back to `/usr/bin/git`, or the standard Git for Windows path.
- A non-zero exit fails with the arguments, the termination and both output streams, with these exceptions. `Git.Client.repository(at:)` returns false for any failing `git` command. `Git.Client.contains(commit:at:)` returns false for exit codes 1 and 128. `Git.Client.ancestor(_:of:at:)` returns false for exit code 1.
- Text results are trimmed of surrounding spaces, tabs and line breaks. `Git.Client.branch(at:)` returns an empty string on a detached HEAD, and `Git.Client.upstream(_:at:)` returns an empty string for a branch with no upstream.
- Fetches and clones never fetch tags. A clone names its remote `origin`, and a clone of one branch fetches only that branch.
- A clone with `depth` truncates history only when the remote is a transport URL. Git ignores `depth` for a plain local path, so a shallow local clone needs a `file://` remote.
- `Git.Merge.Mode.fast` allows only a fast-forward. `Git.Merge.Mode.any` lets Git create a merge commit.
- `Git.Client.commit(message:at:)` records only what is already staged, under the identity Git is configured with, and returns the new HEAD.
- `Git.Client.probe(_:ref:)` asks the remote for the ref with `--exit-code`. A remote with no matching ref fails as a command with exit code 2. The missing-ref error appears only when the remote matched other refs ending in the same name but not the exact one.
- `Git.Client.status(at:)` reports an untracked directory as one entry rather than listing its files.
- `Git.Client.paths(at:)` lists tracked files and untracked files that aren't ignored, sorted. A path that isn't valid UTF-8, or one listed twice, fails.
