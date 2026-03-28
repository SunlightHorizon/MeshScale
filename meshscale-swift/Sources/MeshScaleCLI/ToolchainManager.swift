import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum MeshScaleToolchainRole: String, CaseIterable, Codable {
    case controlPlane = "controlplane"
    case worker = "worker"

    var displayName: String {
        switch self {
        case .controlPlane:
            return "control plane"
        case .worker:
            return "worker"
        }
    }

    var executableName: String {
        #if os(Windows)
        switch self {
        case .controlPlane:
            return "MeshScaleControlPlane.exe"
        case .worker:
            return "MeshScaleWorker.exe"
        }
        #else
        switch self {
        case .controlPlane:
            return "MeshScaleControlPlane"
        case .worker:
            return "MeshScaleWorker"
        }
        #endif
    }

    static func parse(_ rawValue: String) throws -> MeshScaleToolchainRole {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")

        switch normalized {
        case "controlplane", "control":
            return .controlPlane
        case "worker":
            return .worker
        default:
            throw ToolchainManagerError.invalidRole(rawValue)
        }
    }
}

struct MeshScaleToolchainSelection: Codable {
    let version: String
    let updatedAt: Date
}

struct MeshScaleToolchainManifest: Codable {
    let schemaVersion: Int
    let latestVersion: String
    let generatedAt: Date?
    let artifacts: [MeshScaleToolchainArtifact]
}

struct MeshScaleToolchainArtifact: Codable {
    let version: String
    let role: String
    let platform: String
    let arch: String
    let url: String
    let sha256: String?
    let executables: [String]?
    let component: String?
    let installSubpath: String?
}

struct ResolvedToolchainExecutable {
    let url: URL
    let environment: [String: String]
    let source: String
}

enum ToolchainManagerError: LocalizedError {
    case invalidRole(String)
    case invalidManifestURL(String)
    case manifestDownloadFailed(String)
    case manifestDecodeFailed(String)
    case unsupportedPlatform(role: MeshScaleToolchainRole, platform: String, arch: String, version: String)
    case invalidArtifactURL(String)
    case missingInstalledToolchain(role: MeshScaleToolchainRole)
    case missingExecutable(URL)
    case extractionFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case noCurrentToolchain

    var errorDescription: String? {
        switch self {
        case .invalidRole(let value):
            return "Unsupported toolchain role '\(value)'. Use 'control-plane' or 'worker'."
        case .invalidManifestURL(let value):
            return "Invalid toolchain manifest URL: \(value)"
        case .manifestDownloadFailed(let value):
            return "Failed to download the MeshScale toolchain manifest: \(value)"
        case .manifestDecodeFailed(let value):
            return "Failed to decode the MeshScale toolchain manifest: \(value)"
        case .unsupportedPlatform(let role, let platform, let arch, let version):
            return "No \(role.displayName) toolchain is published for \(platform)-\(arch) in version \(version)."
        case .invalidArtifactURL(let value):
            return "Invalid toolchain artifact URL: \(value)"
        case .missingInstalledToolchain(let role):
            return "No installed MeshScale \(role.displayName) toolchain was found. Run 'meshscale install' first."
        case .missingExecutable(let url):
            return "Installed MeshScale toolchain is missing executable: \(url.path)"
        case .extractionFailed(let value):
            return "Failed to extract the MeshScale toolchain archive: \(value)"
        case .checksumMismatch(let expected, let actual):
            return "MeshScale toolchain checksum mismatch. Expected \(expected), got \(actual)."
        case .noCurrentToolchain:
            return "No MeshScale toolchain version is selected. Run 'meshscale install' first."
        }
    }
}

struct ToolchainManager: @unchecked Sendable {
    static let shared = ToolchainManager()
    typealias ProgressHandler = @Sendable (String) -> Void

    private let fileManager = FileManager.default
    private let meshScaleHome: URL
    private let toolchainsDir: URL
    private let selectionFile: URL
    private let defaultManifestURL = "https://github.com/SunlightHorizon/MeshScale/releases/latest/download/meshscale-toolchains.json"

