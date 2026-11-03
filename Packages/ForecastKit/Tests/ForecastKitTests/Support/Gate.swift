/// A one-shot latch for scripting the timing of async stubs in tests.
/// `wait()` suspends until `open()` is called; calls made after `open()` return immediately.
final class Gate: Sendable {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream(of: Void.self)
    }

    func open() {
        continuation.finish()
    }

    func wait() async {
        for await _ in stream {}
    }
}
