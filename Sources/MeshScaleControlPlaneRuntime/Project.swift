import Foundation

public class MeshScaleProject {
    private var domain: String = ""
    private var resources: [String: Any] = [:]
    private var metrics: [String: ResourceMetrics] = [:]
    private var health: [String: ResourceHealth] = [:]
    private let logger: Logger?
    
    public init(logger: Logger? = nil) {
        self.logger = logger
    }
    
    // MARK: - Configuration
    
    public func setDomain(_ domain: String) {
        self.domain = domain
        logger?.log("Project domain set to: \(domain)")
    }
    
    // MARK: - Resource Management
    
    public func addResource<T: Resource>(_ type: T.Type) {
        // TODO: Instantiate resource and add to resources dict
        let resourceName = String(describing: type)
        logger?.log("Adding resource: \(resourceName)")
    }
    
    public func activateResource<T: Resource>(_ type: T.Type) {
        let resourceName = String(describing: type)
        logger?.log("Activating resource: \(resourceName)")
    }
    
    // MARK: - Metrics
    
    public func getMetrics(_ resourceName: String) -> ResourceMetrics {
        // TODO: Fetch real metrics from Convex
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
        // TODO: Send to alerting system
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