    private init() {
        meshScaleHome = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".meshscale", isDirectory: true)
        toolchainsDir = meshScaleHome.appendingPathComponent("toolchains", isDirectory: true)
        selectionFile = toolchainsDir.appendingPathComponent("current.json")

        try? fileManager.createDirectory(at: toolchainsDir, withIntermediateDirectories: true)
    }

    func install(
        version requestedVersion: String,
        roles: [MeshScaleToolchainRole],
        manifestURL overrideManifestURL: String? = nil,
        progress: ProgressHandler? = nil
    ) throws -> String {
        let manifestURLString =
            overrideManifestURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? overrideManifestURL!
            : ProcessInfo.processInfo.environment["MESHCALE_INSTALL_MANIFEST_URL"]
                ?? defaultManifestURL

        progress?("Fetching toolchain manifest from \(manifestURLString)")
        let manifest = try fetchManifest(from: manifestURLString)
        let version = resolveVersion(requestedVersion, manifest: manifest)
        let platform = currentPlatformIdentifier()
        let arch = currentArchitectureIdentifier()
        progress?("Resolved install target: version \(version), platform \(platform), arch \(arch)")

        for role in roles {
            progress?("Preparing \(role.displayName) toolchain")
            let matchingArtifacts = manifest.artifacts.filter {
                $0.version == version &&
                $0.platform == platform &&
                $0.arch == arch &&
                $0.role == role.rawValue
            }

            guard let binaryArtifact = matchingArtifacts.first(where: {
                let component = $0.component?.lowercased() ?? "binary"
                return component == "binary"
            }) else {
                throw ToolchainManagerError.unsupportedPlatform(
                    role: role,
                    platform: platform,
                    arch: arch,
                    version: version
                )
            }

            let root = toolchainRoot(version: version, role: role)
            try installArtifact(binaryArtifact, to: root, progress: progress)

            let componentArtifacts = matchingArtifacts.filter {
                let component = $0.component?.lowercased() ?? "binary"
                return component != "binary"
            }

            for artifact in componentArtifacts {
                let componentName = artifact.installSubpath ?? artifact.component ?? UUID().uuidString
                let destination = root.appendingPathComponent(componentName, isDirectory: true)
                try installArtifact(artifact, to: destination, progress: progress)
            }

            progress?("Installed \(role.displayName) toolchain into \(root.path)")
        }

        try saveSelection(
            MeshScaleToolchainSelection(
                version: version,
                updatedAt: Date()
            )
        )
        progress?("Selected MeshScale toolchain version \(version)")
        return version
    }

    func currentVersion() -> String? {
        loadSelection()?.version
    }

    func resolveExecutable(
        for role: MeshScaleToolchainRole,
        allowLocalBuild: Bool = true
    ) throws -> ResolvedToolchainExecutable {
        if let selection = loadSelection(),
           let installedURL = installedExecutableURL(version: selection.version, role: role) {
            let environment = executionEnvironment(version: selection.version, role: role)
            return ResolvedToolchainExecutable(
                url: installedURL,
                environment: environment,
                source: "installed toolchain \(selection.version)"
            )
        }

        if allowLocalBuild, let localURL = localExecutableURL(named: role.executableName) {
            return ResolvedToolchainExecutable(
                url: localURL,
                environment: [:],
                source: "local build"
            )
        }

        throw ToolchainManagerError.missingInstalledToolchain(role: role)
    }

    func toolchainRoot(version: String, role: MeshScaleToolchainRole) -> URL {
        toolchainsDir
            .appendingPathComponent(version, isDirectory: true)
            .appendingPathComponent(role.rawValue, isDirectory: true)
    }

    private func fetchManifest(from manifestURLString: String) throws -> MeshScaleToolchainManifest {
        guard let url = URL(string: manifestURLString) else {
            throw ToolchainManagerError.invalidManifestURL(manifestURLString)
        }

        let data = try download(url: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(MeshScaleToolchainManifest.self, from: data)
        } catch {
            throw ToolchainManagerError.manifestDecodeFailed(error.localizedDescription)
        }
    }

    private func resolveVersion(_ requestedVersion: String, manifest: MeshScaleToolchainManifest) -> String {
        let trimmed = requestedVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "latest" else {
            return manifest.latestVersion
        }

        if manifest.artifacts.contains(where: { $0.version == trimmed }) {
            return trimmed
        }

        let withPrefix = trimmed.hasPrefix("v") ? trimmed : "v\(trimmed)"
        if manifest.artifacts.contains(where: { $0.version == withPrefix }) {
            return withPrefix
        }

        return trimmed
    }

    private func installArtifact(
        _ artifact: MeshScaleToolchainArtifact,
        to destinationURL: URL,
        progress: ProgressHandler?
    ) throws {
        guard let artifactURL = URL(string: artifact.url) else {
            throw ToolchainManagerError.invalidArtifactURL(artifact.url)
        }

        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent("meshscale-toolchain-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = temporaryRoot.appendingPathComponent("artifact.tar.gz")
        let extractionURL = temporaryRoot.appendingPathComponent("extracted", isDirectory: true)

        try fileManager.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        progress?("Downloading \(artifactDescription(for: artifact))")
        try download(url: artifactURL, to: archiveURL)

        if let expectedChecksum = artifact.sha256?.lowercased(),
           !expectedChecksum.isEmpty {
            progress?("Verifying checksum for \(artifactDescription(for: artifact))")
            let actualChecksum = try sha256Hex(for: archiveURL).lowercased()
            guard actualChecksum == expectedChecksum else {
                throw ToolchainManagerError.checksumMismatch(
                    expected: expectedChecksum,
                    actual: actualChecksum
                )
            }
        }

        progress?("Extracting \(artifactDescription(for: artifact))")
        try extractArchive(at: archiveURL, to: extractionURL)

        let payloadRoot = try payloadRootDirectory(from: extractionURL)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        progress?("Installing \(artifactDescription(for: artifact)) into \(destinationURL.path)")
        try fileManager.copyItem(at: payloadRoot, to: destinationURL)

        if let executables = artifact.executables {
            for executable in executables {
                try markExecutableIfPresent(
                    at: destinationURL.appendingPathComponent(executable)
                )
                try markExecutableIfPresent(
                    at: destinationURL
                        .appendingPathComponent("bin", isDirectory: true)
                        .appendingPathComponent(executable)
                )
            }
        }
    }

    private func download(url: URL) throws -> Data {
        let temporaryFile = fileManager.temporaryDirectory
            .appendingPathComponent("meshscale-download-\(UUID().uuidString)", isDirectory: false)
        defer { try? fileManager.removeItem(at: temporaryFile) }

        try download(url: url, to: temporaryFile)
        return try Data(contentsOf: temporaryFile)
    }

    private func download(url: URL, to destinationURL: URL) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let session = URLSession.shared

        final class Box: @unchecked Sendable {
            var temporaryURL: URL?
            var response: URLResponse?
            var error: Error?
        }

        let box = Box()
        let task = session.downloadTask(with: url) { temporaryURL, response, error in
            box.temporaryURL = temporaryURL
            box.response = response
            box.error = error
            semaphore.signal()
        }
        task.resume()

        semaphore.wait()

        if let error = box.error {
            throw ToolchainManagerError.manifestDownloadFailed(error.localizedDescription)
        }

        guard let http = box.response as? HTTPURLResponse else {
            throw ToolchainManagerError.manifestDownloadFailed("No HTTP response received.")
        }

        guard (200..<300).contains(http.statusCode), let temporaryURL = box.temporaryURL else {
            throw ToolchainManagerError.manifestDownloadFailed("HTTP \(http.statusCode)")
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
    }

    private func extractArchive(at archiveURL: URL, to destinationURL: URL) throws {
        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["tar", "-xzf", archiveURL.path, "-C", destinationURL.path]
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorOutput = String(
                decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            )
            throw ToolchainManagerError.extractionFailed(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func payloadRootDirectory(from extractedURL: URL) throws -> URL {
        let entries = try fileManager.contentsOfDirectory(
            at: extractedURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        if entries.count == 1,
           let isDirectory = try? entries[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
           isDirectory == true {
            return entries[0]
        }

        return extractedURL
    }

    private func saveSelection(_ selection: MeshScaleToolchainSelection) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(selection)
        try data.write(to: selectionFile, options: .atomic)
    }

    private func loadSelection() -> MeshScaleToolchainSelection? {
        guard let data = try? Data(contentsOf: selectionFile) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MeshScaleToolchainSelection.self, from: data)
    }

    private func installedExecutableURL(version: String, role: MeshScaleToolchainRole) -> URL? {
        let root = toolchainRoot(version: version, role: role)
        let candidates = [
            root.appendingPathComponent(role.executableName),
            root.appendingPathComponent("bin", isDirectory: true).appendingPathComponent(role.executableName),
        ]

        return candidates.first(where: { fileManager.fileExists(atPath: $0.path) })
    }

    private func executionEnvironment(version: String, role: MeshScaleToolchainRole) -> [String: String] {
        var environment: [String: String] = [
            "MESHCALE_TOOLCHAIN_VERSION": version,
            "MESHCALE_TOOLCHAIN_ROLE": role.rawValue,
        ]

        if let swiftExecutable = bundledSwiftExecutableURL(version: version, role: role) {
            environment["MESHCALE_SWIFT_EXECUTABLE"] = swiftExecutable.path

            let swiftBinDirectory = swiftExecutable.deletingLastPathComponent().path
            environment["PATH"] = prependPathComponent(
                swiftBinDirectory,
                to: ProcessInfo.processInfo.environment["PATH"]
            )
        }

        if let foundationDBRoot = bundledFoundationDBRoot(version: version, role: role) {
            let includeDirectory = foundationDBRoot
                .appendingPathComponent("include", isDirectory: true)
                .path
            let libraryDirectory = foundationDBRoot
                .appendingPathComponent("lib", isDirectory: true)
                .path

            if fileManager.fileExists(atPath: includeDirectory) {
                environment["CPATH"] = prependPathComponent(
                    includeDirectory,
                    to: ProcessInfo.processInfo.environment["CPATH"]
                )
                environment["C_INCLUDE_PATH"] = prependPathComponent(
                    includeDirectory,
                    to: ProcessInfo.processInfo.environment["C_INCLUDE_PATH"]
                )
            }

            if fileManager.fileExists(atPath: libraryDirectory) {
                environment["LIBRARY_PATH"] = prependPathComponent(
                    libraryDirectory,
                    to: ProcessInfo.processInfo.environment["LIBRARY_PATH"]
                )
                environment["LD_LIBRARY_PATH"] = prependPathComponent(
                    libraryDirectory,
                    to: ProcessInfo.processInfo.environment["LD_LIBRARY_PATH"]
                )
                environment["DYLD_LIBRARY_PATH"] = prependPathComponent(
                    libraryDirectory,
                    to: ProcessInfo.processInfo.environment["DYLD_LIBRARY_PATH"]
                )
            }
        }

        return environment
    }

    private func bundledSwiftExecutableURL(version: String, role: MeshScaleToolchainRole) -> URL? {
        let root = toolchainRoot(version: version, role: role)
        let candidates = [
            root.appendingPathComponent("swift"),
            root.appendingPathComponent("bin", isDirectory: true).appendingPathComponent("swift"),
            root.appendingPathComponent("swift-toolchain", isDirectory: true).appendingPathComponent("bin", isDirectory: true).appendingPathComponent("swift"),
            root.appendingPathComponent("swift-toolchain", isDirectory: true).appendingPathComponent("usr", isDirectory: true).appendingPathComponent("bin", isDirectory: true).appendingPathComponent("swift"),
        ]

        return candidates.first(where: { fileManager.fileExists(atPath: $0.path) })
    }

    private func bundledFoundationDBRoot(version: String, role: MeshScaleToolchainRole) -> URL? {
        let root = toolchainRoot(version: version, role: role)
        let candidates = [
            root.appendingPathComponent("foundationdb", isDirectory: true),
            root.appendingPathComponent("deps", isDirectory: true)
                .appendingPathComponent("foundationdb", isDirectory: true),
        ]

        for candidate in candidates {
            let includeDirectory = candidate
                .appendingPathComponent("include", isDirectory: true)
                .appendingPathComponent("foundationdb", isDirectory: true)
                .appendingPathComponent("fdb_c.h")
            let libraryDirectory = candidate
                .appendingPathComponent("lib", isDirectory: true)

            if fileManager.fileExists(atPath: includeDirectory.path),
               fileManager.fileExists(atPath: libraryDirectory.path) {
                return candidate
            }
        }

        return nil
    }

    private func localExecutableURL(named executableName: String) -> URL? {
        let currentExecutableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let binaryDirectory = currentExecutableURL.deletingLastPathComponent()
        let siblingExecutable = binaryDirectory.appendingPathComponent(executableName)
        if fileManager.fileExists(atPath: siblingExecutable.path) {
            return siblingExecutable
        }

        let candidates = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent(".build", isDirectory: true)
                .appendingPathComponent("debug", isDirectory: true)
                .appendingPathComponent(executableName),
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent(".build-fdb", isDirectory: true)
                .appendingPathComponent("arm64-apple-macosx", isDirectory: true)
                .appendingPathComponent("debug", isDirectory: true)
                .appendingPathComponent(executableName),
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent(".build-linux", isDirectory: true)
                .appendingPathComponent("x86_64-unknown-linux-gnu", isDirectory: true)
                .appendingPathComponent("debug", isDirectory: true)
                .appendingPathComponent(executableName),
        ]

        return candidates.first(where: { fileManager.fileExists(atPath: $0.path) })
    }

    private func prependPathComponent(_ component: String, to existingValue: String?) -> String {
        guard let existingValue, !existingValue.isEmpty else {
            return component
        }

        let parts = existingValue.split(separator: ":").map(String.init)
        if parts.contains(component) {
            return existingValue
        }
        return "\(component):\(existingValue)"
    }

    private func markExecutableIfPresent(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        var permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o644
        permissions |= 0o755
        try fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
    }

    private func currentPlatformIdentifier() -> String {
        #if os(macOS)
        return "darwin"
        #elseif os(Linux)
        return "linux"
        #elseif os(Windows)
        return "windows"
        #else
        return "unknown"
        #endif
    }

    private func currentArchitectureIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let mirror = Mirror(reflecting: systemInfo.machine)
        let rawMachine = mirror.children.reduce(into: "") { partialResult, element in
            guard let value = element.value as? Int8, value != 0 else {
                return
            }
            partialResult.append(Character(UnicodeScalar(UInt8(value))))
        }

        switch rawMachine.lowercased() {
        case "x86_64", "amd64":
            return "amd64"
        case "arm64", "aarch64":
            return "arm64"
        default:
            return rawMachine.lowercased()
        }
    }

    private func sha256Hex(for fileURL: URL) throws -> String {
        let commands: [[String]] = [
            ["sha256sum", fileURL.path],
            ["shasum", "-a", "256", fileURL.path],
        ]

        for command in commands {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = command
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                continue
            }

            guard process.terminationStatus == 0 else {
                continue
            }

            let output = String(
                decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            )
            if let checksum = output.split(separator: " ").first {
                return String(checksum)
            }
        }

        throw ToolchainManagerError.extractionFailed("No SHA-256 utility was available to verify the toolchain archive.")
    }

    private func artifactDescription(for artifact: MeshScaleToolchainArtifact) -> String {
        let component = artifact.component ?? "binary"
        return "\(artifact.role) \(component) (\(artifact.platform)-\(artifact.arch))"
    }
}
