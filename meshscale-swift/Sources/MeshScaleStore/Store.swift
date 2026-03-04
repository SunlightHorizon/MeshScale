import Foundation

public protocol MeshScaleStoreClient: Sendable {
    func get(_ key: String) async throws -> Data?
    func set(_ value: Data, for key: String) async throws
    func delete(_ key: String) async throws
}

public actor InMemoryStore: MeshScaleStoreClient {
    private var storage: [String: Data] = [:]

    public init() {}

    public func get(_ key: String) async throws -> Data? {
        storage[key]
    }

    public func set(_ value: Data, for key: String) async throws {
        storage[key] = value
    }

    public func delete(_ key: String) async throws {
        storage.removeValue(forKey: key)
    }
}

public actor FoundationDBStore: MeshScaleStoreClient {
    private let fallback = InMemoryStore()
    private let clusterFilePath: String?

    public init(clusterFilePath: String? = nil) {
        self.clusterFilePath = clusterFilePath
    }

    public func get(_ key: String) async throws -> Data? {
        _ = clusterFilePath
        // TODO: Replace fallback with real FoundationDB reads.
        return try await fallback.get(key)
    }

    public func set(_ value: Data, for key: String) async throws {
        _ = clusterFilePath
        // TODO: Replace fallback with real FoundationDB writes.
        try await fallback.set(value, for: key)
    }

    public func delete(_ key: String) async throws {
        _ = clusterFilePath
        // TODO: Replace fallback with real FoundationDB deletes.
        try await fallback.delete(key)
    }
}
