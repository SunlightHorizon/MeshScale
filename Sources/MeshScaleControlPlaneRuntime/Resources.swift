import Foundation

// MARK: - Resource & Dependency
// Note: @Resource and @Dependency in user infrastructure.swift are semantic markers.
// Resources conform to protocol types (PostgresDatabase, HTTPService, etc.).
// Dependencies are declared via @Dependency var x: ResourceType for scheduler co-location.

// MARK: - Resource Protocol

public protocol Resource {
    var name: String { get }
    var latencySensitivity: LatencySensitivity { get }
}

// MARK: - Database Resources

public protocol DatabaseResource: Resource {
    var cpu: Int { get }
    var memory: Size { get }
    var storage: StorageType { get }
    var volume: VolumeConfig? { get }
    var sharding: ShardingConfig? { get }
}

public protocol PostgresDatabase: DatabaseResource {}
public protocol MySQLDatabase: DatabaseResource {}
public protocol MongoDatabase: DatabaseResource {}

// MARK: - Cache Resources

public protocol CacheResource: Resource {
    var memory: Size { get }
    var cpu: Int { get }
}

public protocol RedisCache: CacheResource {}

// MARK: - Service Resources

public protocol ServiceResource: Resource {
    var replicas: Int { get }
    var image: String { get }
    var cpu: Int { get }
    var memory: Size { get }
    var env: [String: String] { get }
}

public protocol HTTPService: ServiceResource {
    var port: Int { get }
}

public protocol BackgroundWorker: ServiceResource {}

public protocol WebService: ServiceResource {
    var port: Int { get }
}

public protocol StaticSite: ServiceResource {
    var port: Int { get }
}

// MARK: - Storage Resources

public protocol ObjectStorage: Resource {
    var name: String { get }
    var capacity: Size { get }
    var latencySensitivity: LatencySensitivity { get }
}

extension ObjectStorage {
    public var latencySensitivity: LatencySensitivity { .medium }
}

// MARK: - Message Queue

public protocol MessageQueue: Resource {
    var type: QueueType { get }
    var replicas: Int { get }
    var cpu: Int { get }
    var memory: Size { get }
}

public enum QueueType {
    case rabbitmq
    case kafka
    case sqs
}

// MARK: - Default Implementations

extension DatabaseResource {
    public var latencySensitivity: LatencySensitivity { .high }
    public var volume: VolumeConfig? { nil }
    public var sharding: ShardingConfig? { nil }
}

extension CacheResource {
    public var latencySensitivity: LatencySensitivity { .high }
}

extension ServiceResource {
    public var env: [String: String] { [:] }
}

extension HTTPService {
    public var port: Int { 8080 }
}

extension WebService {
    public var port: Int { 3000 }
}

extension StaticSite {
    public var port: Int { 80 }
}
