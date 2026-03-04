import Foundation
import MeshScaleStore

public final class ControlPlane: @unchecked Sendable {
    private let logger: Logger?
    private var project: MeshScaleProject
    private var isLeader: Bool = false
    private var reconcileTask: Task<Void, Never>?
    private var leaderHeartbeatTask: Task<Void, Never>?
    private let store: any MeshScaleStoreClient
    
    /// Abstract interface where deployment plans are sent. This is intentionally
    /// generic so we can plug in Docker, Kubernetes, Nomad, etc. later.
    private let planner: DeploymentPlanner
    
    public init(
        logger: Logger? = nil,
        store: any MeshScaleStoreClient = FoundationDBStore(),
        planner: DeploymentPlanner = LoggingDeploymentPlanner()
    ) {
        self.logger = logger
        self.store = store
        self.planner = planner
        self.project = MeshScaleProject(logger: logger, store: store)
    }
    
    public func start() {
        logger?.log("Control Plane initialized")
        
        // For now, always become leader. Future: use FoundationDB for distributed election.
        isLeader = true
        
        if isLeader {
            logger?.log("This control plane is the LEADER")
            startReconciliationLoop()
            startLeaderHeartbeat()
        } else {
            logger?.log("This control plane is STANDBY")
        }
        
        logger?.log("Listening for worker connections...")
    }
    
    private func startLeaderHeartbeat() {
        leaderHeartbeatTask = Task.detached { [store, logger] in
            while !Task.isCancelled {
                let now = String(Date().timeIntervalSince1970)
                try? await store.set(Data(now.utf8), for: "control-plane/leader-heartbeat")
                logger?.log("Leader heartbeat updated")
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
    
    private func startReconciliationLoop() {
        logger?.log("Starting reconciliation loop (every 500ms)")
        reconcileTask = Task.detached { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.reconcile()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
    
    private func reconcile() {
        // Fake execution of infrastructure.swift:
        // we use the MeshScaleProject's desired specs to build a generic
        // deployment plan and persist it. Later, Docker/Kubernetes adapters
        // can consume the same plan.
        let desired = project.currentDesiredResources()
        Task {
            await planner.apply(desiredResources: desired, logger: logger, store: store)
        }
    }
    
    public func deployProject(_ projectCode: String) {
        logger?.log("Deploying project (received \(projectCode.utf8.count) bytes)...")
        
        Task {
            try? await store.set(Data(projectCode.utf8), for: "project/source")
        }
        
        logger?.log("Project deployed successfully (stored source at project/source)")
    }
    
    public func registerWorker(_ workerId: String, type: String, region: String) {
        logger?.log("Worker registered: \(workerId) (type: \(type), region: \(region))")

        Task {
            let record = "\(workerId)|\(type)|\(region)"
            try? await store.set(Data(record.utf8), for: "workers/\(workerId)")
        }
    }
    
    public func scheduleTask(_ task: ControlPlaneTask) {
        logger?.log("Task scheduled: \(task.id)")
        // TODO: Resolve worker from task, then enqueue command via FoundationDB-backed store
    }
}

public struct ControlPlaneTask {
    public let id: String
    public let payload: Data
    
    public init(id: String, payload: Data) {
        self.id = id
        self.payload = payload
    }
}

// MARK: - Deployment planning

/// High-level container-like unit the control plane wants to run.
/// This does not assume Docker vs Kubernetes; it is just "something
/// that should be running" with image/env/ports.
public struct PlannedContainer: Codable, Sendable {
    public let id: String
    public let resourceName: String
    public let replicaIndex: Int
    public let kind: ResourceKind
    public let image: String?
    public let cpu: Int
    public let memoryGB: Double
    public let ports: [Int]
    public let env: [String: String]
    public let workerTypeHint: WorkerType
    
    public init(
        id: String,
        resourceName: String,
        replicaIndex: Int,
        kind: ResourceKind,
        image: String?,
        cpu: Int,
        memoryGB: Double,
        ports: [Int],
        env: [String: String],
        workerTypeHint: WorkerType
    ) {
        self.id = id
        self.resourceName = resourceName
        self.replicaIndex = replicaIndex
        self.kind = kind
        self.image = image
        self.cpu = cpu
        self.memoryGB = memoryGB
        self.ports = ports
        self.env = env
        self.workerTypeHint = workerTypeHint
    }
}

/// A deployment plan is the desired set of containers the control plane
/// wants to be running. Backends (Docker, Kubernetes, etc.) can consume this.
public struct DeploymentPlan: Codable, Sendable {
    public let generatedAt: Date
    public let resources: [DesiredResourceSpec]
    public let containers: [PlannedContainer]
}

/// Abstract planner interface. Implementations can target Docker, Kubernetes, etc.
public protocol DeploymentPlanner: Sendable {
    func apply(
        desiredResources: [DesiredResourceSpec],
        logger: Logger?,
        store: any MeshScaleStoreClient
    ) async
}

/// Default planner used in dev: builds a plan and writes it to the store
/// at `deployments/current-plan` and logs what it would do.
public struct LoggingDeploymentPlanner: DeploymentPlanner {
    public init() {}
    
    public func apply(
        desiredResources: [DesiredResourceSpec],
        logger: Logger?,
        store: any MeshScaleStoreClient
    ) async {
        // Build a simple plan: expand replicas into separate container IDs
        var containers: [PlannedContainer] = []
        for spec in desiredResources {
            let replicas = max(spec.replicas, 1)
            for index in 0..<replicas {
                let suffix = replicas == 1 ? "" : "-\(index)"
                let id = "\(spec.name)\(suffix)"
                let workerHint: WorkerType
                switch spec.kind {
                case .database:
                    workerHint = .databaseHeavy
                case .backgroundWorker, .messageQueue, .objectStorage:
                    workerHint = .compute
                default:
                    workerHint = .general
                }
                
                containers.append(
                    PlannedContainer(
                        id: id,
                        resourceName: spec.name,
                        replicaIndex: index,
                        kind: spec.kind,
                        image: spec.image,
                        cpu: spec.cpu,
                        memoryGB: spec.memoryGB,
                        ports: spec.ports,
                        env: spec.env,
                        workerTypeHint: workerHint
                    )
                )
            }
        }
        
        let plan = DeploymentPlan(
            generatedAt: Date(),
            resources: desiredResources,
            containers: containers
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        
        if let data = try? encoder.encode(plan) {
            try? await store.set(data, for: "deployments/current-plan")
        }
        
        logger?.log("Deployment plan updated with \(containers.count) containers")
    }
}
