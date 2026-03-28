import Foundation

public enum WorkerType: String, Codable, Sendable {
    case general
    case databaseHeavy
    case compute
    case controlPlane
}

public enum ContainerAction: String, Codable, Sendable {
    case start
    case stop
    case restart
    case remove
}

public struct VolumeMount: Codable, Equatable, Sendable {
    public let name: String
    public let mountPath: String

    public init(name: String, mountPath: String) {
        self.name = name
        self.mountPath = mountPath
    }
}

public enum PortTransport: String, Codable, Equatable, Sendable {
    case tcp
    case udp
}

public struct PortBinding: Codable, Equatable, Sendable {
    public let hostPort: Int
    public let containerPort: Int
    public let transport: PortTransport

    public init(hostPort: Int, containerPort: Int, transport: PortTransport = .tcp) {
        self.hostPort = hostPort
        self.containerPort = containerPort
        self.transport = transport
    }
}

public struct ManagedFile: Codable, Equatable, Sendable {
    public enum Encoding: String, Codable, Equatable, Sendable {
        case utf8
        case base64
    }

    public let relativePath: String
    public let mountPath: String
    public let content: String
    public let encoding: Encoding

    public init(
        relativePath: String,
        mountPath: String,
        content: String,
        encoding: Encoding = .utf8
    ) {
        self.relativePath = relativePath
        self.mountPath = mountPath
        self.content = content
        self.encoding = encoding
    }
}

public struct ContainerCommand: Codable, Equatable, Sendable {
    public let id: String
    public let action: ContainerAction
    public let image: String?
    public let env: [String: String]?
    public let ports: [PortBinding]?
    public let volumes: [VolumeMount]?
    public let files: [ManagedFile]?
    public let managedFileBundleID: String?
    public let args: [String]?

    public init(
        id: String,
        action: ContainerAction,
        image: String? = nil,
        env: [String: String]? = nil,
        ports: [PortBinding]? = nil,
        volumes: [VolumeMount]? = nil,
        files: [ManagedFile]? = nil,
        managedFileBundleID: String? = nil,
        args: [String]? = nil
    ) {
        self.id = id
        self.action = action
        self.image = image
        self.env = env
        self.ports = ports
        self.volumes = volumes
        self.files = files
        self.managedFileBundleID = managedFileBundleID
        self.args = args
    }
}

public struct ContainerStatus: Codable, Equatable, Sendable {
    public let id: String
    public let status: String
    public let cpu: Double
    public let memory: Double
    public let uptime: TimeInterval
    public let image: String?
    public let lastError: String?
    public let lastUpdatedAt: Date?
    public let retryCount: Int

    public init(
        id: String,
        status: String,
        cpu: Double,
        memory: Double,
        uptime: TimeInterval,
        image: String? = nil,
        lastError: String? = nil,
        lastUpdatedAt: Date? = nil,
        retryCount: Int = 0
    ) {
        self.id = id
        self.status = status
        self.cpu = cpu
        self.memory = memory
        self.uptime = uptime
        self.image = image
        self.lastError = lastError
        self.lastUpdatedAt = lastUpdatedAt
        self.retryCount = retryCount
    }
}

public struct WorkerRecord: Codable, Sendable {
    public let id: String
    public let type: WorkerType
    public let region: String
    public let netbirdIP: String
    public let attachedControlPlaneID: String?
    public let lastSeenAt: Date
    public let status: String

    public init(
        id: String,
        type: WorkerType,
        region: String,
        netbirdIP: String,
        attachedControlPlaneID: String? = nil,
        lastSeenAt: Date,
        status: String
    ) {
        self.id = id
        self.type = type
        self.region = region
        self.netbirdIP = netbirdIP
        self.attachedControlPlaneID = attachedControlPlaneID
        self.lastSeenAt = lastSeenAt
        self.status = status
    }
}

public struct ControlPlaneRecord: Codable, Sendable {
    public let id: String
    public let region: String
    public let apiURL: String
    public let netbirdIP: String
    public let lastSeenAt: Date
    public let status: String

    public init(
        id: String,
        region: String,
        apiURL: String,
        netbirdIP: String,
        lastSeenAt: Date,
        status: String
    ) {
        self.id = id
        self.region = region
        self.apiURL = apiURL
        self.netbirdIP = netbirdIP
        self.lastSeenAt = lastSeenAt
        self.status = status
    }
}

public struct ControlPlaneLeaderRecord: Codable, Sendable {
    public let controlPlaneId: String
    public let electedAt: Date
    public let lastHeartbeatAt: Date

