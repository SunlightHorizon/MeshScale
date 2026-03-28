import Foundation
import ArgumentParser
import MeshScaleStore
import MeshScaleWorkerRuntime

extension MeshScaleCLI {
    struct Worker: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "worker",
            abstract: "Manage MeshScale worker nodes",
            subcommands: [Start.self]
        )
    }
}

extension MeshScaleCLI.Worker {
    struct Start: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "start",
            abstract: "Start a MeshScale worker node"
        )
        
        @Option(name: .shortAndLong, help: "Worker ID")
        var id: String?

        @Option(name: .long, help: "Worker type (general, databaseHeavy, compute)")
        var type: String = "general"

        @Option(name: .long, help: "Worker region")
        var region: String = "us-east-1"

        @Option(name: .long, help: "Attached control-plane ID for topology and affinity reporting")
        var controlPlaneId: String?

        @Option(name: .long, help: "Optional store namespace for isolated clusters")
        var namespace: String?

        @Flag(name: .long, help: "Use locally built binaries instead of an installed toolchain. Intended for repository development only.")
        var allowLocalBuild: Bool = false
        
        func run() throws {
            let workerId = id ?? UUID().uuidString
            let workerType = MeshScaleStore.WorkerType(rawValue: type) ?? .general

            let resolvedExecutable: ResolvedToolchainExecutable
            do {
                resolvedExecutable = try ToolchainManager.shared.resolveExecutable(
                    for: .worker,
                    allowLocalBuild: allowLocalBuild
                )
            } catch {
                print("❌ \(error.localizedDescription)")
                if !allowLocalBuild {
                    print("   Run 'meshscale install' to download the worker toolchain.")
                    print("   Repository development can opt into local binaries with '--allow-local-build'.")
                }
                throw ExitCode.failure
            }
            do {
                try SetupManager.shared.assertReady(for: .worker)
            } catch {
                print("❌ \(error.localizedDescription)")
                print("   Run 'meshscale setup --role worker' before starting a worker.")
                throw ExitCode.failure
            }

            print("Starting MeshScale Worker (ID: \(workerId)) from \(resolvedExecutable.source)...")

            var environment = ProcessInfo.processInfo.environment
                .merging(SetupManager.shared.environment(for: .worker)) { _, new in new }
                .merging(resolvedExecutable.environment) { _, new in new }
            environment["MESHCALE_WORKER_ID"] = workerId
            environment["MESHCALE_WORKER_TYPE"] = workerType.rawValue
            environment["MESHCALE_WORKER_REGION"] = region
            if let controlPlaneId {
                environment["MESHCALE_ATTACHED_CONTROL_PLANE_ID"] = controlPlaneId
            }
            if let namespace, !namespace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                environment["MESHCALE_STORE_NAMESPACE"] = namespace
            }

            let process = Process()
            process.executableURL = resolvedExecutable.url
            process.environment = environment
            process.standardOutput = FileHandle.standardOutput
            process.standardError = FileHandle.standardError

            try process.run()
            process.waitUntilExit()
        }
    }
}
