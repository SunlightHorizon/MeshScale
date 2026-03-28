import CFoundationDBShim
import Foundation

public protocol MeshScaleStoreClient: Sendable {
    func get(_ key: String) async throws -> Data?
    func set(_ value: Data, for key: String) async throws
    func delete(_ key: String) async throws
    func list(prefix: String) async throws -> [String: Data]
    func backendDescription() async -> String
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

    public func list(prefix: String) async throws -> [String: Data] {
        Dictionary(
            uniqueKeysWithValues: storage
                .filter { $0.key.hasPrefix(prefix) }
                .sorted { $0.key < $1.key }
        )
    }

    public func backendDescription() async -> String {
        "in-memory"
    }
}

public actor FoundationDBStore: MeshScaleStoreClient {
    private enum Backend {
        case unresolved
        case foundationdb(FoundationDBDatabaseHandle)
    }

    private let clusterFilePath: String?
    private var backend: Backend = .unresolved

    public init(clusterFilePath: String? = nil) {
        self.clusterFilePath = clusterFilePath ?? FoundationDBStore.defaultClusterFilePath()
    }

    public func backendDescription() async -> String {
        if let clusterFilePath {
            return "foundationdb (\(clusterFilePath))"
        }
        return "foundationdb (default cluster file)"
    }

    public func get(_ key: String) async throws -> Data? {
        try resolveDatabase().get(key: key)
    }

    public func set(_ value: Data, for key: String) async throws {
        try resolveDatabase().set(value: value, key: key)
    }

    public func delete(_ key: String) async throws {
        try resolveDatabase().clear(key: key)
    }

    public func list(prefix: String) async throws -> [String: Data] {
        try resolveDatabase().list(prefix: prefix)
    }

    private func resolveDatabase() throws -> FoundationDBDatabaseHandle {
        switch backend {
        case .foundationdb(let handle):
            return handle
        case .unresolved:
            try FoundationDBRuntime.shared.ensureStarted()
            let handle = try FoundationDBDatabaseHandle(clusterFilePath: clusterFilePath)
            backend = .foundationdb(handle)
            return handle
        }
    }

    private static func defaultClusterFilePath() -> String? {
        let environment = ProcessInfo.processInfo.environment
        return environment["MESHCALE_FDB_CLUSTER_FILE"]
            ?? environment["MESH_SCALE_FDB_CLUSTER_FILE"]
            ?? environment["FOUNDATIONDB_CLUSTER_FILE"]
            ?? environment["FDB_CLUSTER_FILE"]
    }
}

private enum FoundationDBStoreError: Error, LocalizedError {
    case apiVersionSelection(code: fdb_error_t)
    case networkSetup(code: fdb_error_t)
    case createDatabase(code: fdb_error_t, path: String?)
    case futureFailure(context: String, code: fdb_error_t)
    case futureTimeout(context: String, seconds: TimeInterval)
    case invalidRangePrefix(String)
    case invalidUTF8Key

    var errorDescription: String? {
        switch self {
        case .apiVersionSelection(let code):
            return "FoundationDB API selection failed: \(FoundationDBStoreError.describe(code))"
        case .networkSetup(let code):
            return "FoundationDB network setup failed: \(FoundationDBStoreError.describe(code))"
        case .createDatabase(let code, let path):
            if let path {
                return "FoundationDB could not open database at cluster file \(path): \(FoundationDBStoreError.describe(code))"
            }
            return "FoundationDB could not open the default database: \(FoundationDBStoreError.describe(code))"
        case .futureFailure(let context, let code):
            return "FoundationDB \(context) failed: \(FoundationDBStoreError.describe(code))"
        case .futureTimeout(let context, let seconds):
            return "FoundationDB \(context) timed out after \(seconds)s"
        case .invalidRangePrefix(let prefix):
            return "FoundationDB cannot list prefix \(prefix)"
        case .invalidUTF8Key:
            return "FoundationDB returned a non-UTF8 key"
        }
    }

