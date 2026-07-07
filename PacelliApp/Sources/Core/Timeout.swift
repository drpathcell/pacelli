import Foundation

struct TimeoutError: Error, Equatable {}

/// Races `operation` against a deadline. Firestore/Auth calls have no
/// caller-side timeout and can stall indefinitely on stale sessions or
/// broken streams (build 26 lesson: "Loading your home…" forever on a
/// device with a leftover Flutter-era keychain session). Every await on
/// the session/data path goes through this.
func withTimeout<T: Sendable>(
    _ seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        guard let result = try await group.next() else { throw TimeoutError() }
        group.cancelAll()
        return result
    }
}
