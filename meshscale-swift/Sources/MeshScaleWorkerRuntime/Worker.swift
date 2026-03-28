import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import MeshScaleStore

public final class Worker: @unchecked Sendable {
    private let config: WorkerConfig
    private var netBirdIP: String
    private var containers: [String: ContainerStatus] = [:]
    private var lastCommandAttemptAt: [String: Date] = [:]
    private var failedStartAttempts: [String: Int] = [:]
    private var commandTask: Task<Void, Never>?
    private let pollLock = NSLock()
    private var isPollingCommands = false
    private let store: any MeshScaleStoreClient
    private let stateStore: MeshScaleStateStore
    private let docker: any DockerRunner
    private let netBird: NetBirdClient
    private let managedFileBundles: [String: [ManagedFile]]
    
    public init(
        id: String = UUID().uuidString,
        type: WorkerType = .general,
        region: String = "us-east-1",
        controlPlaneID: String? = nil,
        controlPlaneAPIURL: String? = nil,
        managedFileBundles: [String: [ManagedFile]] = [:],
        store: any MeshScaleStoreClient = MeshScaleStoreFactory.makeStore(),
        docker: any DockerRunner = CLIDockerRunner(),
        netBird: NetBirdClient = NetBirdClient(
            configuration: .fromEnvironment(role: .worker),
            logger: { print($0) }
        )
    ) {
        self.config = WorkerConfig(
            id: id,
            type: type,
            region: region,
            controlPlaneID: controlPlaneID,
            controlPlaneAPIURL: controlPlaneAPIURL
        )
        self.netBirdIP = ""
        self.store = store
        self.stateStore = MeshScaleStateStore(client: store)
        self.docker = docker
        self.netBird = netBird
        self.managedFileBundles = managedFileBundles
    }
    
    public func start() {
        print("Worker initialized with ID: \(config.id)")
        print("Type: \(config.type.rawValue)")

        do {
            let netBirdStatus = try netBird.ensureConnected()
            if netBirdStatus.enabled {
                if let ipv4 = netBirdStatus.ipv4 {
                    netBirdIP = ipv4
                    print("NetBird connected on \(ipv4)")
                } else if netBirdStatus.required {
                    print("❌ NetBird is required but no overlay IP is available.")
                    return
                }
            }
        } catch {
            print("❌ Failed to initialize NetBird: \(error.localizedDescription)")
            return
        }
        
        print("Connecting to control plane / store...")
        Task {
            let record = WorkerRecord(
                id: config.id,
                type: config.type,
                region: config.region,
                netbirdIP: netBirdIP,
                attachedControlPlaneID: config.controlPlaneID,
                lastSeenAt: Date(),
                status: "online"
            )
            try? await stateStore.putWorkerRecord(record)
        }
        startCommandListener()
    }
    
