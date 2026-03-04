import Foundation
import MeshScaleStore

public final class Worker: @unchecked Sendable {
    private let config: WorkerConfig
    private var containers: [String: ContainerStatus] = [:]
    private var commandTimer: Timer?
    private let store: any MeshScaleStoreClient
    private let docker: any DockerRunner
    
    public init(
        id: String = UUID().uuidString,
        type: WorkerType = .general,
        store: any MeshScaleStoreClient = FoundationDBStore(),
        docker: any DockerRunner = CLIDockerRunner()
    ) {
        self.config = WorkerConfig(id: id, type: type)
        self.store = store
        self.docker = docker
    }
    
    public func start() {
        print("Worker initialized with ID: \(config.id)")
        print("Type: \(config.type.rawValue)")
        
        print("Connecting to control plane / store (FoundationDB)...")
        Task {
            let value = "\(config.type.rawValue)|started"
            try? await store.set(Data(value.utf8), for: "workers/\(config.id)")
        }
        startCommandListener()
    }
    
    private func startCommandListener() {
        print("Listening for commands...")
        
        commandTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { await self?.pollCommands() }
        }
    }
    
    private func pollCommands() async {
        _ = try? await store.get("workers/\(config.id)/commands")
        await reportHealth()
    }
    
    private func reportHealth() async {
        let runningCount = containers.values.filter { $0.status == "running" }.count
        let payload = "running=\(runningCount),total=\(containers.count)"
        try? await store.set(Data(payload.utf8), for: "workers/\(config.id)/health")
    }
    
    public func executeCommand(_ command: ContainerCommand) {
        print("Executing command: \(command.action.rawValue) for container \(command.id)")
        
        switch command.action {
        case .start:
            startContainer(command)
        case .stop:
            stopContainer(command.id)
        case .restart:
            restartContainer(command.id)
        case .remove:
            removeContainer(command.id)
        }
    }
    
    private func startContainer(_ command: ContainerCommand) {
        guard let image = command.image else {
            print("❌ No image specified for container \(command.id)")
            return
        }
        print("Starting container: \(command.id) (\(image))")
        let ok = docker.run(
            containerId: command.id,
            image: image,
            env: command.env,
            ports: command.ports,
            volumes: command.volumes
        )
        if ok {
            containers[command.id] = ContainerStatus(
                id: command.id,
                status: "running",
                cpu: 0,
                memory: 0,
                uptime: 0
            )
            print("✅ Container \(command.id) started")
        } else {
            print("❌ Docker run failed for \(command.id)")
        }
    }
    
    private func stopContainer(_ id: String) {
        print("Stopping container: \(id)")
        let ok = docker.stop(containerId: id)
        if ok, let current = containers[id] {
            containers[id] = ContainerStatus(
                id: current.id,
                status: "stopped",
                cpu: current.cpu,
                memory: current.memory,
                uptime: current.uptime
            )
            print("✅ Container \(id) stopped")
        } else if !ok {
            print("❌ Docker stop failed for \(id)")
        }
    }
    
    private func restartContainer(_ id: String) {
        print("Restarting container: \(id)")
        let ok = docker.restart(containerId: id)
        if ok {
            print("✅ Container \(id) restarted")
        } else {
            print("❌ Docker restart failed for \(id)")
        }
    }
    
    private func removeContainer(_ id: String) {
        print("Removing container: \(id)")
        _ = docker.remove(containerId: id)
        containers.removeValue(forKey: id)
        print("✅ Container \(id) removed")
    }
}

public struct WorkerTask {
    public let id: String
    public let payload: Data
    
    public init(id: String, payload: Data) {
        self.id = id
        self.payload = payload
    }
}