    static func describe(_ code: fdb_error_t) -> String {
        guard let pointer = fdb_get_error(code) else {
            return "error \(code)"
        }
        return String(cString: pointer)
    }
}

private final class FoundationDBRuntime: @unchecked Sendable {
    static let shared = FoundationDBRuntime()

    private let lock = NSLock()
    private var started = false

    func ensureStarted() throws {
        lock.lock()
        defer { lock.unlock() }

        if started {
            return
        }

        let apiVersion = Int32(FDB_LATEST_API_VERSION)
        let apiCode = fdb_select_api_version_impl(apiVersion, apiVersion)
        guard apiCode == 0 else {
            throw FoundationDBStoreError.apiVersionSelection(code: apiCode)
        }

        let setupCode = fdb_setup_network()
        guard setupCode == 0 else {
            throw FoundationDBStoreError.networkSetup(code: setupCode)
        }

        Thread.detachNewThread {
            let code = fdb_run_network()
            if code != 0 {
                let message = FoundationDBStoreError.describe(code)
                FileHandle.standardError.write(Data("FoundationDB network stopped: \(message)\n".utf8))
            }
        }

        started = true
    }
}

private final class FoundationDBDatabaseHandle: @unchecked Sendable {
    private let database: OpaquePointer
    private let operationTimeoutSeconds: TimeInterval = 5

    init(clusterFilePath: String?) throws {
        var databasePointer: OpaquePointer?
        let createCode: fdb_error_t = if let clusterFilePath {
            clusterFilePath.withCString { pathPointer in
                fdb_create_database(pathPointer, &databasePointer)
            }
        } else {
            fdb_create_database(nil, &databasePointer)
        }

        guard createCode == 0, let databasePointer else {
            throw FoundationDBStoreError.createDatabase(code: createCode, path: clusterFilePath)
        }

        self.database = databasePointer
    }

    deinit {
        fdb_database_destroy(database)
    }

    func get(key: String) throws -> Data? {
        let transaction = try createTransaction()
        defer { fdb_transaction_destroy(transaction) }

        let future = try key.withFDBKey { keyPointer, keyLength in
            guard let future = fdb_transaction_get(transaction, keyPointer, keyLength, 0) else {
                throw FoundationDBStoreError.futureFailure(context: "get \(key)", code: -1)
            }
            return future
        }
        defer { fdb_future_destroy(future) }

        try waitForFuture(future, context: "get \(key)")

        var isPresent: fdb_bool_t = 0
        var valuePointer: UnsafePointer<UInt8>?
        var valueLength: Int32 = 0
        let code = fdb_future_get_value(future, &isPresent, &valuePointer, &valueLength)
        guard code == 0 else {
            throw FoundationDBStoreError.futureFailure(context: "read value for \(key)", code: code)
        }

        guard isPresent != 0, let valuePointer else {
            return nil
        }

        return Data(bytes: valuePointer, count: Int(valueLength))
    }

    func set(value: Data, key: String) throws {
        let transaction = try createTransaction()
        defer { fdb_transaction_destroy(transaction) }

        try key.withFDBKey { keyPointer, keyLength in
            value.withUnsafeBytes { valueBytes in
                let baseAddress = valueBytes.bindMemory(to: UInt8.self).baseAddress
                fdb_transaction_set(transaction, keyPointer, keyLength, baseAddress, Int32(value.count))
            }
        }

        try commit(transaction: transaction, context: "set \(key)")
    }

    func clear(key: String) throws {
        let transaction = try createTransaction()
        defer { fdb_transaction_destroy(transaction) }

        try key.withFDBKey { keyPointer, keyLength in
            fdb_transaction_clear(transaction, keyPointer, keyLength)
        }

        try commit(transaction: transaction, context: "clear \(key)")
    }

