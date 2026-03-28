import Foundation
import MeshScaleStore

public struct SwiftProjectRuntimeResponse: Codable, Sendable {
    public let domain: String?
    public let desiredResources: [DesiredResourceSpec]
    public let alerts: [String]
    public let outputs: [RuntimeOutput]

    public init(domain: String?, desiredResources: [DesiredResourceSpec], alerts: [String], outputs: [RuntimeOutput]) {
        self.domain = domain
        self.desiredResources = desiredResources
        self.alerts = alerts
        self.outputs = outputs
    }
}

public struct SwiftProjectObservedState: Codable, Sendable {
    public let metrics: [String: ResourceMetrics]
    public let health: [String: ResourceHealth]

    public init(metrics: [String: ResourceMetrics], health: [String: ResourceHealth]) {
        self.metrics = metrics
        self.health = health
    }
}

private struct SwiftProjectRuntimeRequest: Codable {
    let command: String
    let observedState: SwiftProjectObservedState
}

public actor SwiftProjectRuntimeHost {
    private enum EntrypointMode {
        case main
        case tick
    }

    private let logger: Logger?
    private let packageRootURL: URL
    private let workspaceURL: URL
    private var currentSource: String?
    private var builtSource: String?
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?

    public init(logger: Logger? = nil) {
        self.logger = logger
        self.packageRootURL = Self.resolvePackageRoot()
        self.workspaceURL = Self.defaultWorkspaceURL()
    }

    public func loadSource(_ source: String) async throws {
        guard builtSource != source else {
            currentSource = source
            if process?.isRunning != true {
                try startProcess()
            }
            return
        }

        try stopProcess()
        try prepareWorkspace(for: source)
        try buildProgram()
        try startProcess()
        builtSource = source
        currentSource = source
        logger?.log("Swift project runtime is ready")
    }

    public func hasLoadedSource() -> Bool {
        currentSource != nil
    }

    public func tick(observedState: SwiftProjectObservedState) async throws -> SwiftProjectRuntimeResponse {
        guard currentSource != nil else {
            throw RuntimeHostError.noSourceLoaded
        }

        if process?.isRunning != true {
            try startProcess()
        }

        let request = SwiftProjectRuntimeRequest(command: "tick", observedState: observedState)
        let encoder = JSONEncoder()
        let payload = try encoder.encode(request)
        guard let line = String(data: payload, encoding: .utf8) else {
            throw RuntimeHostError.invalidResponse("Failed to encode runtime request")
        }

        guard let stdinPipe else {
            throw RuntimeHostError.processUnavailable
        }

        stdinPipe.fileHandleForWriting.write(Data((line + "\n").utf8))
        let responseLine = try readResponseLine()

        let decoder = JSONDecoder()
        return try decoder.decode(SwiftProjectRuntimeResponse.self, from: Data(responseLine.utf8))
    }

    public func stop() async {
        try? stopProcess()
    }

    private func prepareWorkspace(for source: String) throws {
        let sourcesURL = workspaceURL
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("MeshScaleDeployedApp", isDirectory: true)

        try FileManager.default.createDirectory(at: sourcesURL, withIntermediateDirectories: true)

        let packageDefinition = makePackageDefinition()

        try packageDefinition.write(
            to: workspaceURL.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let userProgram = """
        import Foundation
        import MeshScaleControlPlaneRuntime
        import MeshScaleStore

        \(source)
        """

        try userProgram.write(
            to: sourcesURL.appendingPathComponent("UserProgram.swift"),
            atomically: true,
            encoding: .utf8
        )

        try makeHostSource(for: source).write(
            to: sourcesURL.appendingPathComponent("main.swift"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func buildProgram() throws {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        let swiftExecutable = resolvedSwiftExecutable()
        process.currentDirectoryURL = workspaceURL
        if swiftExecutable.hasPrefix("/") {
            process.executableURL = URL(fileURLWithPath: swiftExecutable)
            process.arguments = ["build", "-c", "debug"]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [swiftExecutable, "build", "-c", "debug"]
        }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = mergedEnvironment()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            let errorOutput = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw RuntimeHostError.buildFailed((output + "\n" + errorOutput).trimmingCharacters(in: .whitespacesAndNewlines))
        }

        try installFoundationDBRuntimeIfAvailable()
    }

    private func startProcess() throws {
        let executableURL = try resolveBuiltExecutableURL()

        guard FileManager.default.fileExists(atPath: executableURL.path) else {
            throw RuntimeHostError.processUnavailable
        }

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        process.currentDirectoryURL = workspaceURL
        process.executableURL = executableURL
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.standardError
        process.environment = mergedEnvironment()

        try process.run()

        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
    }

    private func stopProcess() throws {
        if let process, process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }

        self.process = nil
        self.stdinPipe = nil
        self.stdoutPipe = nil
    }

    private func readResponseLine() throws -> String {
        guard let stdoutPipe else {
            throw RuntimeHostError.processUnavailable
        }

        let handle = stdoutPipe.fileHandleForReading
        var buffer = Data()

        while true {
            let chunk = handle.readData(ofLength: 1)
            guard !chunk.isEmpty else {
                throw RuntimeHostError.processUnavailable
            }

            if chunk == Data([0x0A]) {
                let line = String(decoding: buffer, as: UTF8.self)
                if line.hasPrefix("MESHSCALE_RESPONSE:") {
                    return String(line.dropFirst("MESHSCALE_RESPONSE:".count))
                }
                buffer.removeAll(keepingCapacity: true)
                continue
            }

            buffer.append(chunk)
        }
    }

    private func makeHostSource(for source: String) -> String {
        let entrypointMode: EntrypointMode = source.contains("func tick(") ? .tick : .main
        let hasInitialize = source.contains("func initialize(")

        let initializeCall = hasInitialize
            ? """
              var initializationAlerts: [String] = []
              if !didInitialize {
                  project.resetForEvaluation()
                  initialize(project: project)
                  initializationAlerts = project.drainAlerts()
                  didInitialize = true
              }
              """
            : """
              let initializationAlerts: [String] = []
              if !didInitialize {
                  didInitialize = true
              }
              """

        let tickCall: String
        switch entrypointMode {
        case .tick:
            tickCall = "tick(project: project)"
        case .main:
            tickCall = "main(project: project)"
        }

        return """
        import Foundation
        import MeshScaleControlPlaneRuntime
        import MeshScaleStore

        struct RuntimeRequest: Codable {
            let command: String
            let observedState: SwiftProjectObservedState
        }

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        let project = MeshScaleProject(store: InMemoryStore())
        var didInitialize = false

        while let line = readLine() {
            guard let data = line.data(using: .utf8),
                  let request = try? decoder.decode(RuntimeRequest.self, from: data)
            else {
                continue
            }

            switch request.command {
            case "tick":
                project.applyObservedState(
                    metrics: request.observedState.metrics,
                    health: request.observedState.health
                )
                \(initializeCall)
                project.resetForEvaluation()
                \(tickCall)

                let response = SwiftProjectRuntimeResponse(
                    domain: project.currentDomain().isEmpty ? nil : project.currentDomain(),
                    desiredResources: project.currentDesiredResources(),
                    alerts: initializationAlerts + project.drainAlerts(),
                    outputs: project.currentOutputs()
                )

                if let encoded = try? encoder.encode(response),
                   let text = String(data: encoded, encoding: .utf8) {
                    FileHandle.standardOutput.write(Data("MESHSCALE_RESPONSE:\\(text)\\n".utf8))
                }

            default:
                continue
            }
        }
        """
    }

    private static func resolvePackageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func defaultWorkspaceURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("meshscale", isDirectory: true)
            .appendingPathComponent("runtime-host", isDirectory: true)
    }

    private func resolveBuiltExecutableURL() throws -> URL {
        let candidates = [
            workspaceURL
                .appendingPathComponent(".build", isDirectory: true)
                .appendingPathComponent("debug", isDirectory: true)
                .appendingPathComponent("MeshScaleDeployedApp"),
            workspaceURL
                .appendingPathComponent(".build", isDirectory: true)
                .appendingPathComponent("arm64-apple-macosx", isDirectory: true)
                .appendingPathComponent("debug", isDirectory: true)
                .appendingPathComponent("MeshScaleDeployedApp"),
            workspaceURL
                .appendingPathComponent(".build", isDirectory: true)
                .appendingPathComponent("x86_64-unknown-linux-gnu", isDirectory: true)
                .appendingPathComponent("debug", isDirectory: true)
                .appendingPathComponent("MeshScaleDeployedApp"),
        ]

        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        throw RuntimeHostError.processUnavailable
    }

    private func installFoundationDBRuntimeIfAvailable() throws {
        let sourceURL = URL(fileURLWithPath: "/usr/local/lib/libfdb_c.dylib")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return
        }

        let destinations = [
            workspaceURL
                .appendingPathComponent(".build", isDirectory: true)
                .appendingPathComponent("debug", isDirectory: true)
                .appendingPathComponent("libfdb_c.dylib"),
            workspaceURL
                .appendingPathComponent(".build", isDirectory: true)
                .appendingPathComponent("arm64-apple-macosx", isDirectory: true)
                .appendingPathComponent("debug", isDirectory: true)
                .appendingPathComponent("libfdb_c.dylib"),
        ]

        for destination in destinations {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            try FileManager.default.copyItem(at: sourceURL, to: destination)
        }
    }

    private func mergedEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["DYLD_LIBRARY_PATH"] = [environment["DYLD_LIBRARY_PATH"], "/usr/local/lib"]
            .compactMap { $0 }
            .joined(separator: ":")
        environment["LD_LIBRARY_PATH"] = [environment["LD_LIBRARY_PATH"], "/usr/local/lib"]
            .compactMap { $0 }
            .joined(separator: ":")
        return environment
    }

    private func resolvedSwiftExecutable() -> String {
        let environment = ProcessInfo.processInfo.environment
        return environment["MESHCALE_SWIFT_EXECUTABLE"] ?? "swift"
    }

    private func makePackageDefinition() -> String {
        let platformBlock: String
        #if os(macOS)
        platformBlock = """
            platforms: [
                .macOS(.v14)
            ],
        """
        #else
        platformBlock = ""
        #endif

        let linkerSettingsBlock: String
        #if os(macOS)
        linkerSettingsBlock = """
                    linkerSettings: [
                        .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "/usr/local/lib"])
                    ]
        """
        #else
        linkerSettingsBlock = ""
        #endif

        return """
        // swift-tools-version: 6.2
        import PackageDescription

        let package = Package(
            name: "MeshScaleDeployedApp",
            \(platformBlock)
            dependencies: [
                .package(path: "\(packageRootURL.path)")
            ],
            targets: [
                .executableTarget(
                    name: "MeshScaleDeployedApp",
                    dependencies: [
                        .product(name: "MeshScaleControlPlaneRuntime", package: "meshscale-swift"),
                        .product(name: "MeshScaleStore", package: "meshscale-swift")
                    ],
                    swiftSettings: [
                        .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
                    ],
                    \(linkerSettingsBlock)
                )
            ]
        )
        """
    }
}

private enum RuntimeHostError: LocalizedError {
    case noSourceLoaded
    case processUnavailable
    case buildFailed(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .noSourceLoaded:
            return "No Swift source has been loaded into the runtime host."
        case .processUnavailable:
            return "The deployed Swift runtime process is unavailable."
        case .buildFailed(let output):
            return output.isEmpty ? "Failed to build deployed Swift source." : output
        case .invalidResponse(let message):
            return message
        }
    }
}
