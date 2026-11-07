public import Git_Standard

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
