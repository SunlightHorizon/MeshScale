import Foundation

public final class Worker: @unchecked Sendable {
    private let config: WorkerConfig
    private var containers: [String: ContainerStatus] = [:]
    private var commandTimer: Timer?
    
    public init(id: String = UUID().uuidString, type: WorkerType = .general) {
        self.config = WorkerConfig(id: id, type: type)
    }
    
    public func start() {
        print("Worker initialized with ID: \(config.id)")
        print("Type: \(config.type.rawValue)")
        
        print("Connecting to control plane / store (FoundationDB in future)...")
        // TODO: Register worker in FoundationDB-backed store
        startCommandListener()
    }
    
    private func startCommandListener() {
        print("Listening for commands...")
        
        commandTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { await self?.pollCommands() }
        }
    }
    
    private func pollCommands() async {
        // TODO: Load pending commands from FoundationDB-backed store
        await reportHealth()
    }
    
    private func reportHealth() async {
        // TODO: Persist worker + container health in FoundationDB-backed store
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
        guard let image = command.image else { return }
        
        print("Starting container: \(command.id)")
        print("Image: \(image)")
        
        // TODO: Execute docker run command
        // docker run -d --name \(command.id) \(image)
        
        containers[command.id] = ContainerStatus(
            id: command.id,
            status: "running",
            cpu: 0,
            memory: 0,
            uptime: 0
        )
    }
    
    private func stopContainer(_ id: String) {
        print("Stopping container: \(id)")
        // TODO: Execute docker stop
        if let current = containers[id] {
            containers[id] = ContainerStatus(
                id: current.id,
                status: "stopped",
                cpu: current.cpu,
                memory: current.memory,
                uptime: current.uptime
            )
        }
    }
    
    private func restartContainer(_ id: String) {
        print("Restarting container: \(id)")
        // TODO: Execute docker restart
    }
    
    private func removeContainer(_ id: String) {
        print("Removing container: \(id)")
        // TODO: Execute docker rm
        containers.removeValue(forKey: id)
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
