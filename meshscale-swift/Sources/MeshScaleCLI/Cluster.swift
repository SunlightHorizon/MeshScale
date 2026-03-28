import Foundation
import ArgumentParser

extension MeshScaleCLI {
    struct Cluster: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "cluster",
            abstract: "Launch and inspect isolated multi-instance MeshScale clusters",
            subcommands: [Start.self, Stop.self, Status.self]
        )
    }
}

extension MeshScaleCLI.Cluster {
    struct Start: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "start",
            abstract: "Start a 2 control-plane / 3 worker local test cluster on FoundationDB"
        )

        @Option(name: .long, help: "Store namespace used to isolate this cluster")
        var namespace: String = "multi-instance-test"

        @Option(name: .long, help: "FoundationDB cluster file path. Defaults to the shared local MeshScale cluster file if present.")
        var clusterFile: String?

        func run() throws {
            let clusterFilePath = try resolveClusterFilePath(explicitPath: clusterFile)
            let specs = try clusterSpecs(namespace: namespace, clusterFilePath: clusterFilePath)

            for spec in specs {
                if let pid = ConfigManager.shared.loadPid(for: spec.serviceName),
                   ConfigManager.shared.isProcessRunning(pid) {
                    print("❌ \(spec.serviceName) is already running (PID: \(pid))")
                    throw ExitCode.failure
                }
            }

            for spec in specs {
                try spawnBackgroundProcess(spec)
            }

            print("Started MeshScale test cluster in namespace '\(namespace)'.")
            print("FoundationDB cluster file: \(clusterFilePath)")
            print("Control planes:")
            print("- cp-a: http://127.0.0.1:9180")
            print("- cp-b: http://127.0.0.1:9280")
            print("Workers:")
            print("- worker-a1 attached to cp-a")
            print("- worker-a2 attached to cp-a")
            print("- worker-b1 attached to cp-b")
        }
    }

    struct Stop: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stop",
            abstract: "Stop the local multi-instance test cluster"
        )

        @Option(name: .long, help: "Store namespace used to isolate this cluster")
        var namespace: String = "multi-instance-test"

        func run() throws {
            let clusterFilePath = try? resolveClusterFilePath(explicitPath: nil)
            for spec in (try? clusterSpecs(namespace: namespace, clusterFilePath: clusterFilePath)) ?? [] {
                if let pid = ConfigManager.shared.loadPid(for: spec.serviceName),
                   ConfigManager.shared.isProcessRunning(pid) {
                    _ = ConfigManager.shared.killProcess(pid)
                }
                ConfigManager.shared.removePid(for: spec.serviceName)
            }
            print("Stopped MeshScale test cluster '\(namespace)'.")
        }
    }

    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show the status of the local multi-instance test cluster"
        )

        @Option(name: .long, help: "Store namespace used to isolate this cluster")
        var namespace: String = "multi-instance-test"

        func run() throws {
            let snapshot = try loadStatusSnapshot(namespace: namespace)
            let groupedWorkers = Dictionary(grouping: snapshot.snapshot.workers, by: { $0.attachedControlPlaneID ?? "unattached" })

            print("Namespace: \(namespace)")
            print("Leader: \(snapshot.snapshot.leaderControlPlaneID ?? "unknown")")
            print("Control planes: \(snapshot.snapshot.controlPlanes.count)")
            for controlPlane in snapshot.snapshot.controlPlanes.sorted(by: { $0.id < $1.id }) {
                let attachedWorkers = groupedWorkers[controlPlane.id]?.count ?? 0
                let age = Int(Date().timeIntervalSince(controlPlane.lastSeenAt))
                print("- \(controlPlane.id) \(controlPlane.status) api=\(controlPlane.apiURL) workers=\(attachedWorkers) lastSeen=\(age)s ago")
            }

            print("Workers: \(snapshot.snapshot.workers.count)")
            for worker in snapshot.snapshot.workers.sorted(by: { $0.id < $1.id }) {
                let attached = worker.attachedControlPlaneID ?? "unattached"
                let age = Int(Date().timeIntervalSince(worker.lastSeenAt))
                print("- \(worker.id) type=\(worker.type.rawValue) attached=\(attached) lastSeen=\(age)s ago")
            }
        }
    }
}

private struct ClusterProcessSpec {
    let serviceName: String
    let executableURL: URL
    let environment: [String: String]
}

