import Foundation

public actor NamespacedStoreClient: MeshScaleStoreClient {
    private let base: any MeshScaleStoreClient
    private let namespace: String

    public init(base: any MeshScaleStoreClient, namespace: String) {
        self.base = base
        self.namespace = namespace.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func set(_ value: Data, for key: String) async throws {
        try await base.set(value, for: namespaced(key))
    }

    public func get(_ key: String) async throws -> Data? {
        try await base.get(namespaced(key))
    }

    public func delete(_ key: String) async throws {
        try await base.delete(namespaced(key))
    }

    public func list(prefix: String) async throws -> [String: Data] {
        let fullPrefix = namespaced(prefix)
        let entries = try await base.list(prefix: fullPrefix)
        guard !namespace.isEmpty else {
            return entries
        }

        let prefixToStrip = namespace + "/"
        return Dictionary(
            uniqueKeysWithValues: entries.map { key, value in
                let trimmed = key.hasPrefix(prefixToStrip)
                    ? String(key.dropFirst(prefixToStrip.count))
                    : key
                return (trimmed, value)
            }
        )
    }

    public func backendDescription() async -> String {
        let baseDescription = await base.backendDescription()
        guard !namespace.isEmpty else {
            return baseDescription
        }
        return "\(baseDescription) [namespace=\(namespace)]"
    }

    private func namespaced(_ key: String) -> String {
        guard !namespace.isEmpty else {
            return key
        }
        return "\(namespace)/\(key)"
    }
}

public enum MeshScaleStoreFactory {
    public static func makeStore(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        namespace overrideNamespace: String? = nil
    ) -> any MeshScaleStoreClient {
        let base: any MeshScaleStoreClient = FoundationDBStore(
            clusterFilePath: environment["MESHCALE_FDB_CLUSTER_FILE"]
                ?? environment["MESH_SCALE_FDB_CLUSTER_FILE"]
                ?? environment["FOUNDATIONDB_CLUSTER_FILE"]
                ?? environment["FDB_CLUSTER_FILE"]
        )
        let namespace = overrideNamespace ?? environment["MESHCALE_STORE_NAMESPACE"]
        guard let namespace, !namespace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return base
        }
        return NamespacedStoreClient(base: base, namespace: namespace)
    }
}
