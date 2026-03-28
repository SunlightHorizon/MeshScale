import Foundation
import MeshScaleStore

public final class ControlPlane: @unchecked Sendable {
    private let logger: Logger?
    private var project: MeshScaleProject
    private let controlPlaneID: String
    private let controlPlaneRegion: String
    private let apiURL: String
    private let netbirdIP: String
    private var isLeader: Bool = false
    private var reconcileTask: Task<Void, Never>?
    private var leaderHeartbeatTask: Task<Void, Never>?
    private var controlPlaneHeartbeatTask: Task<Void, Never>?
    private var leadershipTask: Task<Void, Never>?
    private var deploymentSyncTask: Task<Void, Never>?
    private let reconcileLock = NSLock()
    private var isReconciling = false
    private let deploymentSyncLock = NSLock()
    private var isSyncingDeploymentState = false
    private var appliedDeploymentRevision: Int = 0
    private let store: any MeshScaleStoreClient
    private let stateStore: MeshScaleStateStore
    private let runtimeHost: SwiftProjectRuntimeHost
    private let dashboardBundle: MeshScaleDashboardBundle?
    
    /// Abstract interface where deployment plans are sent. This is intentionally
    /// generic so we can plug in Docker, Kubernetes, Nomad, etc. later.
    private let planner: DeploymentPlanner
    
    public init(
        id: String = "control-plane",
        region: String = "control-plane",
        apiURL: String = "http://127.0.0.1:8080",
        netbirdIP: String = "",
        logger: Logger? = nil,
        store: any MeshScaleStoreClient = MeshScaleStoreFactory.makeStore(),
        planner: DeploymentPlanner = LoggingDeploymentPlanner()
    ) {
        self.controlPlaneID = id
        self.controlPlaneRegion = region
        self.apiURL = apiURL
        self.netbirdIP = netbirdIP
        self.logger = logger
        self.store = store
        self.stateStore = MeshScaleStateStore(client: store)
        self.planner = planner
        self.project = MeshScaleProject(logger: logger, store: store)
        self.runtimeHost = SwiftProjectRuntimeHost(logger: logger)
        self.dashboardBundle = MeshScaleDashboardBundle.load(logger: logger)
    }
    
    public func start() async {
        logger?.log("Control Plane initialized")
        await restorePersistedProjectState()

        startControlPlaneHeartbeat()
        startDeploymentSyncLoop()
        startLeadershipLoop()
        logger?.log("Listening for worker connections...")
    }

    public func stop() {
        controlPlaneHeartbeatTask?.cancel()
        leadershipTask?.cancel()
        deploymentSyncTask?.cancel()
        stopLeaderHeartbeat()
        stopReconciliationLoop()
    }

    public func currentControlPlaneID() -> String {
        controlPlaneID
    }

    public func currentAPIURL() -> String {
        apiURL
    }

