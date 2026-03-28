import Foundation
import ArgumentParser
import MeshScaleControlPlaneRuntime
import MeshScaleStore

extension MeshScaleCLI {
    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Inspect persisted MeshScale state"
        )

        @Flag(name: .long, help: "Emit JSON instead of a human-readable summary")
        var json: Bool = false

        @Option(name: .long, help: "Optional store namespace for isolated clusters")
        var namespace: String?

        func run() throws {
            let snapshot = try loadStatusSnapshot(namespace: namespace)

            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(snapshot)
                if let output = String(data: data, encoding: .utf8) {
                    print(output)
                }
                return
            }

            print("Store backend: \(snapshot.storeBackend)")
            print("Control plane process: \(snapshot.processSummary)")
            print("Leader control plane: \(snapshot.snapshot.leaderControlPlaneID ?? "unknown")")
            print("Control planes: \(snapshot.snapshot.controlPlanes.count)")
            print("Shared projects: \(snapshot.snapshot.projects.count)")
            print("Domain: \(snapshot.snapshot.domain ?? "not set")")
            print("Desired resources: \(snapshot.snapshot.desiredResources.count)")
            print("Runtime outputs: \(snapshot.snapshot.runtimeOutputs.count)")
            print("Desired containers: \(snapshot.snapshot.currentPlan?.containers.count ?? 0)")
            print("Assignments: \(snapshot.snapshot.assignments.count)")
            print("Workers: \(snapshot.snapshot.workers.count)")

            if !snapshot.snapshot.runtimeOutputs.isEmpty {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                print("")
                print("Runtime outputs:")
                for output in snapshot.snapshot.runtimeOutputs {
                    print("- \(output.key)=\(output.value) updated=\(formatter.string(from: output.updatedAt))")
                }
            }

            if !snapshot.snapshot.workers.isEmpty {
                print("")
                if !snapshot.snapshot.controlPlanes.isEmpty {
                    print("Control plane details:")
                    for controlPlane in snapshot.snapshot.controlPlanes {
                        let age = Int(Date().timeIntervalSince(controlPlane.lastSeenAt))
                        print("- \(controlPlane.id) \(controlPlane.status) region=\(controlPlane.region) api=\(controlPlane.apiURL) lastSeen=\(age)s ago")
                    }
                    print("")
                }

                if !snapshot.snapshot.projectShards.isEmpty {
                    print("Project shards:")
                    for shard in snapshot.snapshot.projectShards {
                        print("- \(shard.projectId) shard=\(shard.shardId) region=\(shard.region) workers=\(shard.workerIds.count) containers=\(shard.containerIds.count)")
                    }
                    print("")
                }

                print("Worker details:")
                for worker in snapshot.snapshot.workers {
                    let age = Int(Date().timeIntervalSince(worker.lastSeenAt))
                    let health = snapshot.snapshot.workerHealth.first { $0.workerId == worker.id }
                    let containerSnapshot = snapshot.snapshot.workerContainers.first { $0.workerId == worker.id }
                    let attached = worker.attachedControlPlaneID ?? "unattached"
                    print("- \(worker.id) [\(worker.type.rawValue)] \(worker.status) region=\(worker.region) controlPlane=\(attached) lastSeen=\(age)s ago")
                    if let health {
                        print("  health: running=\(health.runningContainers) total=\(health.totalContainers)")
                    }
                    let failedContainers = (containerSnapshot?.containers ?? []).filter { $0.status == "failed" }
                    if !failedContainers.isEmpty {
                        for container in failedContainers {
                            let retries = container.retryCount
                            let message = container.lastError ?? "unknown error"
                            print("  failed: \(container.id) retries=\(retries) error=\(message)")
                        }
                    }
                }
            }
        }
    }
}

struct PersistedStatusSnapshot: Codable {
    let storeBackend: String
    let processSummary: String
    let snapshot: ControlPlaneStatusSnapshot
}

private final class PersistedStatusSnapshotBox: @unchecked Sendable {
    var result: Result<PersistedStatusSnapshot, Error>?
}

