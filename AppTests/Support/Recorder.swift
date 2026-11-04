/// Collects values passed to async stubs so tests can assert on them.
actor Recorder<Value: Sendable> {
    private(set) var values: [Value] = []

        func append(_ value: Value) {
        values.append(value)
    }
}