    public init(controlPlaneId: String, electedAt: Date, lastHeartbeatAt: Date) {
        self.controlPlaneId = controlPlaneId
        self.electedAt = electedAt
        self.lastHeartbeatAt = lastHeartbeatAt
    }
}

public struct WorkerHealthReport: Codable, Sendable {
    public let workerId: String
    public let runningContainers: Int
    public let totalContainers: Int
    public let reportedAt: Date

    public init(workerId: String, runningContainers: Int, totalContainers: Int, reportedAt: Date) {
        self.workerId = workerId
        self.runningContainers = runningContainers
        self.totalContainers = totalContainers
        self.reportedAt = reportedAt
    }
}

public struct WorkerAssignmentRecord: Codable, Equatable, Sendable {
    public let workerId: String
    public let containerId: String
    public let image: String?
    public let assignedByControlPlaneID: String?
    public let assignedAt: Date

    public init(
        workerId: String,
        containerId: String,
        image: String?,
        assignedByControlPlaneID: String? = nil,
        assignedAt: Date
    ) {
        self.workerId = workerId
        self.containerId = containerId
        self.image = image
        self.assignedByControlPlaneID = assignedByControlPlaneID
        self.assignedAt = assignedAt
    }
}

public struct DeploymentMetadata: Codable, Sendable {
    public let projectId: String
    public let revision: Int
    public let lastDeployedAt: Date
    public let deployedByControlPlaneID: String?
    public let deploymentKind: DeploymentKind

    public init(
        projectId: String = MeshScaleStoreKeySpace.defaultProjectID,
        revision: Int = 1,
        lastDeployedAt: Date,
        deployedByControlPlaneID: String? = nil,
        deploymentKind: DeploymentKind = .swiftSource
    ) {
        self.projectId = projectId
        self.revision = revision
        self.lastDeployedAt = lastDeployedAt
        self.deployedByControlPlaneID = deployedByControlPlaneID
        self.deploymentKind = deploymentKind
    }

    private enum CodingKeys: String, CodingKey {
        case projectId
        case revision
        case lastDeployedAt
        case deployedByControlPlaneID
        case deploymentKind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projectId = try container.decodeIfPresent(String.self, forKey: .projectId)
            ?? MeshScaleStoreKeySpace.defaultProjectID
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 1
        lastDeployedAt = try container.decode(Date.self, forKey: .lastDeployedAt)
        deployedByControlPlaneID = try container.decodeIfPresent(String.self, forKey: .deployedByControlPlaneID)
        deploymentKind = try container.decodeIfPresent(DeploymentKind.self, forKey: .deploymentKind) ?? .swiftSource
    }
}

public enum DeploymentKind: String, Codable, Sendable {
    case swiftSource
    case manifest
}

public struct SharedProjectRecord: Codable, Equatable, Sendable {
    public let id: String
    public let domain: String?
    public let revision: Int
    public let primaryRegion: String?
    public let shardIds: [String]
    public let lastDeployedAt: Date?
    public let lastUpdatedAt: Date

    public init(
        id: String = MeshScaleStoreKeySpace.defaultProjectID,
        domain: String?,
        revision: Int,
        primaryRegion: String?,
        shardIds: [String],
        lastDeployedAt: Date?,
        lastUpdatedAt: Date = Date()
    ) {
        self.id = id
        self.domain = domain
        self.revision = revision
        self.primaryRegion = primaryRegion
        self.shardIds = shardIds.sorted()
        self.lastDeployedAt = lastDeployedAt
        self.lastUpdatedAt = lastUpdatedAt
    }
}

public struct ProjectShardRecord: Codable, Equatable, Sendable {
    public let projectId: String
    public let shardId: String
    public let region: String
    public let controlPlaneIds: [String]
    public let workerIds: [String]
    public let desiredResourceNames: [String]
    public let containerIds: [String]
    public let lastUpdatedAt: Date

    public init(
        projectId: String = MeshScaleStoreKeySpace.defaultProjectID,
        shardId: String,
        region: String,
        controlPlaneIds: [String],
        workerIds: [String],
        desiredResourceNames: [String],
        containerIds: [String],
        lastUpdatedAt: Date = Date()
    ) {
        self.projectId = projectId
        self.shardId = shardId
        self.region = region
        self.controlPlaneIds = controlPlaneIds.sorted()
        self.workerIds = workerIds.sorted()
        self.desiredResourceNames = desiredResourceNames.sorted()
        self.containerIds = containerIds.sorted()
        self.lastUpdatedAt = lastUpdatedAt
    }
}