func loadStatusSnapshot() throws -> PersistedStatusSnapshot {
    try loadStatusSnapshot(namespace: nil)
}

func loadStatusSnapshot(namespace: String?) throws -> PersistedStatusSnapshot {
    let semaphore = DispatchSemaphore(value: 0)
    let box = PersistedStatusSnapshotBox()

    Task {
        let store = MeshScaleStoreFactory.makeStore(namespace: namespace)
        let stateStore = MeshScaleStateStore(client: store)

        let leader = try? await stateStore.getLeaderRecord()
        let rawControlPlanes = (try? await stateStore.listControlPlanes()) ?? []
        let controlPlanes = rawControlPlanes.map { controlPlane in
            let age = Date().timeIntervalSince(controlPlane.lastSeenAt)
            let derivedStatus: String
            if age >= 5 {
                derivedStatus = "stale"
            } else if controlPlane.id == leader?.controlPlaneId {
                derivedStatus = "leader"
            } else {
                derivedStatus = "standby"
            }

            return ControlPlaneRecord(
                id: controlPlane.id,
                region: controlPlane.region,
                apiURL: controlPlane.apiURL,
                netbirdIP: controlPlane.netbirdIP,
                lastSeenAt: controlPlane.lastSeenAt,
                status: derivedStatus
            )
        }
        let workers = (try? await stateStore.listWorkers()) ?? []
        let health = ((try? await stateStore.listWorkerHealthReports()) ?? [:]).values.sorted { $0.workerId < $1.workerId }
        let plan = try? await stateStore.getJSON(DeploymentPlan.self, for: MeshScaleStoreKeySpace.currentPlan)
        let assignments = (try? await stateStore.getJSON([WorkerAssignmentRecord].self, for: MeshScaleStoreKeySpace.currentAssignments)) ?? []

        var domain: String?
        if let domainData = try? await store.get(MeshScaleStoreKeySpace.projectDomain),
           let decodedDomain = String(data: domainData, encoding: .utf8) {
            domain = decodedDomain
        }

        let backend = await store.backendDescription()

        let desiredResources = (try? await stateStore.getJSON([DesiredResourceSpec].self, for: MeshScaleStoreKeySpace.desiredResources)) ?? []
        let runtimeOutputs = (try? await stateStore.getJSON([RuntimeOutput].self, for: MeshScaleStoreKeySpace.runtimeOutputs)) ?? []
        let projects = (try? await stateStore.listSharedProjects()) ?? []
        let projectShards = (try? await stateStore.listProjectShards(projectId: MeshScaleStoreKeySpace.defaultProjectID)) ?? []

        var workerContainers: [WorkerContainersSnapshot] = []
        for worker in workers {
            let containers = ((try? await stateStore.listContainerStatuses(workerId: worker.id)) ?? [:]).values.sorted { $0.id < $1.id }
            workerContainers.append(WorkerContainersSnapshot(workerId: worker.id, containers: containers))
        }

        let processSummary: String
        if let pid = ConfigManager.shared.loadPid(for: "control-plane") {
            processSummary = ConfigManager.shared.isProcessRunning(pid) ? "running (PID: \(pid))" : "not running (stale PID: \(pid))"
        } else {
            processSummary = "not running"
        }

        let snapshot = ControlPlaneStatusSnapshot(
            domain: domain,
            lastDeployedAt: nil,
            leaderControlPlaneID: leader?.controlPlaneId,
            controlPlanes: controlPlanes,
            projects: projects,
            projectShards: projectShards,
            desiredResources: desiredResources,
            runtimeOutputs: runtimeOutputs,
            workers: workers,
            workerHealth: health,
            workerContainers: workerContainers,
            currentPlan: plan,
            assignments: assignments
        )

        box.result = .success(
            PersistedStatusSnapshot(
                storeBackend: backend,
                processSummary: processSummary,
                snapshot: snapshot
            )
        )
        semaphore.signal()
    }

    semaphore.wait()
    guard let result = box.result else {
        throw ExitCode.failure
    }
    return try result.get()
}
