import Foundation

// MARK: - Latency Sensitivity

public enum LatencySensitivity {
    case high    // Must be co-located with dependencies
    case medium  // Prefer co-location but not required
    case low     // Can be anywhere
}

// MARK: - Worker Types

public enum WorkerType: String, Codable {
    case general        // APIs, frontends, workers
    case databaseHeavy  // Databases (high CPU/RAM/disk)
    case compute        // CPU-intensive tasks
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

public enum ResourceStatus: String, Codable {
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

public struct ResourceMetrics {
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

public struct ResourceHealth {
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