public enum MeshScaleStoreKeySpace {
    public static let defaultProjectID = "swift-project"
    public static let projectDomain = "project/domain"
    public static let projectSource = "project/source"
    public static let desiredResources = "project/desired-resources"
    public static let runtimeOutputs = "project/runtime-outputs"
    public static let currentPlan = "deployments/current-plan"
    public static let currentAssignments = "deployments/current-assignments"
    public static let deploymentMetadata = "deployments/metadata"
    public static let leaderHeartbeat = "control-plane/leader-heartbeat"
    public static let currentLeader = "control-plane/current-leader"

    public static func workerRecord(_ workerId: String) -> String {
        "workers/\(workerId)/record"
    }

    public static func workerHealth(_ workerId: String) -> String {
        "workers/\(workerId)/health"
    }

    public static func workerContainer(_ workerId: String, containerId: String) -> String {
        "workers/\(workerId)/containers/\(containerId)"
    }

    public static func workerDesiredContainer(_ workerId: String, containerId: String) -> String {
        "workers/\(workerId)/desired-containers/\(containerId)"
    }

    public static func workerDesiredPrefix(_ workerId: String) -> String {
        "workers/\(workerId)/desired-containers/"
    }

    public static func workerContainersPrefix(_ workerId: String) -> String {
        "workers/\(workerId)/containers/"
    }

    public static func controlPlaneRecord(_ controlPlaneId: String) -> String {
        "control-planes/\(controlPlaneId)/record"
    }

    public static func sharedProjectRecord(_ projectId: String) -> String {
        "projects/catalog/\(projectId)"
    }

    public static func projectShard(_ projectId: String, shardId: String) -> String {
        "projects/\(projectId)/shards/\(shardId)"
    }

    public static func projectShardsPrefix(_ projectId: String) -> String {
        "projects/\(projectId)/shards/"
    }

    public static let controlPlanesPrefix = "control-planes/"
    public static let workersPrefix = "workers/"
    public static let sharedProjectsPrefix = "projects/catalog/"
}

public struct MeshScaleStateStore: Sendable {
    private let client: any MeshScaleStoreClient

    public init(client: any MeshScaleStoreClient) {
        self.client = client
    }

    public func putJSON<T: Encodable>(_ value: T, for key: String) async throws {
        try await client.set(encode(value), for: key)
    }

    public func getJSON<T: Decodable>(_ type: T.Type, for key: String) async throws -> T? {
        guard let data = try await client.get(key) else {
            return nil
        }
        return try decode(type, from: data)
    }

    public func listJSON<T: Decodable>(_ type: T.Type, prefix: String) async throws -> [String: T] {
        let entries = try await client.list(prefix: prefix)
        var decoded: [String: T] = [:]

        for (key, value) in entries.sorted(by: { $0.key < $1.key }) {
            decoded[key] = try decode(type, from: value)
        }

        return decoded
    }

    public func listWorkers() async throws -> [WorkerRecord] {
        let entries = try await client.list(prefix: MeshScaleStoreKeySpace.workersPrefix)
        return try entries
            .filter { $0.key.hasSuffix("/record") }
            .sorted { $0.key < $1.key }
            .map { try decode(WorkerRecord.self, from: $0.value) }
            .sorted { $0.id < $1.id }
    }

    public func listControlPlanes() async throws -> [ControlPlaneRecord] {
        let entries = try await client.list(prefix: MeshScaleStoreKeySpace.controlPlanesPrefix)
        return try entries
            .filter { $0.key.hasSuffix("/record") }
            .sorted { $0.key < $1.key }
            .map { try decode(ControlPlaneRecord.self, from: $0.value) }
            .sorted { $0.id < $1.id }
    }

    public func getControlPlaneRecord(controlPlaneId: String) async throws -> ControlPlaneRecord? {
        try await getJSON(ControlPlaneRecord.self, for: MeshScaleStoreKeySpace.controlPlaneRecord(controlPlaneId))
    }

    public func putWorkerRecord(_ worker: WorkerRecord) async throws {
        try await putJSON(worker, for: MeshScaleStoreKeySpace.workerRecord(worker.id))
    }

    public func putControlPlaneRecord(_ controlPlane: ControlPlaneRecord) async throws {
        try await putJSON(controlPlane, for: MeshScaleStoreKeySpace.controlPlaneRecord(controlPlane.id))
    }

    public func putWorkerHealth(_ health: WorkerHealthReport) async throws {
        try await putJSON(health, for: MeshScaleStoreKeySpace.workerHealth(health.workerId))
    }

