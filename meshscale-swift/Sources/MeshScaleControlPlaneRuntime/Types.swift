import Foundation
import MeshScaleStore

// MARK: - Latency Sensitivity

public enum LatencySensitivity: String, Codable, Sendable {
    case high    // Must be co-located with dependencies
    case medium  // Prefer co-location but not required
    case low     // Can be anywhere
}

// MARK: - Environment

public enum Environment {
    case development
    case staging
    case production
    
    public static var current: Environment {
        // TODO: Get from environment variable
        return .development
    }
}

// MARK: - Resource Status

public enum ResourceStatus: String, Codable, Sendable {
    case pending
    case provisioning
    case running
    case unhealthy
    case stopped
    case failed
}

// MARK: - Storage

public enum StorageType {
    case ssd(Size)
    case hdd(Size)
}

public struct Size {
    public let bytes: UInt64
    
    public init(bytes: UInt64) {
        self.bytes = bytes
    }
    
    public var gb: Double {
        Double(bytes) / 1_000_000_000
    }
}

extension Int {
    public var gb: Size {
        Size(bytes: UInt64(self) * 1_000_000_000)
    }
}

extension Double {
    public var gb: Size {
        Size(bytes: UInt64(self * 1_000_000_000))
    }
}

// MARK: - Volume Configuration

public struct VolumeConfig {
    public let name: String
    public let size: Size
    public let type: VolumeType
    public let backend: VolumeBackend
    public let mountPath: String
    public let reclaimPolicy: ReclaimPolicy
    
    public init(
        name: String,
        size: Size,
        type: VolumeType,
        backend: VolumeBackend,
        mountPath: String,
        reclaimPolicy: ReclaimPolicy = .retain
    ) {
        self.name = name
        self.size = size
        self.type = type
        self.backend = backend
        self.mountPath = mountPath
        self.reclaimPolicy = reclaimPolicy
    }
}

public enum VolumeType {
    case ssd
    case hdd
}

public enum VolumeBackend {
    case awsEBS
    case longhorn
    case ceph
    case nfs
}

public enum ReclaimPolicy {
    case retain
    case delete
}

// MARK: - Desired State & Scheduling

/// High-level kind of resource. This is derived from which
/// resource protocol a type conforms to (database, HTTPService, etc.).
public enum ResourceKind: String, Codable, Equatable, Sendable {
    case database
    case cache
    case httpService
    case webService
    case meshscaleDashboard
    case netbirdDashboard
    case backgroundWorker
    case staticSite
    case objectStorage
    case messageQueue
}

/// Desired resource description extracted from user `Resource` structs.
/// This is the control plane's generic model, independent of Docker/Kubernetes.
public struct DesiredResourceSpec: Codable, Equatable, Sendable {
    public let name: String
    public let kind: ResourceKind
    public let cpu: Int
    public let memoryGB: Double
    public let storageGB: Double?
    public let replicas: Int
    public let image: String?
    public let env: [String: String]
    public let ports: [Int]
    public let latencySensitivity: LatencySensitivity
    
    public init(
        name: String,
        kind: ResourceKind,
        cpu: Int,
        memoryGB: Double,
        storageGB: Double?,
        replicas: Int,
        image: String?,
        env: [String: String],
        ports: [Int],
        latencySensitivity: LatencySensitivity
    ) {
        self.name = name
        self.kind = kind
        self.cpu = cpu
        self.memoryGB = memoryGB
        self.storageGB = storageGB
        self.replicas = replicas
        self.image = image
        self.env = env
        self.ports = ports
        self.latencySensitivity = latencySensitivity
    }
}

// MARK: - Sharding Configuration

public struct ShardingConfig {
    public let shards: Int
    public let replicationFactor: Int
    public let strategy: ShardingStrategy
    public let autoRebalance: Bool
    
    public init(
        shards: Int,
        replicationFactor: Int,
        strategy: ShardingStrategy,
        autoRebalance: Bool = true
    ) {
        self.shards = shards
        self.replicationFactor = replicationFactor
        self.strategy = strategy
        self.autoRebalance = autoRebalance
    }
}

public enum ShardingStrategy {
    case consistentHash(key: String)
    case range(key: String)
    case modulo(key: String)
}

// MARK: - Metrics

public struct ResourceMetrics: Codable, Sendable {
    public let cpu: Double  // 0.0 to 1.0
    public let memory: Double  // 0.0 to 1.0
    public let requestsPerSecond: Double
    public let qps: Double  // Queries per second
    public let avgResponseTime: TimeInterval
    public let errorRate: Double
    public let currentReplicas: Int
    
    public init(
        cpu: Double = 0,
        memory: Double = 0,
        requestsPerSecond: Double = 0,
        qps: Double = 0,
        avgResponseTime: TimeInterval = 0,
        errorRate: Double = 0,
        currentReplicas: Int = 0
    ) {
        self.cpu = cpu
        self.memory = memory
        self.requestsPerSecond = requestsPerSecond
        self.qps = qps
        self.avgResponseTime = avgResponseTime
        self.errorRate = errorRate
        self.currentReplicas = currentReplicas
    }
}

public struct ResourceHealth: Codable, Sendable {
    public let status: ResourceStatus
    public let avgResponseTime: TimeInterval
    public let currentReplicas: Int
    
    public init(status: ResourceStatus, avgResponseTime: TimeInterval = 0, currentReplicas: Int = 0) {
        self.status = status
        self.avgResponseTime = avgResponseTime
        self.currentReplicas = currentReplicas
    }
}

extension TimeInterval {
    public var ms: TimeInterval {
        self / 1000
    }
}

extension Int {
    public var ms: TimeInterval {
        Double(self) / 1000
    }
}
