import Foundation
import MeshScaleStore

/// Runs Docker CLI commands to create, stop, restart, and remove containers.
/// Container names are sanitized to match Docker's allowed set: [a-zA-Z0-9_.-]
public protocol DockerRunner: Sendable {
    func run(
        containerId: String,
        image: String,
        env: [String: String]?,
        ports: [PortBinding]?,
        volumes: [VolumeMount]?,
        args: [String]?
    ) -> Bool
    func matchesDesiredState(
        containerId: String,
        image: String,
        env: [String: String]?,
        ports: [PortBinding]?,
        volumes: [VolumeMount]?,
        args: [String]?
    ) -> Bool
    func stop(containerId: String) -> Bool
    func restart(containerId: String) -> Bool
    func remove(containerId: String) -> Bool
    func isRunning(containerId: String) -> Bool
    func isAvailable() -> Bool
    func explainUnavailable() -> String?
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
        ports: [PortBinding]? = nil,
        volumes: [VolumeMount]? = nil,
        args commandArgs: [String]? = nil
    ) -> Bool {
        let name = sanitizeName(containerId)
        var args: [String] = [
            "run", "-d", "--name", name
        ]
        for (key, value) in env ?? [:] {
            args.append(contentsOf: ["-e", "\(key)=\(value)"])
        }
        for binding in ports ?? [] {
            let suffix = binding.transport == .tcp ? "" : "/\(binding.transport.rawValue)"
            args.append(
                contentsOf: [
                    "-p",
                    "\(binding.hostPort):\(binding.containerPort)\(suffix)",
                ]
            )
        }
        for v in volumes ?? [] {
            args.append(contentsOf: ["-v", "\(v.name):\(v.mountPath)"])
        }
        args.append(image)
        args.append(contentsOf: commandArgs ?? [])
        return execute(args) == 0
    }

    public func stop(containerId: String) -> Bool {
        execute(["stop", sanitizeName(containerId)]) == 0
    }

    public func matchesDesiredState(
        containerId: String,
        image: String,
        env: [String: String]? = nil,
        ports: [PortBinding]? = nil,
        volumes: [VolumeMount]? = nil,
        args: [String]? = nil
    ) -> Bool {
        let name = sanitizeName(containerId)
        let result = executeCapturingOutput(["inspect", name])
        guard result.status == 0,
              let data = result.stdout.data(using: .utf8),
              let objects = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let object = objects.first
        else {
            return false
        }

        guard let config = object["Config"] as? [String: Any],
              let currentImage = config["Image"] as? String,
              currentImage == image
        else {
            return false
        }

        let currentEnv = Set((config["Env"] as? [String]) ?? [])
        let desiredEnv = Set((env ?? [:]).map { "\($0.key)=\($0.value)" })
        if !desiredEnv.isSubset(of: currentEnv) {
            return false
        }

        let hostConfig = object["HostConfig"] as? [String: Any]
        let currentBindings = (hostConfig?["PortBindings"] as? [String: Any]) ?? [:]
        let desiredPorts = ports ?? []
        let currentPortKeys = Set(currentBindings.keys)
        let desiredPortKeys = Set(
            desiredPorts.map { "\($0.containerPort)/\($0.transport.rawValue)" }
        )
        if currentPortKeys != desiredPortKeys {
            return false
        }

        for binding in desiredPorts {
            let key = "\(binding.containerPort)/\(binding.transport.rawValue)"
            guard let bindings = currentBindings[key] as? [[String: Any]],
                  bindings.count == 1,
                  let hostPort = bindings.first?["HostPort"] as? String,
                  hostPort == String(binding.hostPort)
            else {
                return false
            }
        }

        let desiredVolumes = volumes ?? []
        if !desiredVolumes.isEmpty {
            let currentMounts = object["Mounts"] as? [[String: Any]] ?? []
            let desiredMounts = Set(desiredVolumes.map { "\($0.name):\($0.mountPath)" })
            let actualMounts = Set(currentMounts.compactMap { mount -> String? in
                guard let source = (mount["Name"] as? String) ?? (mount["Source"] as? String),
                      let destination = mount["Destination"] as? String
                else {
                    return nil
                }
                return "\(source):\(destination)"
            })
            if desiredMounts != actualMounts {
                return false
            }
        }

        let desiredArgs = args ?? []
        let currentArgs = object["Args"] as? [String] ?? []
        if !desiredArgs.isEmpty && currentArgs != desiredArgs {
            return false
        }

        return true
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

    public func isAvailable() -> Bool {
        execute(["version", "--format", "{{.Server.Version}}"]) == 0
    }

    public func explainUnavailable() -> String? {
        let result = executeCapturingOutput(["version"])
        guard result.status != 0 else {
            return nil
        }

        let message = [result.stdout, result.stderr]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "docker command failed" : message
    }

    private func sanitizeName(_ id: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-")
        return id.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
    }

    private func execute(_ args: [String]) -> Int32 {
        let process = Process()
        configure(process: process, args: args)
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
        let result = executeCapturingOutput(args)
        return result.stdout
    }

    private func executeCapturingOutput(_ args: [String]) -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        configure(process: process, args: args)
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        do {
            try process.run()
            process.waitUntilExit()
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            return (
                process.terminationStatus,
                String(data: stdoutData, encoding: .utf8) ?? "",
                String(data: stderrData, encoding: .utf8) ?? ""
            )
        } catch {
            return (-1, "", error.localizedDescription)
        }
    }

    private func configure(process: Process, args: [String]) {
        if dockerPath.contains("/") {
            process.executableURL = URL(fileURLWithPath: dockerPath)
            process.arguments = args
            return
        }

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [dockerPath] + args
    }
}