    public func putContainerStatus(_ status: ContainerStatus, workerId: String) async throws {
        try await putJSON(status, for: MeshScaleStoreKeySpace.workerContainer(workerId, containerId: status.id))
    }

    public func listDesiredCommands(workerId: String) async throws -> [String: ContainerCommand] {
        try await listJSON(ContainerCommand.self, prefix: MeshScaleStoreKeySpace.workerDesiredPrefix(workerId))
    }

    public func putDesiredCommand(_ command: ContainerCommand, workerId: String) async throws {
        try await putJSON(command, for: MeshScaleStoreKeySpace.workerDesiredContainer(workerId, containerId: command.id))
    }

    public func deleteDesiredCommand(workerId: String, containerId: String) async throws {
        try await client.delete(MeshScaleStoreKeySpace.workerDesiredContainer(workerId, containerId: containerId))
    }

    public func putAssignments(_ assignments: [WorkerAssignmentRecord]) async throws {
        try await putJSON(assignments, for: MeshScaleStoreKeySpace.currentAssignments)
    }

    public func putDeploymentMetadata(_ metadata: DeploymentMetadata) async throws {
        try await putJSON(metadata, for: MeshScaleStoreKeySpace.deploymentMetadata)
    }

    public func getDeploymentMetadata() async throws -> DeploymentMetadata? {
        try await getJSON(DeploymentMetadata.self, for: MeshScaleStoreKeySpace.deploymentMetadata)
    }

    public func listSharedProjects() async throws -> [SharedProjectRecord] {
        let entries = try await client.list(prefix: MeshScaleStoreKeySpace.sharedProjectsPrefix)
        return try entries
            .sorted { $0.key < $1.key }
            .map { try decode(SharedProjectRecord.self, from: $0.value) }
            .sorted { $0.id < $1.id }
    }

    public func putSharedProjectRecord(_ project: SharedProjectRecord) async throws {
        try await putJSON(project, for: MeshScaleStoreKeySpace.sharedProjectRecord(project.id))
    }

    public func getSharedProjectRecord(projectId: String) async throws -> SharedProjectRecord? {
        try await getJSON(SharedProjectRecord.self, for: MeshScaleStoreKeySpace.sharedProjectRecord(projectId))
    }

    public func listProjectShards(projectId: String) async throws -> [ProjectShardRecord] {
        let entries = try await client.list(prefix: MeshScaleStoreKeySpace.projectShardsPrefix(projectId))
        return try entries
            .sorted { $0.key < $1.key }
            .map { try decode(ProjectShardRecord.self, from: $0.value) }
            .sorted { $0.shardId < $1.shardId }
    }

    public func putProjectShard(_ shard: ProjectShardRecord) async throws {
        try await putJSON(
            shard,
            for: MeshScaleStoreKeySpace.projectShard(shard.projectId, shardId: shard.shardId)
        )
    }

    public func deleteProjectShard(projectId: String, shardId: String) async throws {
        try await client.delete(MeshScaleStoreKeySpace.projectShard(projectId, shardId: shardId))
    }

    public func putLeaderRecord(_ leader: ControlPlaneLeaderRecord) async throws {
        try await putJSON(leader, for: MeshScaleStoreKeySpace.currentLeader)
    }

    public func getLeaderRecord() async throws -> ControlPlaneLeaderRecord? {
        try await getJSON(ControlPlaneLeaderRecord.self, for: MeshScaleStoreKeySpace.currentLeader)
    }

    public func listWorkerHealthReports() async throws -> [String: WorkerHealthReport] {
        let entries = try await client.list(prefix: MeshScaleStoreKeySpace.workersPrefix)
        var reports: [String: WorkerHealthReport] = [:]

        for (key, value) in entries where key.hasSuffix("/health") {
            reports[key] = try decode(WorkerHealthReport.self, from: value)
        }

        return reports
    }

    public func listContainerStatuses(workerId: String) async throws -> [String: ContainerStatus] {
        try await listJSON(ContainerStatus.self, prefix: MeshScaleStoreKeySpace.workerContainersPrefix(workerId))
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}

public extension MeshScaleStoreClient {
    func setJSON<T: Encodable>(_ value: T, for key: String) async throws {
        try await MeshScaleStateStore(client: self).putJSON(value, for: key)
    }

    func getJSON<T: Decodable>(_ type: T.Type, for key: String) async throws -> T? {
        try await MeshScaleStateStore(client: self).getJSON(type, for: key)
    }
}
