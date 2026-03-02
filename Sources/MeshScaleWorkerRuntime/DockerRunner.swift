import Foundation

/// Runs Docker CLI commands to create, stop, restart, and remove containers.
/// Container names are sanitized to match Docker's allowed set: [a-zA-Z0-9_.-]
public protocol DockerRunner: Sendable {
    func run(
        containerId: String,
        image: String,
        env: [String: String]?,
        ports: [Int]?,
        volumes: [VolumeMount]?
    ) -> Bool
    func stop(containerId: String) -> Bool
    func restart(containerId: String) -> Bool
    func remove(containerId: String) -> Bool
    func isRunning(containerId: String) -> Bool
}

/// Default implementation using the `docker` CLI.
public final class CLIDockerRunner: DockerRunner {
    private let dockerPath: String
    private let timeout: TimeInterval

    public init(dockerPath: String = "docker", timeout: TimeInterval = 60) {
        self.dockerPath = dockerPath
        self.timeout = timeout
    }

    public func run(
        containerId: String,
        image: String,
        env: [String: String]? = nil,
        ports: [Int]? = nil,
        volumes: [VolumeMount]? = nil
    ) -> Bool {
        let name = sanitizeName(containerId)
        var args: [String] = [
            "run", "-d", "--name", name
        ]
        for (key, value) in env ?? [:] {
            args.append(contentsOf: ["-e", "\(key)=\(value)"])
        }
        for p in ports ?? [] {
            args.append(contentsOf: ["-p", "\(p):\(p)"])
        }
        for v in volumes ?? [] {
            args.append(contentsOf: ["-v", "\(v.name):\(v.mountPath)"])
        }
        args.append(image)
        return execute(args) == 0
    }

    public func stop(containerId: String) -> Bool {
        execute(["stop", sanitizeName(containerId)]) == 0
    }

    public func restart(containerId: String) -> Bool {
        execute(["restart", sanitizeName(containerId)]) == 0
    }

    public func remove(containerId: String) -> Bool {
        execute(["rm", "-f", sanitizeName(containerId)]) == 0
    }

    public func isRunning(containerId: String) -> Bool {
        let name = sanitizeName(containerId)
        let out = executeWithOutput(["ps", "-q", "--filter", "name=^\(name)$"])
        return !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sanitizeName(_ id: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-")
        return id.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
    }

    private func execute(_ args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: dockerPath)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    private func executeWithOutput(_ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: dockerPath)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
