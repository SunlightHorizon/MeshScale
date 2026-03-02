import Foundation
import ArgumentParser
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
        
        func run() throws {
            let workerId = id ?? UUID().uuidString
            print("Starting MeshScale Worker (ID: \(workerId))...")
            let worker = MeshScaleWorkerRuntime.Worker(id: workerId)
            worker.start()
            RunLoop.main.run()
        }
    }
}
