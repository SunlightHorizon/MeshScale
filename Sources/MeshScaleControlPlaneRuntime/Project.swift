import Foundation
import MeshScaleStore

public class MeshScaleProject {
    private var domain: String = ""
    private var resources: [String: Any] = [:]
    private var desiredSpecs: [String: DesiredResourceSpec] = [:]
    private var metrics: [String: ResourceMetrics] = [:]
    private var health: [String: ResourceHealth] = [:]
    private let logger: Logger?
    private let store: any MeshScaleStoreClient
    
    public init(
        logger: Logger? = nil,
        store: any MeshScaleStoreClient = FoundationDBStore()
    ) {
        self.logger = logger
        self.store = store
    }
    
    // MARK: - Configuration
    
    public func setDomain(_ domain: String) {
        self.domain = domain
        logger?.log("Project domain set to: \(domain)")

        Task {
            try? await store.set(Data(domain.utf8), for: "project/domain")
        }
    }
    
    // MARK: - Resource Management
    
    /// Register a resource definition from user infrastructure.swift.
    /// This converts protocol-based config into a generic DesiredResourceSpec.
    public func addResource<T: Resource>(_ type: T.Type) {
        let instance = T.init()
        let resourceName = instance.name
        let spec = makeDesiredSpec(from: instance)
        desiredSpecs[resourceName] = spec
        resources[resourceName] = instance
        logger?.log("Adding resource: \(resourceName) [\(spec.kind)]")
    }
    
    public func activateResource<T: Resource>(_ type: T.Type) {
        let resourceName = String(describing: type)
        logger?.log("Activating resource: \(resourceName)")
    }
    
    // MARK: - Metrics
    
    public func getMetrics(_ resourceName: String) -> ResourceMetrics {
        // TODO: Fetch real metrics from FoundationDB
        return metrics[resourceName] ?? ResourceMetrics()
    }
    
    public func getMetric(_ metricName: String) -> Double {
        // TODO: Fetch specific metric
        return 0
    }
    
    public func getResourceHealth<T: Resource>(_ type: T.Type) -> ResourceHealth {
        let resourceName = String(describing: type)
        return health[resourceName] ?? ResourceHealth(status: .running)
    }
    
    // MARK: - Networking
    
    public func addNetworkingPolicy(_ policy: NetworkingPolicy) {
        logger?.log("Adding networking policy")
    }
    
    // MARK: - Alerts
    
    public func sendAlert(_ message: String) {
        logger?.log("ALERT: \(message)")

        Task {
            try? await store.set(Data(message.utf8), for: "alerts/\(UUID().uuidString)")
        }
    }
    
    // MARK: - Desired State Snapshot
    
    public func currentDesiredResources() -> [DesiredResourceSpec] {
        Array(desiredSpecs.values)
    }
    
    // MARK: - Internal helpers
    
    private func makeDesiredSpec(from anyResource: Resource) -> DesiredResourceSpec {
        let name = anyResource.name
        let latency = anyResource.latencySensitivity
        
        // Databases
        if let db = anyResource as? DatabaseResource {
            let storageGB: Double?
            switch db.storage {
            case .ssd(let size), .hdd(let size):
                storageGB = size.gb
            }
            return DesiredResourceSpec(
                name: name,
                kind: .database,
                cpu: db.cpu,
                memoryGB: db.memory.gb,
                storageGB: storageGB,
                replicas: db.sharding?.shards ?? 1,
                image: nil,
                env: [:],
                ports: [],
                latencySensitivity: latency
            )
        }
        
        // Caches
        if let cache = anyResource as? CacheResource {
            return DesiredResourceSpec(
                name: name,
                kind: .cache,
                cpu: cache.cpu,
                memoryGB: cache.memory.gb,
                storageGB: nil,
                replicas: 1,
                image: nil,
                env: [:],
                ports: [],
                latencySensitivity: latency
            )
        }
        
        // Services (HTTP / Web / Static / Background)
        if let http = anyResource as? HTTPService {
            return DesiredResourceSpec(
                name: name,
                kind: .httpService,
                cpu: http.cpu,
                memoryGB: http.memory.gb,
                storageGB: nil,
                replicas: http.replicas,
                image: http.image,
                env: http.env,
                ports: [http.port],
                latencySensitivity: latency
            )
        }
        
        if let web = anyResource as? WebService {
            return DesiredResourceSpec(
                name: name,
                kind: .webService,
                cpu: web.cpu,
                memoryGB: web.memory.gb,
                storageGB: nil,
                replicas: web.replicas,
                image: web.image,
                env: web.env,
                ports: [web.port],
                latencySensitivity: latency
            )
        }
        
        if let site = anyResource as? StaticSite {
            return DesiredResourceSpec(
                name: name,
                kind: .staticSite,
                cpu: site.cpu,
                memoryGB: site.memory.gb,
                storageGB: nil,
                replicas: site.replicas,
                image: site.image,
                env: site.env,
                ports: [site.port],
                latencySensitivity: latency
            )
        }
        
        if let worker = anyResource as? BackgroundWorker {
            return DesiredResourceSpec(
                name: name,
                kind: .backgroundWorker,
                cpu: worker.cpu,
                memoryGB: worker.memory.gb,
                storageGB: nil,
                replicas: worker.replicas,
                image: worker.image,
                env: worker.env,
                ports: [],
                latencySensitivity: latency
            )
        }
        
        // Object storage
        if let object = anyResource as? ObjectStorage {
            return DesiredResourceSpec(
                name: name,
                kind: .objectStorage,
                cpu: 0,
                memoryGB: 0,
                storageGB: object.capacity.gb,
                replicas: 1,
                image: nil,
                env: [:],
                ports: [],
                latencySensitivity: object.latencySensitivity
            )
        }
        
        // Message queue
        if let mq = anyResource as? MessageQueue {
            return DesiredResourceSpec(
                name: name,
                kind: .messageQueue,
                cpu: mq.cpu,
                memoryGB: mq.memory.gb,
                storageGB: nil,
                replicas: mq.replicas,
                image: nil,
                env: [:],
                ports: [],
                latencySensitivity: latency
            )
        }
        
        // Fallback generic
        return DesiredResourceSpec(
            name: name,
            kind: .backgroundWorker,
            cpu: 0,
            memoryGB: 0,
            storageGB: nil,
            replicas: 1,
            image: nil,
            env: [:],
            ports: [],
            latencySensitivity: latency
        )
    }
}

// MARK: - Networking Policy

public struct NetworkingPolicy {
    public let inbound: PortFiltering
    public let outbound: PortFiltering
    public let url: ResourcePath
    
    public init(inbound: PortFiltering, outbound: PortFiltering, url: ResourcePath) {
        self.inbound = inbound
        self.outbound = outbound
        self.url = url
    }
}

public struct PortFiltering {
    public enum Kind {
        case specific([Int])
        case all
    }
    
    public let kind: Kind
    public var ports: [Int] {
        if case .specific(let p) = kind { return p }
        return []
    }
    
    public init(_ ports: Int...) {
        self.kind = ports.isEmpty ? .all : .specific(Array(ports))
    }
    
    public init(_ kind: Kind) {
        self.kind = kind
    }
    
    public static var all: PortFiltering {
        PortFiltering(.all)
    }
}

public struct ResourcePath {
    public let path: String
    
    public init(_ path: String) {
        self.path = path
    }
}