    func list(prefix: String) throws -> [String: Data] {
        let start = Array(prefix.utf8)
        guard let end = nextPrefix(after: start) else {
            throw FoundationDBStoreError.invalidRangePrefix(prefix)
        }

        let transaction = try createTransaction()
        defer { fdb_transaction_destroy(transaction) }

        let future = try start.withUnsafeBufferPointer { startBuffer in
            try end.withUnsafeBufferPointer { endBuffer in
                guard
                    let startPointer = startBuffer.baseAddress,
                    let endPointer = endBuffer.baseAddress,
                    let future = fdb_transaction_get_range(
                        transaction,
                        startPointer,
                        Int32(startBuffer.count),
                        0,
                        1,
                        endPointer,
                        Int32(endBuffer.count),
                        0,
                        1,
                        0,
                        0,
                        FDB_STREAMING_MODE_WANT_ALL,
                        1,
                        0,
                        0
                    )
                else {
                    throw FoundationDBStoreError.futureFailure(context: "list \(prefix)", code: -1)
                }
                return future
            }
        }
        defer { fdb_future_destroy(future) }

        try waitForFuture(future, context: "list \(prefix)")

        var kvPointer: UnsafePointer<FDBKeyValue>?
        var count: Int32 = 0
        var more: fdb_bool_t = 0
        let code = fdb_future_get_keyvalue_array(future, &kvPointer, &count, &more)
        guard code == 0 else {
            throw FoundationDBStoreError.futureFailure(context: "read range for \(prefix)", code: code)
        }

        guard let kvPointer else {
            return [:]
        }

        var output: [String: Data] = [:]
        for index in 0..<Int(count) {
            let keyValue = kvPointer[index]

            guard
                let keyBase = keyValue.key,
                let valueBase = keyValue.value,
                let key = String(bytes: UnsafeBufferPointer(start: keyBase, count: Int(keyValue.key_length)), encoding: .utf8)
            else {
                throw FoundationDBStoreError.invalidUTF8Key
            }

            output[key] = Data(bytes: valueBase, count: Int(keyValue.value_length))
        }

        _ = more
        return output
    }

    private func createTransaction() throws -> OpaquePointer {
        var transaction: OpaquePointer?
        let code = fdb_database_create_transaction(database, &transaction)
        guard code == 0, let transaction else {
            throw FoundationDBStoreError.futureFailure(context: "create transaction", code: code)
        }
        return transaction
    }

    private func commit(transaction: OpaquePointer, context: String) throws {
        guard let future = fdb_transaction_commit(transaction) else {
            throw FoundationDBStoreError.futureFailure(context: context, code: -1)
        }
        defer { fdb_future_destroy(future) }
        try waitForFuture(future, context: context)
    }

    private func waitForFuture(_ future: OpaquePointer, context: String) throws {
        let startedAt = Date()
        while fdb_future_is_ready(future) == 0 {
            if Date().timeIntervalSince(startedAt) >= operationTimeoutSeconds {
                throw FoundationDBStoreError.futureTimeout(context: context, seconds: operationTimeoutSeconds)
            }
            usleep(10_000)
        }

        let errorCode = fdb_future_get_error(future)
        guard errorCode == 0 else {
            throw FoundationDBStoreError.futureFailure(context: context, code: errorCode)
        }
    }

    private func nextPrefix(after bytes: [UInt8]) -> [UInt8]? {
        guard !bytes.isEmpty else {
            return [0xFF]
        }

        var next = bytes
        for index in stride(from: next.count - 1, through: 0, by: -1) {
            if next[index] < 0xFF {
                next[index] += 1
                return Array(next[0...index])
            }
        }
        return nil
    }
}

private extension String {
    func withFDBKey<T>(_ body: (UnsafePointer<UInt8>, Int32) throws -> T) throws -> T {
        let bytes = Array(utf8)
        return try bytes.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return try [UInt8](repeating: 0, count: 1).withUnsafeBufferPointer { emptyBuffer in
                    try body(emptyBuffer.baseAddress!, 0)
                }
            }
            return try body(baseAddress, Int32(buffer.count))
        }
    }
}