private func clusterSpecs(namespace: String, clusterFilePath: String?) throws -> [ClusterProcessSpec] {
    let binaryDirectory = try currentBinaryDirectory()
    let baseEnvironment = [
        "MESHCALE_STORE_NAMESPACE": namespace,
        "MESHCALE_NETBIRD_ENABLED": "false",
        "MESHCALE_FDB_CLUSTER_FILE": clusterFilePath ?? "",
    ]

    return [
        ClusterProcessSpec(
            serviceName: clusterServiceName(namespace: namespace, name: "cp-a"),
            executableURL: binaryDirectory.appendingPathComponent("MeshScaleControlPlane"),
            environment: baseEnvironment.merging([
                "MESHCALE_CONTROL_PLANE_ID": "cp-a",
                "MESHCALE_CONTROL_PLANE_REGION": "lab-a",
                "MESHCALE_CONTROL_PLANE_PORT": "9180",
                "MESHCALE_CONTROL_PLANE_PUBLIC_HOST": "127.0.0.1",
                "MESHCALE_CONTROL_PLANE_EMBEDDED_WORKER": "false",
            ]) { _, new in new }
        ),
        ClusterProcessSpec(
            serviceName: clusterServiceName(namespace: namespace, name: "cp-b"),
            executableURL: binaryDirectory.appendingPathComponent("MeshScaleControlPlane"),
            environment: baseEnvironment.merging([
                "MESHCALE_CONTROL_PLANE_ID": "cp-b",
                "MESHCALE_CONTROL_PLANE_REGION": "lab-b",
                "MESHCALE_CONTROL_PLANE_PORT": "9280",
                "MESHCALE_CONTROL_PLANE_PUBLIC_HOST": "127.0.0.1",
                "MESHCALE_CONTROL_PLANE_EMBEDDED_WORKER": "false",
            ]) { _, new in new }
        ),
        ClusterProcessSpec(
            serviceName: clusterServiceName(namespace: namespace, name: "worker-a1"),
            executableURL: binaryDirectory.appendingPathComponent("MeshScaleWorker"),
            environment: baseEnvironment.merging([
                "MESHCALE_WORKER_ID": "worker-a1",
                "MESHCALE_WORKER_TYPE": "general",
                "MESHCALE_WORKER_REGION": "lab-a",
                "MESHCALE_ATTACHED_CONTROL_PLANE_ID": "cp-a",
            ]) { _, new in new }
        ),
        ClusterProcessSpec(
            serviceName: clusterServiceName(namespace: namespace, name: "worker-a2"),
            executableURL: binaryDirectory.appendingPathComponent("MeshScaleWorker"),
            environment: baseEnvironment.merging([
                "MESHCALE_WORKER_ID": "worker-a2",
                "MESHCALE_WORKER_TYPE": "general",
                "MESHCALE_WORKER_REGION": "lab-a",
                "MESHCALE_ATTACHED_CONTROL_PLANE_ID": "cp-a",
            ]) { _, new in new }
        ),
        ClusterProcessSpec(
            serviceName: clusterServiceName(namespace: namespace, name: "worker-b1"),
            executableURL: binaryDirectory.appendingPathComponent("MeshScaleWorker"),
            environment: baseEnvironment.merging([
                "MESHCALE_WORKER_ID": "worker-b1",
                "MESHCALE_WORKER_TYPE": "general",
                "MESHCALE_WORKER_REGION": "lab-b",
                "MESHCALE_ATTACHED_CONTROL_PLANE_ID": "cp-b",
            ]) { _, new in new }
        ),
    ]
}

private func clusterServiceName(namespace: String, name: String) -> String {
    "cluster-\(namespace)-\(name)"
}

private func currentBinaryDirectory() throws -> URL {
    let executablePath = CommandLine.arguments[0]
    let executableURL = URL(fileURLWithPath: executablePath)
    let standardized = executableURL.standardizedFileURL
    let resolved = standardized.hasDirectoryPath ? standardized : standardized.deletingLastPathComponent()
    return resolved
}

private func resolveClusterFilePath(explicitPath: String?) throws -> String {
    if let explicitPath, !explicitPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return explicitPath
    }

    let environment = ProcessInfo.processInfo.environment
    for key in ["MESHCALE_FDB_CLUSTER_FILE", "MESH_SCALE_FDB_CLUSTER_FILE", "FOUNDATIONDB_CLUSTER_FILE", "FDB_CLUSTER_FILE"] {
        if let value = environment[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
    }

    let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let candidates = [
        currentDirectory.appendingPathComponent(".meshscale/foundationdb/shared/fdb.cluster"),
        currentDirectory.appendingPathComponent("../.meshscale/foundationdb/shared/fdb.cluster"),
    ]

    if let match = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
        return match.standardizedFileURL.path
    }

    throw ValidationError("No FoundationDB cluster file found. Pass --cluster-file or set MESHCALE_FDB_CLUSTER_FILE.")
}

private func spawnBackgroundProcess(_ spec: ClusterProcessSpec) throws {
    guard FileManager.default.fileExists(atPath: spec.executableURL.path) else {
        print("❌ \(spec.executableURL.lastPathComponent) not found at \(spec.executableURL.path)")
        throw ExitCode.failure
    }

    let process = Process()
    process.executableURL = spec.executableURL
    process.environment = ProcessInfo.processInfo.environment.merging(spec.environment) { _, new in new }

    let logFile = ConfigManager.shared.getLogFile(for: spec.serviceName)
    if !FileManager.default.fileExists(atPath: logFile.path) {
        _ = FileManager.default.createFile(atPath: logFile.path, contents: nil)
    }
    let handle = try FileHandle(forWritingTo: logFile)
    try handle.seekToEnd()
    process.standardOutput = handle
    process.standardError = handle

    try process.run()
    try ConfigManager.shared.savePid(process.processIdentifier, for: spec.serviceName)
}