    private func startCommandListener() {
        print("Listening for commands...")

        commandTask?.cancel()
        commandTask = Task.detached { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.pollCommands()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
    
    private func pollCommands() async {
        guard beginPollCycle() else {
            return
        }
        defer { endPollCycle() }

        let workerStatus: String
        if docker.isAvailable() {
            workerStatus = "online"
        } else if let detail = docker.explainUnavailable() {
            workerStatus = "degraded:no-docker"
            print("Container runtime unavailable: \(detail)")
        } else {
            workerStatus = "degraded:no-docker"
        }
        await updateWorkerRecord(status: workerStatus)

        guard let desired = try? await stateStore.listDesiredCommands(workerId: config.id) else {
            await reportHealth()
            return
        }

        await reconcileDesiredContainers(desired)
        await reportHealth()
    }
    
    private func reportHealth() async {
        let runningCount = containers.values.filter { $0.status == "running" }.count
        let health = WorkerHealthReport(
            workerId: config.id,
            runningContainers: runningCount,
            totalContainers: containers.count,
            reportedAt: Date()
        )
        try? await stateStore.putWorkerHealth(health)
        for status in containers.values {
            try? await stateStore.putContainerStatus(status, workerId: config.id)
        }
    }
    
    public func executeCommand(_ command: ContainerCommand) async {
        print("Executing command: \(command.action.rawValue) for container \(command.id)")
        
        switch command.action {
        case .start:
            await startContainer(command)
        case .stop:
            stopContainer(command.id)
        case .restart:
            restartContainer(command.id)
        case .remove:
            removeContainer(command.id)
        }
    }

    private func reconcileDesiredContainers(_ desiredEntries: [String: ContainerCommand]) async {
        let desiredCommands = Dictionary(
            uniqueKeysWithValues: desiredEntries.map { key, command in
                (
                    String(key.dropFirst(MeshScaleStoreKeySpace.workerDesiredPrefix(config.id).count)),
                    command
                )
            }
        )

        let persistedStatuses = (try? await stateStore.listContainerStatuses(workerId: config.id)) ?? [:]
        let persistedContainerIds = Set(
            persistedStatuses.values.map(\.id)
        )

        for (containerId, command) in desiredCommands.sorted(by: { $0.key < $1.key }) {
            let isRunning = docker.isRunning(containerId: containerId)
            let persistedStatus = persistedStatuses[
                MeshScaleStoreKeySpace.workerContainer(config.id, containerId: containerId)
            ]
            let desiredVolumes = await resolvedVolumes(for: command)
            let matchesDesiredState = if let image = command.image {
                docker.matchesDesiredState(
                    containerId: containerId,
                    image: image,
                    env: command.env,
                    ports: command.ports,
                    volumes: desiredVolumes,
                    args: command.args
                )
            } else {
                true
            }

            if isRunning && matchesDesiredState {
                let current = containers[containerId] ?? persistedStatus
                containers[containerId] = ContainerStatus(
                    id: containerId,
                    status: "running",
                    cpu: current?.cpu ?? 0,
                    memory: current?.memory ?? 0,
                    uptime: current?.uptime ?? 0,
                    image: current?.image ?? command.image,
                    lastError: nil,
                    lastUpdatedAt: Date(),
                    retryCount: current?.retryCount ?? 0
                )
                lastCommandAttemptAt.removeValue(forKey: containerId)
                continue
            }

            if isRunning && !matchesDesiredState {
                print("Detected config drift for container: \(containerId)")
                removeContainer(containerId)
            }

            switch command.action {
            case .start:
                if shouldAttempt(commandFor: containerId) {
                    await executeCommand(command)
                }
            case .stop, .restart, .remove:
                if shouldAttempt(commandFor: containerId) {
                    await executeCommand(command)
                }
            }
        }

        let staleContainerIds = Set(containers.keys)
            .union(persistedContainerIds)
            .subtracting(desiredCommands.keys)
        for containerId in staleContainerIds.sorted() {
            removeContainer(containerId)
        }
    }

    private func updateWorkerRecord(status: String) async {
        let record = WorkerRecord(
            id: config.id,
            type: config.type,
            region: config.region,
            netbirdIP: netBirdIP,
            attachedControlPlaneID: config.controlPlaneID,
            lastSeenAt: Date(),
            status: status
        )
        try? await stateStore.putWorkerRecord(record)
    }

    private func shouldAttempt(commandFor containerId: String) -> Bool {
        let now = Date()
        let failureCount = failedStartAttempts[containerId] ?? 0
        let retryInterval = min(Double(max(failureCount, 1)) * 10, 60)
        if let lastAttemptAt = lastCommandAttemptAt[containerId],
           now.timeIntervalSince(lastAttemptAt) < retryInterval {
            return false
        }

        lastCommandAttemptAt[containerId] = now
        return true
    }

    private func beginPollCycle() -> Bool {
        pollLock.lock()
        defer { pollLock.unlock() }

        if isPollingCommands {
            return false
        }

        isPollingCommands = true
        return true
    }

    private func endPollCycle() {
        pollLock.lock()
        isPollingCommands = false
        pollLock.unlock()
    }
    
    private func startContainer(_ command: ContainerCommand) async {
        guard let image = command.image else {
            print("❌ No image specified for container \(command.id)")
            recordFailure(
                containerId: command.id,
                image: command.image,
                message: "No image specified in desired command"
            )
            return
        }
        print("Starting container: \(command.id) (\(image))")
        // Clear any stopped or partially created container so `docker run --name`
        // can recreate the desired instance cleanly.
        _ = docker.remove(containerId: command.id)
        let volumes = await resolvedVolumes(for: command)
        let ok = docker.run(
            containerId: command.id,
            image: image,
            env: command.env,
            ports: command.ports,
            volumes: volumes,
            args: command.args
        )
        if ok {
            containers[command.id] = ContainerStatus(
                id: command.id,
                status: "running",
                cpu: 0,
                memory: 0,
                uptime: 0,
                image: image,
                lastError: nil,
                lastUpdatedAt: Date(),
                retryCount: failedStartAttempts[command.id] ?? 0
            )
            lastCommandAttemptAt.removeValue(forKey: command.id)
            failedStartAttempts.removeValue(forKey: command.id)
            print("✅ Container \(command.id) started")
            Task { try? await stateStore.putContainerStatus(containers[command.id]!, workerId: config.id) }
        } else {
            print("❌ Docker run failed for \(command.id)")
            recordFailure(
                containerId: command.id,
                image: image,
                message: docker.explainUnavailable() ?? (docker.isAvailable() ? "Docker run failed" : "Docker daemon is unavailable")
            )
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
                uptime: current.uptime,
                image: current.image,
                lastError: nil,
                lastUpdatedAt: Date(),
                retryCount: current.retryCount
            )
            lastCommandAttemptAt.removeValue(forKey: id)
            print("✅ Container \(id) stopped")
            Task { try? await stateStore.putContainerStatus(containers[id]!, workerId: config.id) }
        } else if !ok {
            print("❌ Docker stop failed for \(id)")
        }
    }
    
    private func restartContainer(_ id: String) {
        print("Restarting container: \(id)")
        let ok = docker.restart(containerId: id)
        if ok {
            if let current = containers[id] {
                containers[id] = ContainerStatus(
                    id: current.id,
                    status: "running",
                    cpu: current.cpu,
                    memory: current.memory,
                    uptime: current.uptime,
                    image: current.image,
                    lastError: nil,
                    lastUpdatedAt: Date(),
                    retryCount: current.retryCount
                )
                Task { try? await stateStore.putContainerStatus(containers[id]!, workerId: config.id) }
            }
            lastCommandAttemptAt.removeValue(forKey: id)
            print("✅ Container \(id) restarted")
        } else {
            print("❌ Docker restart failed for \(id)")
        }
    }
    
    private func removeContainer(_ id: String) {
        print("Removing container: \(id)")
        _ = docker.remove(containerId: id)
        cleanupStaleContainerState(id)
        print("✅ Container \(id) removed")
    }

    private func cleanupStaleContainerState(_ id: String) {
        containers.removeValue(forKey: id)
        lastCommandAttemptAt.removeValue(forKey: id)
        failedStartAttempts.removeValue(forKey: id)
        Task { try? await store.delete(MeshScaleStoreKeySpace.workerContainer(config.id, containerId: id)) }
    }

    private func recordFailure(containerId: String, image: String?, message: String) {
        let retryCount = (failedStartAttempts[containerId] ?? 0) + 1
        failedStartAttempts[containerId] = retryCount

        let previous = containers[containerId]
        containers[containerId] = ContainerStatus(
            id: containerId,
            status: "failed",
            cpu: previous?.cpu ?? 0,
            memory: previous?.memory ?? 0,
            uptime: previous?.uptime ?? 0,
            image: image ?? previous?.image,
            lastError: message,
            lastUpdatedAt: Date(),
            retryCount: retryCount
        )

        Task { try? await stateStore.putContainerStatus(containers[containerId]!, workerId: config.id) }
    }

    private func resolvedVolumes(for command: ContainerCommand) async -> [VolumeMount]? {
        let managedFiles = await resolvedManagedFiles(for: command)
        cleanupStaleManagedFiles(for: command.id, keeping: managedFiles)
        let fileVolumes = managedFiles.compactMap { managedFile in
            writeManagedFile(managedFile, for: command.id)
        }
        let combined = (command.volumes ?? []) + fileVolumes
        return combined.isEmpty ? nil : combined
    }

    private func resolvedManagedFiles(for command: ContainerCommand) async -> [ManagedFile] {
        var files = command.files ?? []

        guard let bundleID = command.managedFileBundleID else {
            return files
        }

        if let localBundle = managedFileBundles[bundleID] {
            files.append(contentsOf: localBundle)
            return files.sorted {
                ($0.relativePath, $0.mountPath) < ($1.relativePath, $1.mountPath)
            }
        }

        do {
            let bundledFiles = try await fetchManagedFileBundle(bundleID: bundleID)
            files.append(contentsOf: bundledFiles)
        } catch {
            print("❌ Failed to fetch managed file bundle '\(bundleID)' for \(command.id): \(error.localizedDescription)")
        }

        return files.sorted {
            ($0.relativePath, $0.mountPath) < ($1.relativePath, $1.mountPath)
        }
    }

    private func fetchManagedFileBundle(bundleID: String) async throws -> [ManagedFile] {
        let controlPlane = try await resolvedControlPlaneRecordForBundleFetch()
        let url = try managedFileBundleURL(bundleID: bundleID, controlPlane: controlPlane)
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "MeshScaleWorkerRuntime",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Bundle response was not an HTTP response."]
            )
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "MeshScaleWorkerRuntime",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Bundle request failed with status \(httpResponse.statusCode)."]
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ManagedFile].self, from: data)
    }

    private func resolvedControlPlaneRecordForBundleFetch() async throws -> ControlPlaneRecord {
        if let directAPIURL = config.controlPlaneAPIURL, !directAPIURL.isEmpty {
            return ControlPlaneRecord(
                id: config.controlPlaneID ?? "control-plane",
                region: config.region,
                apiURL: directAPIURL,
                netbirdIP: netBirdIP,
                lastSeenAt: Date(),
                status: "direct"
            )
        }

        if let controlPlaneID = config.controlPlaneID,
           let record = try await stateStore.getControlPlaneRecord(controlPlaneId: controlPlaneID) {
            return record
        }

        let controlPlanes = try await stateStore.listControlPlanes()
            .filter { Date().timeIntervalSince($0.lastSeenAt) < 30 }
            .sorted { $0.id < $1.id }
        if let controlPlane = controlPlanes.first {
            return controlPlane
        }

        throw NSError(
            domain: "MeshScaleWorkerRuntime",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "No active control plane record is available for bundle fetch."]
        )
    }

    private func managedFileBundleURL(bundleID: String, controlPlane: ControlPlaneRecord) throws -> URL {
        let base = controlPlane.apiURL.hasSuffix("/") ? String(controlPlane.apiURL.dropLast()) : controlPlane.apiURL
        guard var components = URLComponents(string: base) else {
            throw NSError(
                domain: "MeshScaleWorkerRuntime",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Control plane API URL is invalid: \(controlPlane.apiURL)"]
            )
        }

        // NetBird self-addresses on the same host can hang on macOS, so the embedded
        // worker rewrites its own control-plane fetches to loopback while preserving
        // the same HTTP server/port.
        if let host = components.host,
           !netBirdIP.isEmpty,
           host == netBirdIP {
            components.host = "127.0.0.1"
        }

        components.path = "/api/v1/system-apps/\(bundleID)/files"
        guard let url = components.url else {
            throw NSError(
                domain: "MeshScaleWorkerRuntime",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Control plane bundle URL is invalid for base \(controlPlane.apiURL)"]
            )
        }
        return url
    }

    private func writeManagedFile(_ file: ManagedFile, for containerId: String) -> VolumeMount? {
        let baseURL = generatedFilesDirectory(for: containerId)
        let destinationURL = baseURL.appendingPathComponent(file.relativePath)

        do {
            try FileManager.default.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data: Data
            switch file.encoding {
            case .utf8:
                data = Data(file.content.utf8)
            case .base64:
                guard let decoded = Data(base64Encoded: file.content) else {
                    throw NSError(
                        domain: "MeshScaleWorkerRuntime",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Managed file content is not valid base64."]
                    )
                }
                data = decoded
            }
            try data.write(to: destinationURL, options: .atomic)
            return VolumeMount(name: destinationURL.path, mountPath: file.mountPath)
        } catch {
            print("❌ Failed to materialize managed file for \(containerId): \(error.localizedDescription)")
            return nil
        }
    }

    private func cleanupStaleManagedFiles(for containerId: String, keeping files: [ManagedFile]) {
        let fileManager = FileManager.default
        let baseURL = generatedFilesDirectory(for: containerId)
        guard fileManager.fileExists(atPath: baseURL.path),
              let enumerator = fileManager.enumerator(
                at: baseURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              )
        else {
            return
        }

        let keepRelativePaths = Set(files.map(\.relativePath))
        var staleFileURLs: [URL] = []

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true
            else {
                continue
            }

            let relativePath = fileURL.path.replacingOccurrences(
                of: baseURL.path + "/",
                with: ""
            )
            if !keepRelativePaths.contains(relativePath) {
                staleFileURLs.append(fileURL)
            }
        }

        for fileURL in staleFileURLs {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private func generatedFilesDirectory(for containerId: String) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".config/meshscale/generated-files", isDirectory: true)
            .appendingPathComponent(config.id, isDirectory: true)
            .appendingPathComponent(containerId, isDirectory: true)
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
