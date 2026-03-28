import Foundation
import MeshScaleStore

public struct RuntimeOutput: Codable, Equatable, Sendable {
    public let key: String
    public let value: String
    public let updatedAt: Date

    public init(key: String, value: String, updatedAt: Date = Date()) {
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}

public class MeshScaleProject {
    private var domain: String = ""
    private var resources: [String: Any] = [:]
    private var desiredSpecs: [String: DesiredResourceSpec] = [:]
    private var metrics: [String: ResourceMetrics] = [:]
    private var health: [String: ResourceHealth] = [:]
    private var runtimeOutputs: [String: RuntimeOutput] = [:]
    private var pendingAlerts: [String] = []
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
        let didChange = self.domain != domain
        self.domain = domain
        if didChange {
            logger?.log("Project domain set to: \(domain)")
        }

        if didChange {
            let store = self.store
            let domainData = Data(domain.utf8)
            Task {
                try? await store.set(domainData, for: MeshScaleStoreKeySpace.projectDomain)
            }
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
        pendingAlerts.append(message)
        logger?.log("ALERT: \(message)")

        let store = self.store
        let messageData = Data(message.utf8)
        let alertKey = "alerts/\(UUID().uuidString)"
        Task {
            try? await store.set(messageData, for: alertKey)
        }
    }

    // MARK: - Runtime Outputs

    public func setOutput(_ key: String, to value: String) {
        runtimeOutputs[key] = RuntimeOutput(key: key, value: value)
    }

    // MARK: - Desired State Snapshot

    public func currentDesiredResources() -> [DesiredResourceSpec] {
        desiredSpecs.values.sorted { $0.name < $1.name }
    }

    public func currentDomain() -> String {
        domain
    }

    public func currentOutputs() -> [RuntimeOutput] {
        runtimeOutputs.values.sorted { $0.key < $1.key }
    }

    public func applyObservedState(
        metrics: [String: ResourceMetrics],
        health: [String: ResourceHealth]
    ) {
        self.metrics = metrics
        self.health = health
    }

    public func replaceRuntimeOutputs(_ outputs: [RuntimeOutput]) {
        let nextOutputs = Dictionary(uniqueKeysWithValues: outputs.map { ($0.key, $0) })
        guard runtimeOutputs != nextOutputs else {
            return
        }

        runtimeOutputs = nextOutputs

        let store = self.store
        Task {
            try? await store.setJSON(outputs, for: MeshScaleStoreKeySpace.runtimeOutputs)
        }
    }

    public func resetForEvaluation() {
        domain = ""
        resources.removeAll()
        desiredSpecs.removeAll()
        runtimeOutputs.removeAll()
        pendingAlerts.removeAll()
    }

    public func drainAlerts() -> [String] {
        let alerts = pendingAlerts
        pendingAlerts.removeAll()
        return alerts
    }

    public func replaceDesiredResources(_ specs: [DesiredResourceSpec], domain: String?) {
        let nextSpecs = Dictionary(uniqueKeysWithValues: specs.map { ($0.name, $0) })
        let specsChanged = desiredSpecs != nextSpecs
        let domainChanged = domain.map { $0 != self.domain } ?? false

        desiredSpecs = nextSpecs

        if let domain {
            self.domain = domain
            if domainChanged {
                logger?.log("Project domain set to: \(domain)")
            }
        }

        if specsChanged {
            logger?.log("Loaded \(specs.count) desired resources into project state")
        }

        if specsChanged || domainChanged {
            let store = self.store
            let domainData = domain.map { Data($0.utf8) }
            Task {
                try? await store.setJSON(specs, for: MeshScaleStoreKeySpace.desiredResources)
                if let domainData {
                    try? await store.set(domainData, for: MeshScaleStoreKeySpace.projectDomain)
                }
            }
        }
    }