    private func startControlPlaneHeartbeat() {
        controlPlaneHeartbeatTask?.cancel()
        controlPlaneHeartbeatTask = Task.detached { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.publishControlPlaneRecord()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func startLeadershipLoop() {
        leadershipTask?.cancel()
        leadershipTask = Task.detached { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.evaluateLeadership()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func startDeploymentSyncLoop() {
        deploymentSyncTask?.cancel()
        deploymentSyncTask = Task.detached { [weak self] in
            guard let self else { return }
            await self.syncSharedDeploymentState(force: true)
            while !Task.isCancelled {
                await self.syncSharedDeploymentState()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func publishControlPlaneRecord() async {
        let status = isLeader ? "leader" : "standby"
        let record = ControlPlaneRecord(
            id: controlPlaneID,
            region: controlPlaneRegion,
            apiURL: apiURL,
            netbirdIP: netbirdIP,
            lastSeenAt: Date(),
            status: status
        )
        try? await stateStore.putControlPlaneRecord(record)
    }

    private func evaluateLeadership() async {
        let activeControlPlanes = (((try? await stateStore.listControlPlanes()) ?? [])
            .filter { Date().timeIntervalSince($0.lastSeenAt) < 5 })
            .sorted { $0.id < $1.id }

        let leaderID = activeControlPlanes.first?.id ?? controlPlaneID
        let shouldLead = leaderID == controlPlaneID
        guard shouldLead != isLeader else {
            return
        }

        isLeader = shouldLead
        await publishControlPlaneRecord()

        if shouldLead {
            logger?.log("This control plane is the LEADER")
            startReconciliationLoop()
            startLeaderHeartbeat()
        } else {
            logger?.log("This control plane is STANDBY")
            stopLeaderHeartbeat()
            stopReconciliationLoop()
        }
    }

    private func startLeaderHeartbeat() {
        leaderHeartbeatTask?.cancel()
        leaderHeartbeatTask = Task.detached { [weak self, store, logger] in
            guard let self else { return }
            let electedAt = Date()
            while !Task.isCancelled {
                let now = String(Date().timeIntervalSince1970)
                try? await store.set(Data(now.utf8), for: MeshScaleStoreKeySpace.leaderHeartbeat)
                try? await self.stateStore.putLeaderRecord(
                    ControlPlaneLeaderRecord(
                        controlPlaneId: self.controlPlaneID,
                        electedAt: electedAt,
                        lastHeartbeatAt: Date()
                    )
                )
                logger?.log("Leader heartbeat updated")
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func stopLeaderHeartbeat() {
        leaderHeartbeatTask?.cancel()
        leaderHeartbeatTask = nil
    }

    private func startReconciliationLoop() {
        guard reconcileTask == nil else {
            return
        }
        logger?.log("Starting reconciliation loop (every 500ms)")
        reconcileTask = Task.detached { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.reconcile()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func stopReconciliationLoop() {
        reconcileTask?.cancel()
        reconcileTask = nil
    }

    private func reconcile() async {
        guard beginReconcileCycle() else {
            return
        }
        defer { endReconcileCycle() }

        guard isLeader else { return }
        await syncSharedDeploymentState()
        if await runtimeHost.hasLoadedSource() {
            do {
                let observedState = await currentObservedState()
                let response = try await runtimeHost.tick(observedState: observedState)
                project.replaceRuntimeOutputs(response.outputs)
                project.replaceDesiredResources(response.desiredResources, domain: response.domain)
                for alert in response.alerts {
                    project.sendAlert(alert)
                }
                _ = project.drainAlerts()
            } catch {
                logger?.log("Swift project runtime tick failed: \(error.localizedDescription)")
            }
        }

        let desired = desiredResourcesIncludingSystemApps(project.currentDesiredResources())
        let plan = await planner.apply(desiredResources: desired, logger: logger, store: store)
        await self.syncAssignments(for: plan)
    }
    
    public func deployProject(_ projectCode: String) {
        logger?.log("Deploying project (received \(projectCode.utf8.count) bytes)...")
        
        Task {
            try? await store.set(Data(projectCode.utf8), for: MeshScaleStoreKeySpace.projectSource)
            try? await stateStore.putDeploymentMetadata(await nextDeploymentMetadata(kind: .swiftSource))
            await syncSharedDeploymentState(force: true)
        }
    }

    public func deployManifest(_ submission: DeploymentSubmission) {
        logger?.log("Deploying manifest with \(submission.resources.count) resources")
        project.replaceRuntimeOutputs([])
        project.replaceDesiredResources(submission.resources, domain: submission.domain)

        Task {
            try? await stateStore.putJSON(submission.resources, for: MeshScaleStoreKeySpace.desiredResources)
            try? await stateStore.putJSON([RuntimeOutput](), for: MeshScaleStoreKeySpace.runtimeOutputs)
            if let domain = submission.domain {
                try? await store.set(Data(domain.utf8), for: MeshScaleStoreKeySpace.projectDomain)
            } else {
                try? await store.delete(MeshScaleStoreKeySpace.projectDomain)
            }
            try? await store.delete(MeshScaleStoreKeySpace.projectSource)
            await runtimeHost.stop()
            try? await stateStore.putDeploymentMetadata(await nextDeploymentMetadata(kind: .manifest))
            await syncSharedDeploymentState(force: true)
        }
    }
    
    public func registerWorker(_ workerId: String, type: String, region: String) {
        logger?.log("Worker registered: \(workerId) (type: \(type), region: \(region))")

        Task {
            let workerType = WorkerType(rawValue: type) ?? .general
            let record = WorkerRecord(
                id: workerId,
                type: workerType,
                region: region,
                netbirdIP: "",
                attachedControlPlaneID: nil,
                lastSeenAt: Date(),
                status: "registered"
            )
            try? await stateStore.putWorkerRecord(record)
        }
    }
    
    public func scheduleTask(_ task: ControlPlaneTask) {
        logger?.log("Task scheduled: \(task.id)")
        // TODO: Resolve worker from task, then enqueue command via FoundationDB-backed store
    }

    public func statusSnapshot() async -> ControlPlaneStatusSnapshot {
        var snapshot = ControlPlaneStatusSnapshot(
            domain: nil,
            lastDeployedAt: nil,
            leaderControlPlaneID: nil,
            controlPlanes: [],
            projects: [],
            projectShards: [],
            desiredResources: [],
            runtimeOutputs: [],
            workers: [],
            workerHealth: [],
            workerContainers: [],
            currentPlan: nil,
            assignments: []
        )

        if let domainData = try? await store.get(MeshScaleStoreKeySpace.projectDomain),
           let decodedDomain = String(data: domainData, encoding: .utf8) {
            snapshot.domain = decodedDomain
        }
        snapshot.controlPlanes = (try? await stateStore.listControlPlanes()) ?? []
        snapshot.leaderControlPlaneID = try? await stateStore.getLeaderRecord()?.controlPlaneId
        snapshot.projects = (try? await stateStore.listSharedProjects()) ?? []
        snapshot.projectShards = (try? await stateStore.listProjectShards(projectId: MeshScaleStoreKeySpace.defaultProjectID)) ?? []
        let storedDesiredResources = (try? await stateStore.getJSON([DesiredResourceSpec].self, for: MeshScaleStoreKeySpace.desiredResources)) ?? []
        snapshot.desiredResources = desiredResourcesIncludingSystemApps(storedDesiredResources)
        snapshot.runtimeOutputs = (try? await stateStore.getJSON([RuntimeOutput].self, for: MeshScaleStoreKeySpace.runtimeOutputs)) ?? []
        snapshot.workers = (try? await stateStore.listWorkers()) ?? []
        let healthReports = (try? await stateStore.listWorkerHealthReports()) ?? [:]
        snapshot.workerHealth = healthReports.values.sorted { $0.workerId < $1.workerId }
        snapshot.lastDeployedAt = try? await stateStore.getDeploymentMetadata()?.lastDeployedAt

        var containerSnapshots: [WorkerContainersSnapshot] = []
        for worker in snapshot.workers {
            let statuses = (try? await stateStore.listContainerStatuses(workerId: worker.id)) ?? [:]
            let containers = statuses.values.sorted { $0.id < $1.id }
            containerSnapshots.append(WorkerContainersSnapshot(workerId: worker.id, containers: containers))
        }
        snapshot.workerContainers = containerSnapshots
        snapshot.currentPlan = try? await stateStore.getJSON(DeploymentPlan.self, for: MeshScaleStoreKeySpace.currentPlan)
        snapshot.assignments = (try? await stateStore.getJSON([WorkerAssignmentRecord].self, for: MeshScaleStoreKeySpace.currentAssignments)) ?? []
        return snapshot
    }

    public func managedFileBundle(named bundleID: String) -> [ManagedFile]? {
        switch bundleID {
        case MeshScaleDashboardBundle.bundleID:
            return dashboardBundle?.files
        default:
            return nil
        }
    }

    private func restorePersistedProjectState() async {
        await syncSharedDeploymentState(force: true)
    }

    private func nextDeploymentMetadata(kind: DeploymentKind) async -> DeploymentMetadata {
        let currentRevision = (try? await stateStore.getDeploymentMetadata())?.revision ?? 0
        return DeploymentMetadata(
            projectId: MeshScaleStoreKeySpace.defaultProjectID,
            revision: max(currentRevision, appliedDeploymentRevision) + 1,
            lastDeployedAt: Date(),
            deployedByControlPlaneID: controlPlaneID,
            deploymentKind: kind
        )
    }

    private func syncSharedDeploymentState(force: Bool = false) async {
        guard beginDeploymentSyncCycle() else {
            return
        }
        defer { endDeploymentSyncCycle() }

        let metadata = try? await stateStore.getDeploymentMetadata()
        let revision = metadata?.revision ?? 0
        guard force || revision > appliedDeploymentRevision else {
            return
        }

        await project.restoreFromStore()

        if let sourceData = try? await store.get(MeshScaleStoreKeySpace.projectSource),
           let source = String(data: sourceData, encoding: .utf8) {
            do {
                try await runtimeHost.loadSource(source)
                logger?.log("Applied shared deployment revision \(revision) from control plane store")
                appliedDeploymentRevision = revision
            } catch {
                logger?.log("Failed to load shared deployment revision \(revision): \(error.localizedDescription)")
                return
            }
        } else {
            await runtimeHost.stop()
            appliedDeploymentRevision = revision
        }
    }

    private func desiredResourcesIncludingSystemApps(_ desiredResources: [DesiredResourceSpec]) -> [DesiredResourceSpec] {
        var merged = desiredResources
        if let dashboardSpec = meshScaleDashboardSpec(),
           !merged.contains(where: { $0.kind == .meshscaleDashboard || $0.name == dashboardSpec.name }) {
            merged.append(dashboardSpec)
        }
        return merged.sorted { $0.name < $1.name }
    }

    private func meshScaleDashboardSpec() -> DesiredResourceSpec? {
        guard dashboardBundle != nil else {
            return nil
        }

        return DesiredResourceSpec(
            name: MeshScaleDashboardBundle.defaultResourceName,
            kind: .meshscaleDashboard,
            cpu: 1,
            memoryGB: 1,
            storageGB: nil,
            replicas: 1,
            image: "nginx:alpine",
            env: [:],
            ports: [MeshScaleDashboardBundle.defaultPort],
            latencySensitivity: .medium
        )
    }

    private func beginReconcileCycle() -> Bool {
        reconcileLock.lock()
        defer { reconcileLock.unlock() }

        if isReconciling {
            return false
        }

        isReconciling = true
        return true
    }

    private func endReconcileCycle() {
        reconcileLock.lock()
        isReconciling = false
        reconcileLock.unlock()
    }

    private func beginDeploymentSyncCycle() -> Bool {
        deploymentSyncLock.lock()
        defer { deploymentSyncLock.unlock() }

        if isSyncingDeploymentState {
            return false
        }

        isSyncingDeploymentState = true
        return true
    }

    private func endDeploymentSyncCycle() {
        deploymentSyncLock.lock()
        isSyncingDeploymentState = false
        deploymentSyncLock.unlock()
    }

    private func currentObservedState() async -> SwiftProjectObservedState {
        let workers = (try? await stateStore.listWorkers()) ?? []
        let currentPlan = try? await stateStore.getJSON(DeploymentPlan.self, for: MeshScaleStoreKeySpace.currentPlan)

        var statusesByResource: [String: [ContainerStatus]] = [:]

        for worker in workers {
            let statuses = (try? await stateStore.listContainerStatuses(workerId: worker.id)) ?? [:]
            for status in statuses.values {
                let resourceName = inferResourceName(
                    for: status.id,
                    containers: currentPlan?.containers
                )
                statusesByResource[resourceName, default: []].append(status)
            }
        }

        var metrics: [String: ResourceMetrics] = [:]
        var health: [String: ResourceHealth] = [:]

        for (resourceName, statuses) in statusesByResource {
            let runningStatuses = statuses.filter { $0.status == "running" }
            let averageCPU = statuses.isEmpty ? 0 : statuses.map(\.cpu).reduce(0, +) / Double(statuses.count)
            let averageMemory = statuses.isEmpty ? 0 : statuses.map(\.memory).reduce(0, +) / Double(statuses.count)
            let errorRate = statuses.isEmpty
                ? 0
                : Double(statuses.filter { $0.status == "failed" }.count) / Double(statuses.count)

            metrics[resourceName] = ResourceMetrics(
                cpu: averageCPU,
                memory: averageMemory,
                requestsPerSecond: 0,
                qps: 0,
                avgResponseTime: 0,
                errorRate: errorRate,
                currentReplicas: runningStatuses.count
            )

            let resourceStatus: ResourceStatus
            if statuses.contains(where: { $0.status == "failed" }) {
                resourceStatus = .failed
            } else if !runningStatuses.isEmpty {
                resourceStatus = .running
            } else if statuses.contains(where: { $0.status == "starting" || $0.status == "created" }) {
                resourceStatus = .provisioning
            } else {
                resourceStatus = .pending
            }

            health[resourceName] = ResourceHealth(
                status: resourceStatus,
                avgResponseTime: 0,
                currentReplicas: runningStatuses.count
            )
        }

        return SwiftProjectObservedState(metrics: metrics, health: health)
    }

    private func inferResourceName(
        for containerId: String,
        containers: [PlannedContainer]?
    ) -> String {
        if let explicitMatch = containers?.first(where: { $0.id == containerId }) {
            return explicitMatch.resourceName
        }

        if let range = containerId.range(of: #"-\d+$"#, options: .regularExpression) {
            return String(containerId[..<range.lowerBound])
        }

        return containerId
    }

    private func syncAssignments(for plan: DeploymentPlan) async {
        let workers = ((try? await stateStore.listWorkers()) ?? [])
            .filter { Date().timeIntervalSince($0.lastSeenAt) < 30 }
            .sorted { $0.id < $1.id }

        guard !workers.isEmpty else {
            logger?.log("No active workers registered; plan stored but not assigned")
            try? await stateStore.putAssignments([])
            return
        }

        var desiredCommandsByWorker: [String: [String: ContainerCommand]] = [:]
        var assignments: [WorkerAssignmentRecord] = []
        var roundRobinIndex = 0

        for container in plan.containers {
            let compatibleWorkers = workers.filter { worker in
                isCompatible(worker: worker.type, with: container.workerTypeHint)
            }
            let nonControlPlaneWorkers = workers.filter { $0.type != .controlPlane }
            let fallbackWorkers = nonControlPlaneWorkers.isEmpty ? workers : nonControlPlaneWorkers
            let candidates = compatibleWorkers.isEmpty ? fallbackWorkers : compatibleWorkers
            let worker: WorkerRecord
            if let targetWorkerId = container.targetWorkerId {
                guard let targetedWorker = candidates.first(where: { $0.id == targetWorkerId }) else {
                    logger?.log("Skipping \(container.id); target worker \(targetWorkerId) is not currently registered")
                    continue
                }
                worker = targetedWorker
            } else {
                worker = candidates[roundRobinIndex % candidates.count]
                roundRobinIndex += 1
            }

            let command = ContainerCommand(
                id: container.id,
                action: .start,
                image: resolvedImage(for: container),
                env: container.env,
                ports: resolvedPortBindings(for: container),
                volumes: containerVolumes(for: container),
                files: containerFiles(for: container),
                managedFileBundleID: container.managedFileBundleID,
                args: containerArguments(for: container)
            )

            desiredCommandsByWorker[worker.id, default: [:]][container.id] = command
            let previousAssignments = (try? await stateStore.getJSON(
                [WorkerAssignmentRecord].self,
                for: MeshScaleStoreKeySpace.currentAssignments
            )) ?? []
            let previousAssignment = previousAssignments.first {
                $0.workerId == worker.id &&
                $0.containerId == container.id &&
                $0.image == command.image &&
                $0.assignedByControlPlaneID == controlPlaneID
            }

            assignments.append(
                WorkerAssignmentRecord(
                    workerId: worker.id,
                    containerId: container.id,
                    image: command.image,
                    assignedByControlPlaneID: controlPlaneID,
                    assignedAt: previousAssignment?.assignedAt ?? Date()
                )
            )
        }

        for worker in workers {
            let existing = (try? await stateStore.listDesiredCommands(workerId: worker.id)) ?? [:]
            let desired = desiredCommandsByWorker[worker.id] ?? [:]

            for (containerId, command) in desired where existing[MeshScaleStoreKeySpace.workerDesiredContainer(worker.id, containerId: containerId)] != command {
                try? await stateStore.putDesiredCommand(command, workerId: worker.id)
            }

            for key in existing.keys {
                let containerId = String(key.dropFirst(MeshScaleStoreKeySpace.workerDesiredPrefix(worker.id).count))
                if desired[containerId] == nil {
                    try? await stateStore.deleteDesiredCommand(workerId: worker.id, containerId: containerId)
                }
            }
        }

        let previousAssignments = ((try? await stateStore.getJSON(
            [WorkerAssignmentRecord].self,
            for: MeshScaleStoreKeySpace.currentAssignments
        )) ?? []).sorted {
            ($0.workerId, $0.containerId, $0.image ?? "", $0.assignedByControlPlaneID ?? "", $0.assignedAt) <
            ($1.workerId, $1.containerId, $1.image ?? "", $1.assignedByControlPlaneID ?? "", $1.assignedAt)
        }
        let sortedAssignments = assignments.sorted {
            ($0.workerId, $0.containerId, $0.image ?? "", $0.assignedByControlPlaneID ?? "", $0.assignedAt) <
            ($1.workerId, $1.containerId, $1.image ?? "", $1.assignedByControlPlaneID ?? "", $1.assignedAt)
        }

        if previousAssignments != sortedAssignments {
            try? await stateStore.putAssignments(assignments)
            logger?.log("Assigned \(assignments.count) containers across \(workers.count) workers")
        }

        await publishSharedProjectTopology(plan: plan, assignments: assignments, workers: workers)
    }

    private func publishSharedProjectTopology(
        plan: DeploymentPlan,
        assignments: [WorkerAssignmentRecord],
        workers: [WorkerRecord]
    ) async {
        let projectId = MeshScaleStoreKeySpace.defaultProjectID
        let metadata = try? await stateStore.getDeploymentMetadata()
        let controlPlanes = (try? await stateStore.listControlPlanes()) ?? []
        let workersById = Dictionary(uniqueKeysWithValues: workers.map { ($0.id, $0) })
        let resourceNamesByContainer = Dictionary(uniqueKeysWithValues: plan.containers.map { ($0.id, $0.resourceName) })

        struct RegionTopology {
            var controlPlaneIds = Set<String>()
            var workerIds = Set<String>()
            var resourceNames = Set<String>()
            var containerIds = Set<String>()
        }

        var topologyByRegion: [String: RegionTopology] = [:]

        for controlPlane in controlPlanes {
            topologyByRegion[controlPlane.region, default: RegionTopology()].controlPlaneIds.insert(controlPlane.id)
        }

        for assignment in assignments {
            guard let worker = workersById[assignment.workerId] else {
                continue
            }
            topologyByRegion[worker.region, default: RegionTopology()].workerIds.insert(worker.id)
            topologyByRegion[worker.region, default: RegionTopology()].containerIds.insert(assignment.containerId)
            if let resourceName = resourceNamesByContainer[assignment.containerId] {
                topologyByRegion[worker.region, default: RegionTopology()].resourceNames.insert(resourceName)
            }
        }

        if topologyByRegion.isEmpty {
            topologyByRegion[controlPlaneRegion] = RegionTopology()
            topologyByRegion[controlPlaneRegion]?.controlPlaneIds.insert(controlPlaneID)
            for resource in plan.resources {
                topologyByRegion[controlPlaneRegion]?.resourceNames.insert(resource.name)
            }
        }

        let existingShards = (try? await stateStore.listProjectShards(projectId: projectId)) ?? []
        let existingShardsById = Dictionary(uniqueKeysWithValues: existingShards.map { ($0.shardId, $0) })
        let shardRecords = topologyByRegion.keys.sorted().map { region in
            let topology = topologyByRegion[region] ?? RegionTopology()
            let previous = existingShardsById[region]
            return ProjectShardRecord(
                projectId: projectId,
                shardId: region,
                region: region,
                controlPlaneIds: Array(topology.controlPlaneIds),
                workerIds: Array(topology.workerIds),
                desiredResourceNames: Array(topology.resourceNames),
                containerIds: Array(topology.containerIds),
                lastUpdatedAt: previous?.controlPlaneIds == Array(topology.controlPlaneIds).sorted() &&
                    previous?.workerIds == Array(topology.workerIds).sorted() &&
                    previous?.desiredResourceNames == Array(topology.resourceNames).sorted() &&
                    previous?.containerIds == Array(topology.containerIds).sorted()
                    ? (previous?.lastUpdatedAt ?? Date())
                    : Date()
            )
        }
        let activeShardIds = Set(shardRecords.map(\.shardId))
        for shard in existingShards where !activeShardIds.contains(shard.shardId) {
            try? await stateStore.deleteProjectShard(projectId: projectId, shardId: shard.shardId)
        }

        for shard in shardRecords {
            if existingShardsById[shard.shardId] != shard {
                try? await stateStore.putProjectShard(shard)
            }
        }

        let primaryRegion = shardRecords.max {
            ($0.containerIds.count, $0.region) < ($1.containerIds.count, $1.region)
        }?.region ?? controlPlaneRegion
        let domain = project.currentDomain().isEmpty ? nil : project.currentDomain()
        let previousSharedProject = (try? await stateStore.getSharedProjectRecord(projectId: projectId))
        let sharedProject = SharedProjectRecord(
            id: projectId,
            domain: domain,
            revision: metadata?.revision ?? appliedDeploymentRevision,
            primaryRegion: primaryRegion,
            shardIds: shardRecords.map(\.shardId),
            lastDeployedAt: metadata?.lastDeployedAt,
            lastUpdatedAt: previousSharedProject?.domain == domain &&
                previousSharedProject?.revision == (metadata?.revision ?? appliedDeploymentRevision) &&
                previousSharedProject?.primaryRegion == primaryRegion &&
                previousSharedProject?.shardIds == shardRecords.map(\.shardId).sorted() &&
                previousSharedProject?.lastDeployedAt == metadata?.lastDeployedAt
                ? (previousSharedProject?.lastUpdatedAt ?? Date())
                : Date()
        )
        if previousSharedProject != sharedProject {
            try? await stateStore.putSharedProjectRecord(sharedProject)
        }
    }

    private func resolvedImage(for container: PlannedContainer) -> String? {
        if let image = container.image {
            return image
        }

        switch container.kind {
        case .database:
            return "postgres:16-alpine"
        case .cache:
            return "redis:7-alpine"
        case .messageQueue:
            return "rabbitmq:3-management"
        case .webService, .staticSite, .meshscaleDashboard:
            return "nginx:alpine"
        case .netbirdDashboard:
            return "netbirdio/dashboard:latest"
        case .httpService, .backgroundWorker, .objectStorage:
            return nil
        }
    }

    private func resolvedPortBindings(for container: PlannedContainer) -> [PortBinding]? {
        if let bindings = container.portBindings, !bindings.isEmpty {
            return bindings
        }

        if container.ports.isEmpty {
            return nil
        }

        return container.ports.map {
            PortBinding(hostPort: $0, containerPort: $0)
        }
    }

    private func containerVolumes(for container: PlannedContainer) -> [VolumeMount]? {
        container.volumes
    }

    private func containerFiles(for container: PlannedContainer) -> [ManagedFile]? {
        container.files
    }

    private func containerArguments(for container: PlannedContainer) -> [String]? {
        container.args
    }

    private func isCompatible(worker: WorkerType, with required: WorkerType) -> Bool {
        if worker == required {
            return true
        }

        switch (worker, required) {
        case (.compute, .general), (.databaseHeavy, .general):
            return true
        default:
            return false
        }
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

public struct DeploymentSubmission: Codable, Sendable {
    public let domain: String?
    public let resources: [DesiredResourceSpec]

    public init(domain: String? = nil, resources: [DesiredResourceSpec]) {
        self.domain = domain
        self.resources = resources
    }
}

public struct ControlPlaneStatusSnapshot: Codable, Sendable {
    public var domain: String?
    public var lastDeployedAt: Date?
    public var leaderControlPlaneID: String?
    public var controlPlanes: [ControlPlaneRecord]
    public var projects: [SharedProjectRecord]
    public var projectShards: [ProjectShardRecord]
    public var desiredResources: [DesiredResourceSpec]
    public var runtimeOutputs: [RuntimeOutput]
    public var workers: [WorkerRecord]
    public var workerHealth: [WorkerHealthReport]
    public var workerContainers: [WorkerContainersSnapshot]
    public var currentPlan: DeploymentPlan?
    public var assignments: [WorkerAssignmentRecord]

    public init(
        domain: String?,
        lastDeployedAt: Date?,
        leaderControlPlaneID: String?,
        controlPlanes: [ControlPlaneRecord],
        projects: [SharedProjectRecord],
        projectShards: [ProjectShardRecord],
        desiredResources: [DesiredResourceSpec],
        runtimeOutputs: [RuntimeOutput],
        workers: [WorkerRecord],
        workerHealth: [WorkerHealthReport],
        workerContainers: [WorkerContainersSnapshot],
        currentPlan: DeploymentPlan?,
        assignments: [WorkerAssignmentRecord]
    ) {
        self.domain = domain
        self.lastDeployedAt = lastDeployedAt
        self.leaderControlPlaneID = leaderControlPlaneID
        self.controlPlanes = controlPlanes
        self.projects = projects
        self.projectShards = projectShards
        self.desiredResources = desiredResources
        self.runtimeOutputs = runtimeOutputs
        self.workers = workers
        self.workerHealth = workerHealth
        self.workerContainers = workerContainers
        self.currentPlan = currentPlan
        self.assignments = assignments
    }
}

public struct WorkerContainersSnapshot: Codable, Sendable {
    public let workerId: String
    public let containers: [ContainerStatus]

    public init(workerId: String, containers: [ContainerStatus]) {
        self.workerId = workerId
        self.containers = containers
    }
}

// MARK: - Deployment planning

/// High-level container-like unit the control plane wants to run.
/// This does not assume Docker vs Kubernetes; it is just "something
/// that should be running" with image/env/ports.
public struct PlannedContainer: Codable, Equatable, Sendable {
    public let id: String
    public let resourceName: String
    public let replicaIndex: Int
    public let targetWorkerId: String?
    public let kind: ResourceKind
    public let image: String?
    public let cpu: Int
    public let memoryGB: Double
    public let ports: [Int]
    public let portBindings: [PortBinding]?
    public let env: [String: String]
    public let volumes: [VolumeMount]?
    public let files: [ManagedFile]?
    public let managedFileBundleID: String?
    public let args: [String]?
    public let workerTypeHint: WorkerType
    
    public init(
        id: String,
        resourceName: String,
        replicaIndex: Int,
        targetWorkerId: String? = nil,
        kind: ResourceKind,
        image: String?,
        cpu: Int,
        memoryGB: Double,
        ports: [Int],
        portBindings: [PortBinding]? = nil,
        env: [String: String],
        volumes: [VolumeMount]? = nil,
        files: [ManagedFile]? = nil,
        managedFileBundleID: String? = nil,
        args: [String]? = nil,
        workerTypeHint: WorkerType
    ) {
        self.id = id
        self.resourceName = resourceName
        self.replicaIndex = replicaIndex
        self.targetWorkerId = targetWorkerId
        self.kind = kind
        self.image = image
        self.cpu = cpu
        self.memoryGB = memoryGB
        self.ports = ports
        self.portBindings = portBindings
        self.env = env
        self.volumes = volumes
        self.files = files
        self.managedFileBundleID = managedFileBundleID
        self.args = args
        self.workerTypeHint = workerTypeHint
    }
}

/// A deployment plan is the desired set of containers the control plane
/// wants to be running. Backends (Docker, Kubernetes, etc.) can consume this.
public struct DeploymentPlan: Codable, Equatable, Sendable {
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
    ) async -> DeploymentPlan
}

/// Default planner used in dev: builds a plan and writes it to the store
/// at `deployments/current-plan` and logs what it would do.
public struct LoggingDeploymentPlanner: DeploymentPlanner {
    public init() {}
    
    public func apply(
        desiredResources: [DesiredResourceSpec],
        logger: Logger?,
        store: any MeshScaleStoreClient
    ) async -> DeploymentPlan {
        // Build a simple plan: expand replicas into separate container IDs
        var containers: [PlannedContainer] = []
        let controlPlaneWorkers = ((try? await MeshScaleStateStore(client: store).listWorkers()) ?? [])
            .filter { $0.type == .controlPlane }
            .filter { Date().timeIntervalSince($0.lastSeenAt) < 30 }
            .sorted { $0.id < $1.id }
        for spec in desiredResources {
            if spec.kind == .meshscaleDashboard {
                let hostingWorkers = controlPlaneWorkers.isEmpty
                    ? [WorkerRecord(
                        id: "control-plane",
                        type: .controlPlane,
                        region: "control-plane",
                        netbirdIP: "",
                        attachedControlPlaneID: nil,
                        lastSeenAt: Date(),
                        status: "unknown"
                    )]
                    : controlPlaneWorkers

                for (index, worker) in hostingWorkers.enumerated() {
                    let dashboardPort = meshScaleDashboardPort(for: spec)
                    containers.append(
                        PlannedContainer(
                            id: meshScaleDashboardContainerID(resourceName: spec.name, workerId: worker.id),
                            resourceName: spec.name,
                            replicaIndex: index,
                            targetWorkerId: worker.id,
                            kind: .meshscaleDashboard,
                            image: spec.image ?? "nginx:alpine",
                            cpu: spec.cpu,
                            memoryGB: spec.memoryGB,
                            ports: [dashboardPort],
                            portBindings: [
                                PortBinding(hostPort: dashboardPort, containerPort: 80),
                            ],
                            env: spec.env,
                            files: nil,
                            managedFileBundleID: MeshScaleDashboardBundle.bundleID,
                            workerTypeHint: .controlPlane
                        )
                    )
                }
                continue
            }

            if spec.kind == .netbirdDashboard {
                let hostingWorkers = controlPlaneWorkers.isEmpty
                    ? [WorkerRecord(
                        id: "control-plane",
                        type: .controlPlane,
                        region: "control-plane",
                        netbirdIP: "",
                        lastSeenAt: Date(),
                        status: "unknown"
                    )]
                    : controlPlaneWorkers

                for (index, worker) in hostingWorkers.enumerated() {
                    let host = netBirdServiceHost(for: worker, spec: spec)
                    let dashboardPort = netBirdDashboardPort(for: spec)
                    let managementPort = netBirdManagementPort(for: spec)
                    let config = netBirdServerConfig(
                        host: host,
                        dashboardPort: dashboardPort,
                        managementPort: managementPort
                    )
                    let dataDirectory = netBirdDataDirectory(for: worker.id, resourceName: spec.name)

                    containers.append(
                        PlannedContainer(
                            id: netBirdServerContainerID(resourceName: spec.name, workerId: worker.id),
                            resourceName: spec.name,
                            replicaIndex: index,
                            targetWorkerId: worker.id,
                            kind: .backgroundWorker,
                            image: "netbirdio/netbird-server:latest",
                            cpu: spec.cpu,
                            memoryGB: spec.memoryGB,
                            ports: [managementPort],
                            portBindings: [
                                PortBinding(hostPort: managementPort, containerPort: 80),
                            ],
                            env: [:],
                            volumes: [
                                VolumeMount(name: dataDirectory, mountPath: "/var/lib/netbird"),
                            ],
                            files: [
                                ManagedFile(
                                    relativePath: "config.yaml",
                                    mountPath: "/etc/netbird/config.yaml",
                                    content: config
                                ),
                            ],
                            args: ["--config", "/etc/netbird/config.yaml"],
                            workerTypeHint: .controlPlane
                        )
                    )

                    containers.append(
                        PlannedContainer(
                            id: netBirdDashboardContainerID(resourceName: spec.name, workerId: worker.id),
                            resourceName: spec.name,
                            replicaIndex: index,
                            targetWorkerId: worker.id,
                            kind: spec.kind,
                            image: spec.image,
                            cpu: spec.cpu,
                            memoryGB: spec.memoryGB,
                            ports: [dashboardPort],
                            portBindings: [
                                PortBinding(hostPort: dashboardPort, containerPort: 80),
                            ],
                            env: netBirdDashboardEnvironment(
                                host: host,
                                dashboardPort: dashboardPort,
                                managementPort: managementPort
                            ),
                            workerTypeHint: .controlPlane
                        )
                    )
                }
                continue
            }

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
                case .httpService, .webService, .staticSite, .cache:
                    workerHint = .general
                case .meshscaleDashboard, .netbirdDashboard:
                    workerHint = .controlPlane
                }
                
                containers.append(
                    PlannedContainer(
                        id: id,
                        resourceName: spec.name,
                        replicaIndex: index,
                        targetWorkerId: nil,
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
        
        let previousPlan = try? await MeshScaleStateStore(client: store).getJSON(
            DeploymentPlan.self,
            for: MeshScaleStoreKeySpace.currentPlan
        )
        let generatedAt: Date
        if let previousPlan,
           previousPlan.resources == desiredResources,
           previousPlan.containers == containers {
            generatedAt = previousPlan.generatedAt
        } else {
            generatedAt = Date()
        }

        let plan = DeploymentPlan(
            generatedAt: generatedAt,
            resources: desiredResources,
            containers: containers
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        
        if previousPlan != plan {
            if let data = try? encoder.encode(plan) {
                try? await store.set(data, for: MeshScaleStoreKeySpace.currentPlan)
            }
            logger?.log("Deployment plan updated with \(containers.count) containers")
        }
        return plan
    }

    private func netBirdDashboardContainerID(resourceName: String, workerId: String) -> String {
        "\(resourceName)-dashboard-\(sanitizeWorkerID(workerId))"
    }

    private func meshScaleDashboardContainerID(resourceName: String, workerId: String) -> String {
        "\(resourceName)-ui-\(sanitizeWorkerID(workerId))"
    }

    private func netBirdServerContainerID(resourceName: String, workerId: String) -> String {
        "\(resourceName)-server-\(sanitizeWorkerID(workerId))"
    }

    private func sanitizeWorkerID(_ workerId: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-")
        return workerId.unicodeScalars
            .map { allowed.contains($0) ? String($0) : "_" }
            .joined()
    }

    private func netBirdDashboardPort(for spec: DesiredResourceSpec) -> Int {
        Int(spec.env["MESHCALE_NETBIRD_DASHBOARD_HOST_PORT"] ?? "") ?? spec.ports.first ?? 18080
    }

    private func meshScaleDashboardPort(for spec: DesiredResourceSpec) -> Int {
        spec.ports.first ?? MeshScaleDashboardBundle.defaultPort
    }

    private func netBirdManagementPort(for spec: DesiredResourceSpec) -> Int {
        Int(spec.env["MESHCALE_NETBIRD_MANAGEMENT_HOST_PORT"] ?? "") ?? 18081
    }

    private func netBirdServiceHost(for worker: WorkerRecord, spec: DesiredResourceSpec) -> String {
        if let configured = spec.env["MESHCALE_NETBIRD_PUBLIC_HOST"], !configured.isEmpty {
            return configured
        }
        if !worker.netbirdIP.isEmpty {
            return worker.netbirdIP
        }
        return "localhost"
    }

    private func netBirdDashboardEnvironment(
        host: String,
        dashboardPort: Int,
        managementPort: Int
    ) -> [String: String] {
        let base = "http://\(host):\(managementPort)"
        return [
            "NETBIRD_MGMT_API_ENDPOINT": base,
            "NETBIRD_MGMT_GRPC_API_ENDPOINT": base,
            "AUTH_AUDIENCE": "netbird-dashboard",
            "AUTH_CLIENT_ID": "netbird-dashboard",
            "AUTH_CLIENT_SECRET": "",
            "AUTH_AUTHORITY": "\(base)/oauth2",
            "USE_AUTH0": "false",
            "AUTH_SUPPORTED_SCOPES": "openid profile email groups",
            "AUTH_REDIRECT_URI": "/nb-auth",
            "AUTH_SILENT_REDIRECT_URI": "/nb-silent-auth",
            "LETSENCRYPT_DOMAIN": "none",
            "NGINX_SSL_PORT": "443",
        ]
    }

    private func netBirdServerConfig(
        host: String,
        dashboardPort: Int,
        managementPort: Int
    ) -> String {
        let relaySecret = "meshscale-netbird-relay-secret-\(sanitizeWorkerID(host))-\(managementPort)"
        let encryptionKey = netBirdEncryptionKey(seed: "\(host):\(managementPort)")
        let redirectHosts = netBirdLoopbackHosts(for: host)
        var lines = [
            "server:",
            "  listenAddress: \":80\"",
            "  exposedAddress: \"http://\(host):\(managementPort)\"",
            "  stunPorts:",
            "    - 3478",
            "  metricsPort: 9090",
            "  healthcheckAddress: \":9000\"",
            "  logLevel: \"info\"",
            "  logFile: \"console\"",
            "  authSecret: \"\(relaySecret)\"",
            "  dataDir: \"/var/lib/netbird\"",
            "  auth:",
            "    issuer: \"http://\(host):\(managementPort)/oauth2\"",
            "    signKeyRefreshEnabled: true",
            "    dashboardRedirectURIs:",
        ]
        lines.append(
            contentsOf: redirectHosts.flatMap { redirectHost in
                [
                    "      - \"http://\(redirectHost):\(dashboardPort)/nb-auth\"",
                    "      - \"http://\(redirectHost):\(dashboardPort)/nb-silent-auth\"",
                ]
            }
        )
        lines.append(
            contentsOf: [
                "    cliRedirectURIs:",
                "      - \"http://localhost:53000/\"",
                "  store:",
                "    engine: \"sqlite\"",
                "    dsn: \"\"",
                "    encryptionKey: \"\(encryptionKey)\"",
            ]
        )
        return lines.joined(separator: "\n")
    }

    private func netBirdDataDirectory(for workerId: String, resourceName: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/meshscale/netbird/\(sanitizeWorkerID(workerId))/\(resourceName)"
    }

    private func netBirdEncryptionKey(seed: String) -> String {
        var bytes = Array(seed.utf8)
        if bytes.isEmpty {
            bytes = [0]
        }

        while bytes.count < 32 {
            bytes.append(contentsOf: bytes)
        }

        return Data(bytes.prefix(32)).base64EncodedString()
    }

    private func netBirdLoopbackHosts(for host: String) -> [String] {
        if host == "localhost" || host == "127.0.0.1" {
            return ["localhost", "127.0.0.1"]
        }
        return [host]
    }
}
