import Foundation

public enum WorkerType: String, Codable {
    case general
    case databaseHeavy
    case compute
}

public struct WorkerConfig {
    public let id: String
    public let type: WorkerType
    public let region: String
    public let netbirdIP: String
    
    public init(id: String, type: WorkerType = .general, region: String = "us-east-1", netbirdIP: String = "") {
        self.id = id
        self.type = type
        self.region = region
        self.netbirdIP = netbirdIP
    }
}

public struct ContainerCommand: Codable {
    public let id: String
    public let action: ContainerAction
    public let image: String?
    public let env: [String: String]?
    public let ports: [Int]?
    public let volumes: [VolumeMount]?
    
    public init(
        id: String,
        action: ContainerAction,
        image: String? = nil,
        env: [String: String]? = nil,
        ports: [Int]? = nil,
        volumes: [VolumeMount]? = nil
    ) {
        self.id = id
        self.action = action
        self.image = image
        self.env = env
        self.ports = ports
        self.volumes = volumes
    }
}

public enum ContainerAction: String, Codable {
    case start
    case stop
    case restart
    case remove
}

public struct VolumeMount: Codable {
    public let name: String
    public let mountPath: String
    
    public init(name: String, mountPath: String) {
        self.name = name
        self.mountPath = mountPath
    }
}

public struct ContainerStatus: Codable {
    public let id: String
    public let status: String
    public let cpu: Double
    public let memory: Double
    public let uptime: TimeInterval
    
    public init(id: String, status: String, cpu: Double, memory: Double, uptime: TimeInterval) {
        self.id = id
        self.status = status
        self.cpu = cpu
        self.memory = memory
        self.uptime = uptime
    }
}