    public func restoreFromStore() async {
        if let domainData = try? await store.get(MeshScaleStoreKeySpace.projectDomain),
           let persistedDomain = String(data: domainData, encoding: .utf8) {
            domain = persistedDomain
        }

        if let persistedSpecs = try? await store.getJSON([DesiredResourceSpec].self, for: MeshScaleStoreKeySpace.desiredResources) {
            desiredSpecs = Dictionary(uniqueKeysWithValues: persistedSpecs.map { ($0.name, $0) })
            logger?.log("Restored \(persistedSpecs.count) desired resources from store")
        }

        if let persistedOutputs = try? await store.getJSON([RuntimeOutput].self, for: MeshScaleStoreKeySpace.runtimeOutputs) {
            runtimeOutputs = Dictionary(uniqueKeysWithValues: persistedOutputs.map { ($0.key, $0) })
            logger?.log("Restored \(persistedOutputs.count) runtime outputs from store")
        }
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

            let image: String
            let env: [String: String]
            let ports: [Int]

            if anyResource is PostgresDatabase {
                image = db.image
                env = [
                    "POSTGRES_DB": name,
                    "POSTGRES_USER": "meshscale",
                    "POSTGRES_PASSWORD": "meshscale-dev-password"
                ]
                ports = [5432]
            } else if anyResource is MySQLDatabase {
                image = db.image
                env = [
                    "MYSQL_DATABASE": name,
                    "MYSQL_USER": "meshscale",
                    "MYSQL_PASSWORD": "meshscale-dev-password",
                    "MYSQL_ROOT_PASSWORD": "meshscale-root-password"
                ]
                ports = [3306]
            } else if anyResource is MongoDatabase {
                image = db.image
                env = [:]
                ports = [27017]
            } else {
                image = db.image
                env = [:]
                ports = []
            }

            return DesiredResourceSpec(
                name: name,
                kind: .database,
                cpu: db.cpu,
                memoryGB: db.memory.gb,
                storageGB: storageGB,
                replicas: db.sharding?.shards ?? 1,
                image: image.isEmpty ? nil : image,
                env: env,
                ports: ports,
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
                image: anyResource is RedisCache ? "redis:7-alpine" : nil,
                env: [:],
                ports: anyResource is RedisCache ? [6379] : [],
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

        if let dashboard = anyResource as? MeshScaleDashboard {
            return DesiredResourceSpec(
                name: name,
                kind: .meshscaleDashboard,
                cpu: dashboard.cpu,
                memoryGB: dashboard.memory.gb,
                storageGB: nil,
                replicas: dashboard.replicas,
                image: dashboard.image,
                env: dashboard.env,
                ports: [dashboard.port],
                latencySensitivity: dashboard.latencySensitivity
            )
        }

        if let dashboard = anyResource as? NetBirdDashboard {
            return DesiredResourceSpec(
                name: name,
                kind: .netbirdDashboard,
                cpu: dashboard.cpu,
                memoryGB: dashboard.memory.gb,
                storageGB: nil,
                replicas: dashboard.replicas,
                image: dashboard.image,
                env: [
                    "MESHCALE_NETBIRD_PUBLIC_HOST": dashboard.publicHost ?? "",
                    "MESHCALE_NETBIRD_DASHBOARD_HOST_PORT": String(dashboard.dashboardHostPort),
                    "MESHCALE_NETBIRD_MANAGEMENT_HOST_PORT": String(dashboard.managementHostPort),
                ],
                ports: [dashboard.dashboardHostPort],
                latencySensitivity: dashboard.latencySensitivity
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
            let image: String?
            let ports: [Int]
            switch mq.type {
            case .rabbitmq:
                image = "rabbitmq:3-management"
                ports = [5672, 15672]
            case .kafka:
                image = "bitnami/kafka:latest"
                ports = [9092]
            case .sqs:
                image = "softwaremill/elasticmq-native"
                ports = [9324]
            }

            return DesiredResourceSpec(
                name: name,
                kind: .messageQueue,
                cpu: mq.cpu,
                memoryGB: mq.memory.gb,
                storageGB: nil,
                replicas: mq.replicas,
                image: image,
                env: [:],
                ports: ports,
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
