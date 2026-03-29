import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if os(macOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif
import ArgumentParser
import MeshScaleStore
import MeshScaleWorkerRuntime

enum MeshScaleSetupRole: String, CaseIterable, Codable {
    case controlPlane = "control-plane"
    case worker = "worker"

    var displayName: String {
        switch self {
        case .controlPlane:
            return "control plane"
        case .worker:
            return "worker"
        }
    }

    var requiredDependencies: [MeshScaleSystemDependency] {
        switch self {
        case .controlPlane:
            return [.netbird, .foundationDB]
        case .worker:
            return [.netbird]
        }
    }

    static func parse(_ rawValue: String) throws -> MeshScaleSetupRole {
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
            throw SetupError.invalidRole(rawValue)
        }
    }
}

enum MeshScaleSystemDependency: String, Codable {
    case netbird
    case foundationDB = "foundationdb"

    var displayName: String {
        switch self {
        case .netbird:
            return "NetBird"
        case .foundationDB:
            return "FoundationDB"
        }
    }
}

struct MeshScaleDependencyStatus: Codable {
    let dependency: MeshScaleSystemDependency
    let installed: Bool
    let detail: String
}

struct MeshScaleRoleSetupRecord: Codable {
    let role: MeshScaleSetupRole
    let completedAt: Date
    let dependencies: [MeshScaleDependencyStatus]
    let details: MeshScaleRoleSetupDetails
}

struct MeshScaleRoleSetupDetails: Codable {
    let netBirdManagementURL: String?
    let netBirdSetupKey: String?
    let netBirdAdminURL: String?
    let netBirdHostname: String?
    let foundationDBClusterFilePath: String?
    let foundationDBConnectionDescription: String?
}

struct MeshScaleSetupState: Codable {
    var roles: [String: MeshScaleRoleSetupRecord]
}

enum SetupError: LocalizedError {
    case invalidRole(String)
    case unsupportedPlatform(String)
    case setupNotCompleted(role: MeshScaleSetupRole)
    case setupRequired(role: MeshScaleSetupRole, missing: [MeshScaleDependencyStatus])
    case installFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidRole(let value):
            return "Unsupported setup role '\(value)'. Use 'control-plane' or 'worker'."
        case .unsupportedPlatform(let detail):
            return detail
        case .setupNotCompleted(let role):
            return "Mandatory setup has not been completed for the \(role.displayName)."
        case .setupRequired(let role, let missing):
            let summary = missing
                .map { "\($0.dependency.displayName): \($0.detail)" }
                .joined(separator: "; ")
            return "Mandatory setup is incomplete for the \(role.displayName). Missing: \(summary)"
        case .installFailed(let message):
            return "Setup failed: \(message)"
        case .commandFailed(let message):
            return message
        }
    }
}

struct SetupManager: @unchecked Sendable {
    static let shared = SetupManager()

    private let fileManager = FileManager.default
    private let stateFile: URL
    private let meshScaleHome: URL

    private init() {
        let home = SetupManager.resolveMeshScaleHomeDirectory(using: fileManager)
        meshScaleHome = home
            .appendingPathComponent(".meshscale", isDirectory: true)
        stateFile = meshScaleHome.appendingPathComponent("setup.json")
        try? fileManager.createDirectory(at: meshScaleHome, withIntermediateDirectories: true)
    }

    private static func resolveMeshScaleHomeDirectory(using fileManager: FileManager) -> URL {
        let environment = ProcessInfo.processInfo.environment
        if let sudoUser = environment["SUDO_USER"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sudoUser.isEmpty {
            if let sudoHome = homeDirectoryForSystemUser(named: sudoUser) {
                return sudoHome
            }

            if let sudoHome = fileManager.homeDirectory(forUser: sudoUser) {
                return sudoHome
            }

            let conventionalMacHome = URL(fileURLWithPath: "/Users/\(sudoUser)", isDirectory: true)
            if fileManager.fileExists(atPath: conventionalMacHome.path) {
                return conventionalMacHome
            }

            let conventionalLinuxHome = URL(fileURLWithPath: "/home/\(sudoUser)", isDirectory: true)
            if fileManager.fileExists(atPath: conventionalLinuxHome.path) {
                return conventionalLinuxHome
            }
        }

        if let homePath = environment["HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !homePath.isEmpty {
            return URL(fileURLWithPath: homePath, isDirectory: true)
        }

        return fileManager.homeDirectoryForCurrentUser
    }

    private static func homeDirectoryForSystemUser(named username: String) -> URL? {
        guard let cString = username.cString(using: .utf8) else {
            return nil
        }
        return cString.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress,
                  let user = getpwnam(baseAddress) else {
                return nil
            }
            return URL(fileURLWithPath: String(cString: user.pointee.pw_dir), isDirectory: true)
        }
    }

    private func stateFileCandidates() -> [URL] {
        var candidates: [URL] = [stateFile]
        var seenPaths = Set(candidates.map(\.path))

        func appendCandidate(home: URL?) {
            guard let home else { return }
            let candidate = home
                .appendingPathComponent(".meshscale", isDirectory: true)
                .appendingPathComponent("setup.json")
            guard seenPaths.insert(candidate.path).inserted else { return }
            candidates.append(candidate)
        }

        let environment = ProcessInfo.processInfo.environment
        if let sudoUser = environment["SUDO_USER"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sudoUser.isEmpty {
            appendCandidate(home: Self.homeDirectoryForSystemUser(named: sudoUser))
            appendCandidate(home: fileManager.homeDirectory(forUser: sudoUser))
            appendCandidate(home: URL(fileURLWithPath: "/Users/\(sudoUser)", isDirectory: true))
            appendCandidate(home: URL(fileURLWithPath: "/home/\(sudoUser)", isDirectory: true))
        }

        if let homePath = environment["HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !homePath.isEmpty {
            appendCandidate(home: URL(fileURLWithPath: homePath, isDirectory: true))
        }

        appendCandidate(home: fileManager.homeDirectoryForCurrentUser)
        return candidates
    }

    func assertReady(for role: MeshScaleSetupRole) throws {
        let statuses = dependencyStatuses(for: role)
        let missing = statuses.filter { !$0.installed }
        guard missing.isEmpty else {
            throw SetupError.setupRequired(role: role, missing: missing)
        }

        let hasRecord = loadState()?.roles[role.rawValue] != nil
        guard hasRecord else {
            throw SetupError.setupNotCompleted(role: role)
        }

        if role == .controlPlane,
           let details = loadState()?.roles[role.rawValue]?.details,
           let clusterFilePath = details.foundationDBClusterFilePath,
           !fileManager.fileExists(atPath: clusterFilePath) {
            throw SetupError.setupRequired(
                role: role,
                missing: [
                    MeshScaleDependencyStatus(
                        dependency: .foundationDB,
                        installed: false,
                        detail: "Configured cluster file is missing at \(clusterFilePath). Run 'meshscale setup --role control-plane' again."
                    )
                ]
            )
        }
    }

    func runSetup(for roles: [MeshScaleSetupRole], bootstrapCluster: Bool = false) throws {
        let uniqueRoles = Array(Set(roles)).sorted { $0.rawValue < $1.rawValue }
        for role in uniqueRoles {
            let details = try promptForDetails(for: role, bootstrapCluster: bootstrapCluster)
            try installMissingDependencies(for: role)
            try configureRole(role, using: details, bootstrapCluster: bootstrapCluster)
            let statuses = dependencyStatuses(for: role)
            let missing = statuses.filter { !$0.installed }
            guard missing.isEmpty else {
                throw SetupError.setupRequired(role: role, missing: missing)
            }
            try saveRecord(
                MeshScaleRoleSetupRecord(
                    role: role,
                    completedAt: Date(),
                    dependencies: statuses,
                    details: details
                )
            )
        }
    }

    func environment(for role: MeshScaleSetupRole) -> [String: String] {
        guard let record = loadState()?.roles[role.rawValue] else {
            return [:]
        }

        var environment: [String: String] = [:]
        let rolePrefix = role == .controlPlane ? "CONTROL_PLANE" : "WORKER"
        let shouldEnableNetBird = !(record.details.netBirdSetupKey?.isEmpty ?? true)

        if shouldEnableNetBird {
            environment["MESHCALE_\(rolePrefix)_NETBIRD_ENABLED"] = "true"
            environment["MESHCALE_\(rolePrefix)_NETBIRD_REQUIRED"] = "true"
        }

        if let managementURL = record.details.netBirdManagementURL, !managementURL.isEmpty {
            environment["MESHCALE_\(rolePrefix)_NETBIRD_MANAGEMENT_URL"] = managementURL
        }
        if let setupKey = record.details.netBirdSetupKey, !setupKey.isEmpty {
            environment["MESHCALE_\(rolePrefix)_NETBIRD_SETUP_KEY"] = setupKey
        }
        if let adminURL = record.details.netBirdAdminURL, !adminURL.isEmpty {
            environment["MESHCALE_\(rolePrefix)_NETBIRD_ADMIN_URL"] = adminURL
        }
        if let hostname = record.details.netBirdHostname, !hostname.isEmpty {
            environment["MESHCALE_\(rolePrefix)_NETBIRD_HOSTNAME"] = hostname
        }
        if role == .controlPlane,
           let clusterFilePath = record.details.foundationDBClusterFilePath,
           !clusterFilePath.isEmpty {
            environment["MESHCALE_FDB_CLUSTER_FILE"] = clusterFilePath
        }

        return environment
    }

    func dependencyStatuses(for role: MeshScaleSetupRole) -> [MeshScaleDependencyStatus] {
        role.requiredDependencies.map(status(for:))
    }

    func loadState() -> MeshScaleSetupState? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for candidate in stateFileCandidates() {
            guard let data = try? Data(contentsOf: candidate) else {
                continue
            }
            if let decoded = try? decoder.decode(MeshScaleSetupState.self, from: data) {
                return decoded
            }
        }
        return nil
    }

    private func promptForDetails(for role: MeshScaleSetupRole, bootstrapCluster: Bool) throws -> MeshScaleRoleSetupDetails {
        let existing = loadState()?.roles[role.rawValue]?.details
        let hostName = ProcessInfo.processInfo.hostName

        if bootstrapCluster {
            let bootstrapNetBird = try bootstrapNetBirdControlPlaneIfNeeded(
                for: role,
                hostname: hostName,
                existingDetails: existing
            )
            let bootstrapFoundationDB = role == .controlPlane ? try bootstrapFoundationDBIfNeeded() : nil
            return MeshScaleRoleSetupDetails(
                netBirdManagementURL: bootstrapNetBird?.managementURL ?? existing?.netBirdManagementURL,
                netBirdSetupKey: bootstrapNetBird?.setupKey ?? existing?.netBirdSetupKey,
                netBirdAdminURL: bootstrapNetBird?.adminURL ?? existing?.netBirdAdminURL,
                netBirdHostname: existing?.netBirdHostname ?? hostName,
                foundationDBClusterFilePath: bootstrapFoundationDB?.clusterFilePath ?? existing?.foundationDBClusterFilePath,
                foundationDBConnectionDescription: bootstrapFoundationDB?.connectionString ?? existing?.foundationDBConnectionDescription
            )
        }

        let netBirdManagementURL = prompt(
            label: "NetBird management URL for the \(role.displayName)",
            example: "https://netbird.example.com",
            defaultValue: environmentValue(
                primary: "MESHCALE_SETUP_NETBIRD_URL",
                role: role,
                existing: existing?.netBirdManagementURL
            )
        )
        let netBirdSetupKey = prompt(
            label: "NetBird setup key for the \(role.displayName)",
            example: "setup-key-from-netbird",
            defaultValue: environmentValue(
                primary: "MESHCALE_SETUP_NETBIRD_SETUP_KEY",
                role: role,
                existing: existing?.netBirdSetupKey
            ),
            allowEmpty: false
        )
        let netBirdAdminURL = prompt(
            label: "Optional NetBird admin URL for the \(role.displayName)",
            example: "https://netbird.example.com",
            defaultValue: environmentValue(
                primary: "MESHCALE_SETUP_NETBIRD_ADMIN_URL",
                role: role,
                existing: existing?.netBirdAdminURL
            ),
            allowEmpty: true
        )
        let netBirdHostname = prompt(
            label: "NetBird hostname for this \(role.displayName)",
            example: hostName,
            defaultValue: environmentValue(
                primary: "MESHCALE_SETUP_NETBIRD_HOSTNAME",
                role: role,
                existing: existing?.netBirdHostname ?? hostName
            ),
            allowEmpty: false
        )

        let foundationDBConnection: String?
        if role == .controlPlane {
            foundationDBConnection = prompt(
                label: "FoundationDB cluster URL or cluster-file contents for the control plane",
                example: "fdb://100.64.0.10:4500 or meshscale:token@100.64.0.10:4500",
                defaultValue: environmentValue(
                    primary: "MESHCALE_SETUP_FOUNDATIONDB_URL",
                    role: role,
                    existing: existing?.foundationDBConnectionDescription
                ),
                allowEmpty: false
            )
        } else {
            foundationDBConnection = nil
        }

        let clusterFilePath: String?
        if let foundationDBConnection {
            clusterFilePath = try writeFoundationDBClusterFile(from: foundationDBConnection)
        } else {
            clusterFilePath = nil
        }

        return MeshScaleRoleSetupDetails(
            netBirdManagementURL: netBirdManagementURL,
            netBirdSetupKey: netBirdSetupKey,
            netBirdAdminURL: netBirdAdminURL,
            netBirdHostname: netBirdHostname,
            foundationDBClusterFilePath: clusterFilePath,
            foundationDBConnectionDescription: foundationDBConnection
        )
    }

    private func configureRole(
        _ role: MeshScaleSetupRole,
        using details: MeshScaleRoleSetupDetails,
        bootstrapCluster: Bool
    ) throws {
        if bootstrapCluster {
            if let setupKey = details.netBirdSetupKey,
               let managementURL = details.netBirdManagementURL,
               let hostname = details.netBirdHostname {
                try ensureNetBirdServiceRunningForSetup()
                let status = try NetBirdClient(
                    configuration: NetBirdConfiguration(
                        enabled: true,
                        required: true,
                        setupKey: setupKey,
                        managementURL: managementURL,
                        adminURL: details.netBirdAdminURL,
                        hostname: hostname,
                        configPath: nil,
                        daemonAddress: nil
                    ),
                    logger: { print($0) }
                ).ensureConnected()

                guard status.connected else {
                    throw SetupError.commandFailed("NetBird bootstrap completed but the local agent did not connect.")
                }
            }

            if role == .controlPlane, let clusterFilePath = details.foundationDBClusterFilePath {
                try validateFoundationDBClusterFile(at: clusterFilePath)
            }
            return
        }

        let netBirdConfiguration = NetBirdConfiguration(
            enabled: true,
            required: true,
            setupKey: details.netBirdSetupKey,
            managementURL: details.netBirdManagementURL,
            adminURL: details.netBirdAdminURL,
            hostname: details.netBirdHostname,
            configPath: nil,
            daemonAddress: nil
        )

        try ensureNetBirdServiceRunningForSetup()
        let status = try NetBirdClient(
            configuration: netBirdConfiguration,
            logger: { print($0) }
        ).ensureConnected()

        guard status.connected else {
            throw SetupError.commandFailed("NetBird did not report a connected overlay after setup.")
        }

        if role == .controlPlane, let clusterFilePath = details.foundationDBClusterFilePath {
            try validateFoundationDBClusterFile(at: clusterFilePath)
        }
    }

    private func saveRecord(_ record: MeshScaleRoleSetupRecord) throws {
        var state = loadState() ?? MeshScaleSetupState(roles: [:])
        state.roles[record.role.rawValue] = record

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: stateFile, options: .atomic)

        for candidate in stateFileCandidates() where candidate.path != stateFile.path {
            let directory = candidate.deletingLastPathComponent()
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: candidate, options: .atomic)
        }
    }

    private func installMissingDependencies(for role: MeshScaleSetupRole) throws {
        for dependency in role.requiredDependencies {
            let current = status(for: dependency)
            if current.installed {
                continue
            }
            if dependency == .netbird {
                throw SetupError.installFailed(
                    "NetBird must already be installed before running 'meshscale setup'. Install it manually, then rerun setup."
                )
            }
            try install(dependency: dependency)
        }
    }

    private func status(for dependency: MeshScaleSystemDependency) -> MeshScaleDependencyStatus {
        switch dependency {
        case .netbird:
            if let version = commandOutput(["netbird", "version"])?.trimmingCharacters(in: .whitespacesAndNewlines),
               !version.isEmpty {
                return MeshScaleDependencyStatus(
                    dependency: dependency,
                    installed: true,
                    detail: version
                )
            }
            return MeshScaleDependencyStatus(
                dependency: dependency,
                installed: false,
                detail: "Install NetBird manually before running 'meshscale setup'."
            )

        case .foundationDB:
            let hasCLI = commandSucceeds(["fdbcli", "--version"])
            let hasServer = commandSucceeds(["fdbserver", "--version"]) || commandSucceeds(["fdbmonitor", "--version"])
            let hasHeader = foundationDBHeaderPaths().contains(where: { fileManager.fileExists(atPath: $0) })
            let hasLibrary = foundationDBLibraryPaths().contains(where: { fileManager.fileExists(atPath: $0) })

            if hasCLI && hasHeader && hasLibrary {
                var detail = commandOutput(["fdbcli", "--version"])?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nonEmpty ?? "installed"
                if !hasServer {
                    detail += " (client/runtime installed; local server tooling not detected)"
                }
                return MeshScaleDependencyStatus(
                    dependency: dependency,
                    installed: true,
                    detail: detail
                )
            }

            var missingParts: [String] = []
            if !hasCLI { missingParts.append("fdbcli") }
            if !hasHeader { missingParts.append("fdb_c.h") }
            if !hasLibrary { missingParts.append("libfdb_c") }

            return MeshScaleDependencyStatus(
                dependency: dependency,
                installed: false,
                detail: "Missing \(missingParts.joined(separator: ", "))."
            )
        }
    }

    private func install(dependency: MeshScaleSystemDependency) throws {
        print("Installing \(dependency.displayName)...")
        for command in try installCommands(for: dependency) {
            try runInteractiveShell(command)
        }
    }

    private func installCommands(for dependency: MeshScaleSystemDependency) throws -> [String] {
        #if os(macOS)
        switch dependency {
        case .netbird:
            return [
                "brew install netbirdio/tap/netbird",
                "netbird service install",
                "netbird service start",
            ]
        case .foundationDB:
            return [
                "brew install foundationdb",
            ]
        }
        #elseif os(Linux)
        switch dependency {
        case .netbird:
            if commandSucceeds(["sh", "-lc", "command -v apt-get >/dev/null 2>&1"]) {
                return [
                    "curl -fsSL https://pkgs.netbird.io/install.sh | sh",
                    "netbird service install || true",
                    "netbird service start",
                ]
            }

            return [
                """
                cat >/etc/yum.repos.d/netbird.repo <<'EOF'
                [netbird]
                name=netbird
                baseurl=https://pkgs.netbird.io/yum/
                enabled=1
                gpgcheck=0
                gpgkey=https://pkgs.netbird.io/yum/repodata/repomd.xml.key
                repo_gpgcheck=0
                EOF
                """,
                "dnf install -y dnf-plugins-core",
                "dnf config-manager --add-repo /etc/yum.repos.d/netbird.repo || dnf config-manager addrepo --from-repofile=/etc/yum.repos.d/netbird.repo",
                "dnf makecache",
                "dnf install -y netbird",
                "netbird service install || true",
                "netbird service start",
            ]
        case .foundationDB:
            let architecture = currentArchitecture()
            guard architecture == "amd64" else {
                throw SetupError.unsupportedPlatform(
                    "FoundationDB setup is currently supported only on linux/amd64 for MeshScale control planes."
                )
            }
            let version = ProcessInfo.processInfo.environment["MESHCALE_FOUNDATIONDB_VERSION"] ?? "7.3.69"
            return [
                "apt-get update",
                "apt-get install -y ca-certificates curl",
                "curl -L --retry 5 --retry-delay 2 -o /tmp/foundationdb-clients_\(version)-1_amd64.deb https://github.com/apple/foundationdb/releases/download/\(version)/foundationdb-clients_\(version)-1_amd64.deb",
                "curl -L --retry 5 --retry-delay 2 -o /tmp/foundationdb-server_\(version)-1_amd64.deb https://github.com/apple/foundationdb/releases/download/\(version)/foundationdb-server_\(version)-1_amd64.deb",
                "dpkg -i /tmp/foundationdb-clients_\(version)-1_amd64.deb /tmp/foundationdb-server_\(version)-1_amd64.deb",
                "service foundationdb start",
            ]
        }
        #else
        throw SetupError.unsupportedPlatform("MeshScale setup is currently supported on macOS and Linux only.")
        #endif
    }

    private func prompt(
        label: String,
        example: String,
        defaultValue: String?,
        allowEmpty: Bool = false
    ) -> String? {
        if let environmentValue = defaultValue, !environmentValue.isEmpty,
           ProcessInfo.processInfo.environment["CI"] == "true" {
            return environmentValue
        }

        while true {
            if let defaultValue, !defaultValue.isEmpty {
                print("\(label) [\(defaultValue)]")
            } else {
                print("\(label)")
            }
            print("  example: \(example)")

            let rawInput = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if rawInput.isEmpty {
                if let defaultValue {
                    return defaultValue.isEmpty && allowEmpty ? nil : defaultValue
                }
                if allowEmpty {
                    return nil
                }
                print("A value is required.")
                continue
            }
            return rawInput
        }
    }

    private func promptSecret(
        label: String,
        example: String,
        allowEmpty: Bool = false
    ) -> String? {
        while true {
            print("\(label)")
            print("  example: \(example)")

            if let secretPointer = getpass("") {
                let rawInput = String(cString: secretPointer)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if rawInput.isEmpty {
                    if allowEmpty {
                        return nil
                    }
                    print("A value is required.")
                    continue
                }
                return rawInput
            }

            let rawInput = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if rawInput.isEmpty {
                if allowEmpty {
                    return nil
                }
                print("A value is required.")
                continue
            }
            return rawInput
        }
    }

    private func environmentValue(primary: String, role: MeshScaleSetupRole, existing: String?) -> String? {
        let rolePrefix = role == .controlPlane ? "CONTROL_PLANE" : "WORKER"
        let environment = ProcessInfo.processInfo.environment
        return environment["\(primary)_\(rolePrefix)"] ?? environment[primary] ?? existing
    }

    private func writeFoundationDBClusterFile(from rawInput: String) throws -> String {
        let normalized = try normalizeFoundationDBConnection(rawInput)
        let directory = meshScaleHome.appendingPathComponent("foundationdb", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let clusterFile = directory.appendingPathComponent("cluster.fdb.cluster")
        try normalized.write(to: clusterFile, atomically: true, encoding: .utf8)
        return clusterFile.path
    }

    private func normalizeFoundationDBConnection(_ rawInput: String) throws -> String {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SetupError.commandFailed("FoundationDB cluster connection is required.")
        }

        if trimmed.contains("@") {
            return trimmed
        }

        let endpoint: String
        if let url = URL(string: trimmed), let host = url.host, let port = url.port {
            endpoint = "\(host):\(port)"
        } else {
            endpoint = trimmed.replacingOccurrences(of: "fdb://", with: "")
        }

        guard endpoint.contains(":"), !endpoint.contains("@") else {
            throw SetupError.commandFailed(
                "FoundationDB connection must be a cluster string or an endpoint like fdb://100.64.0.10:4500."
            )
        }

        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        return "meshscale:\(token)@\(endpoint)"
    }

    private func validateFoundationDBClusterFile(at path: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["fdbcli", "--exec", "status minimal", "--cluster-file", path]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderr = String(
                data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
            let stdout = String(
                data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = [stderr, stdout]
                .compactMap { $0?.nonEmpty }
                .joined(separator: "\n")
            throw SetupError.commandFailed(
                "FoundationDB cluster validation failed for \(path): \(message.isEmpty ? "unknown error" : message)"
            )
        }
    }

    private func bootstrapNetBirdControlPlaneIfNeeded(
        for role: MeshScaleSetupRole,
        hostname: String,
        existingDetails: MeshScaleRoleSetupDetails?
    ) throws -> (adminURL: String, managementURL: String, setupKey: String?)? {
        guard role == .controlPlane else {
            return nil
        }

        let docker = CLIDockerRunner()
        guard docker.isAvailable() else {
            throw SetupError.commandFailed(
                "Docker is required to bootstrap the local NetBird control plane. \(docker.explainUnavailable() ?? "")"
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        let baseDirectory = meshScaleHome
            .appendingPathComponent("netbird", isDirectory: true)
            .appendingPathComponent("bootstrap", isDirectory: true)
        let dataDirectory = baseDirectory.appendingPathComponent("data", isDirectory: true)
        let configDirectory = baseDirectory.appendingPathComponent("config", isDirectory: true)
        try fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: baseDirectory.path)
        try? fileManager.setAttributes([.posixPermissions: 0o777], ofItemAtPath: dataDirectory.path)
        try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: configDirectory.path)

        let publicHost = preferredBootstrapNetBirdPublicHost()
        let adminURL = "http://\(publicHost):18080"
        let managementURL = "http://\(publicHost):18081"
        let configPath = configDirectory.appendingPathComponent("config.yaml")
        let config = bootstrapNetBirdServerConfig(
            host: publicHost,
            dashboardPort: 18080,
            managementPort: 18081
        )
        try config.write(to: configPath, atomically: true, encoding: .utf8)
        try? fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: configPath.path)

        let serverContainer = "meshscale-bootstrap-netbird-server"
        let dashboardContainer = "meshscale-bootstrap-netbird-dashboard"
        let serverVolumes = [
            VolumeMount(name: dataDirectory.path, mountPath: "/var/lib/netbird"),
            VolumeMount(name: configPath.path, mountPath: "/etc/netbird/config.yaml"),
        ]
        let serverArgs = ["--config", "/etc/netbird/config.yaml"]
        let serverPorts = [
            PortBinding(hostPort: 18081, containerPort: 80),
        ]
        let dashboardEnvironment = bootstrapNetBirdDashboardEnvironment(
            host: publicHost,
            dashboardPort: 18080,
            managementPort: 18081
        )
        let dashboardPorts = [
            PortBinding(hostPort: 18080, containerPort: 80),
        ]

        if !(docker.isRunning(containerId: serverContainer) &&
            docker.matchesDesiredState(
                containerId: serverContainer,
                image: "netbirdio/netbird-server:latest",
                env: [:],
                ports: serverPorts,
                volumes: serverVolumes,
                args: serverArgs
            )) {
            _ = docker.remove(containerId: serverContainer)
            guard docker.run(
                containerId: serverContainer,
                image: "netbirdio/netbird-server:latest",
                env: [:],
                ports: serverPorts,
                volumes: serverVolumes,
                args: serverArgs
            ) else {
                throw SetupError.commandFailed("Failed to start the local NetBird server bootstrap container.")
            }
        }

        if !(docker.isRunning(containerId: dashboardContainer) &&
            docker.matchesDesiredState(
                containerId: dashboardContainer,
                image: "netbirdio/dashboard:latest",
                env: dashboardEnvironment,
                ports: dashboardPorts,
                volumes: nil,
                args: nil
            )) {
            _ = docker.remove(containerId: dashboardContainer)
            guard docker.run(
                containerId: dashboardContainer,
                image: "netbirdio/dashboard:latest",
                env: dashboardEnvironment,
                ports: dashboardPorts,
                volumes: nil,
                args: nil
            ) else {
                throw SetupError.commandFailed("Failed to start the local NetBird dashboard bootstrap container.")
            }
        }

        try waitForHTTP(url: URL(string: "\(adminURL)/setup")!, expectedStatusPrefix: 200)
        try waitForHTTP(url: URL(string: "\(managementURL)/oauth2/.well-known/openid-configuration")!, expectedStatusPrefix: 200)

        let setupKey = try bootstrapNetBirdSetupKey(
            adminURL: adminURL,
            managementURL: managementURL,
            hostname: hostname,
            existingSetupKey: existingDetails?.netBirdSetupKey
        )

        print("NetBird dashboard/admin panel: \(adminURL)")
        print("NetBird management API: \(managementURL)")
        print("NetBird bootstrap setup key is ready for the local agent.")

        return (adminURL: adminURL, managementURL: managementURL, setupKey: setupKey)
    }

    private func bootstrapNetBirdSetupKey(
        adminURL: String,
        managementURL: String,
        hostname: String,
        existingSetupKey: String?
    ) throws -> String {
        let instanceStatus = try fetchBootstrapNetBirdInstanceStatus(managementURL: managementURL)
        let ownerCredentials: BootstrapNetBirdOwnerCredentials

        if instanceStatus.setupRequired {
            ownerCredentials = try bootstrapNetBirdOwnerCredentials(
                hostname: hostname,
                allowGeneratedValues: true
            )
            try createBootstrapNetBirdOwner(
                managementURL: managementURL,
                credentials: ownerCredentials
            )
            print("Created the initial NetBird owner account for bootstrap: \(ownerCredentials.email)")
        } else {
            if let existingSetupKey, !existingSetupKey.isEmpty {
                return existingSetupKey
            }

            ownerCredentials = try bootstrapNetBirdOwnerCredentials(
                hostname: hostname,
                allowGeneratedValues: false
            )
        }

        let accessToken = try loginToBootstrapNetBirdOwner(
            adminURL: adminURL,
            managementURL: managementURL,
            credentials: ownerCredentials
        )
        let setupKey = try createBootstrapNetBirdSetupKey(
            managementURL: managementURL,
            accessToken: accessToken
        )

        if ownerCredentials.shouldEchoCredentials {
            print("Bootstrap NetBird owner email: \(ownerCredentials.email)")
            print("Bootstrap NetBird owner password: \(ownerCredentials.password)")
        }
        print("NetBird dashboard: \(adminURL)")

        return setupKey
    }

    private func fetchBootstrapNetBirdInstanceStatus(managementURL: String) throws -> BootstrapNetBirdInstanceStatus {
        let requestURL = try bootstrapURL("\(managementURL)/api/instance")
        let response = try performJSONRequest(
            to: requestURL,
            method: "GET",
            headers: ["Accept": "application/json"]
        )

        return try decodeJSON(
            BootstrapNetBirdInstanceStatus.self,
            from: response.body,
            failureContext: "Could not decode NetBird instance status."
        )
    }

    private func createBootstrapNetBirdOwner(
        managementURL: String,
        credentials: BootstrapNetBirdOwnerCredentials
    ) throws {
        let requestURL = try bootstrapURL("\(managementURL)/api/setup")
        let payload = BootstrapNetBirdOwnerSetupRequest(
            email: credentials.email,
            password: credentials.password,
            name: credentials.name
        )
        _ = try performJSONRequest(
            to: requestURL,
            method: "POST",
            headers: [
                "Accept": "application/json",
                "Content-Type": "application/json",
            ],
            jsonBody: payload
        )
    }

    private func loginToBootstrapNetBirdOwner(
        adminURL: String,
        managementURL: String,
        credentials: BootstrapNetBirdOwnerCredentials
    ) throws -> String {
        let redirectURI = "\(adminURL)/nb-auth"
        let codeVerifier = randomBootstrapSecret(length: 48)
        var components = URLComponents(string: "\(managementURL)/oauth2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: "netbird-dashboard"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid profile email groups"),
            URLQueryItem(name: "state", value: randomBootstrapSecret(length: 24)),
            URLQueryItem(name: "code_challenge", value: codeVerifier),
            URLQueryItem(name: "code_challenge_method", value: "plain"),
        ]

        guard let authorizationURL = components?.url else {
            throw SetupError.commandFailed("Could not build the NetBird authorization URL.")
        }

        let loginPage = try performJSONRequest(
            to: authorizationURL,
            method: "GET",
            headers: ["Accept": "text/html"],
            followRedirects: true
        )
        let loginURL = loginPage.finalURL ?? authorizationURL
        let loginBody = formURLEncodedBody([
            "login": credentials.email,
            "password": credentials.password,
        ])
        let loginResponse = try performJSONRequest(
            to: loginURL,
            method: "POST",
            headers: [
                "Accept": "text/html",
                "Content-Type": "application/x-www-form-urlencoded",
            ],
            body: loginBody,
            followRedirects: false
        )

        guard let redirectLocation = loginResponse.redirectLocation,
              let redirectURL = URL(string: redirectLocation, relativeTo: loginURL),
              let code = URLComponents(url: redirectURL.absoluteURL, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value,
              !code.isEmpty
        else {
            throw SetupError.commandFailed("NetBird login succeeded but no authorization code was returned.")
        }

        let tokenBody = formURLEncodedBody([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": "netbird-dashboard",
            "client_secret": "",
            "code_verifier": codeVerifier,
        ])
        let tokenResponse = try performJSONRequest(
            to: try bootstrapURL("\(managementURL)/oauth2/token"),
            method: "POST",
            headers: [
                "Accept": "application/json",
                "Content-Type": "application/x-www-form-urlencoded",
            ],
            body: tokenBody
        )
        let payload = try decodeJSON(
            BootstrapNetBirdTokenResponse.self,
            from: tokenResponse.body,
            failureContext: "Could not decode the NetBird bootstrap access token."
        )

        guard !payload.accessToken.isEmpty else {
            throw SetupError.commandFailed("NetBird bootstrap login did not return an access token.")
        }
        return payload.accessToken
    }

    private func createBootstrapNetBirdSetupKey(
        managementURL: String,
        accessToken: String
    ) throws -> String {
        let requestURL = try bootstrapURL("\(managementURL)/api/setup-keys")
        let payload = BootstrapNetBirdSetupKeyRequest(
            name: "meshscale-bootstrap-agent",
            type: "reusable",
            expiresIn: bootstrapNetBirdSetupKeyTTL(),
            autoGroups: [],
            usageLimit: 0,
            ephemeral: false,
            allowExtraDNSLabels: true
        )
        let response = try performJSONRequest(
            to: requestURL,
            method: "POST",
            headers: [
                "Accept": "application/json",
                "Authorization": "Bearer \(accessToken)",
                "Content-Type": "application/json",
            ],
            jsonBody: payload
        )
        let setupKey = try decodeJSON(
            BootstrapNetBirdSetupKeyResponse.self,
            from: response.body,
            failureContext: "Could not decode the NetBird setup key creation response."
        )

        guard !setupKey.key.isEmpty else {
            throw SetupError.commandFailed("NetBird returned an empty setup key.")
        }
        return setupKey.key
    }

    private func bootstrapFoundationDBIfNeeded() throws -> (clusterFilePath: String, connectionString: String) {
        let directory = meshScaleHome
            .appendingPathComponent("foundationdb", isDirectory: true)
            .appendingPathComponent("bootstrap", isDirectory: true)
        let dataDirectory = directory.appendingPathComponent("data", isDirectory: true)
        let logsDirectory = directory.appendingPathComponent("logs", isDirectory: true)
        try fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        let clusterFile = directory.appendingPathComponent("cluster.fdb.cluster")
        if let adopted = adoptExistingFoundationDBCluster(into: clusterFile) {
            return adopted
        }

        if fileManager.fileExists(atPath: clusterFile.path),
           let existingConnectionString = try? String(contentsOf: clusterFile, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
           !existingConnectionString.isEmpty,
           foundationDBStatusHealthy(clusterFilePath: clusterFile.path) {
            return (clusterFilePath: clusterFile.path, connectionString: existingConnectionString)
        }

        let host = preferredFoundationDBBootstrapHost()
        let port = availableFoundationDBPort()
        let connectionString = "meshscale:meshscale@\(host):\(port)"
        if !fileManager.fileExists(atPath: clusterFile.path) ||
            (try? String(contentsOf: clusterFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)) != connectionString {
            try connectionString.write(to: clusterFile, atomically: true, encoding: .utf8)
        }

        if !foundationDBStatusHealthy(clusterFilePath: clusterFile.path) {
            let fdbserverPath = try resolveFoundationDBServerExecutable()
            let logFile = logsDirectory.appendingPathComponent("fdbserver.out")
            if !fileManager.fileExists(atPath: logFile.path) {
                _ = fileManager.createFile(atPath: logFile.path, contents: nil)
            }
            let serverDataDirectory = dataDirectory.appendingPathComponent(String(port), isDirectory: true)
            try fileManager.createDirectory(at: serverDataDirectory, withIntermediateDirectories: true)

            let escapedCommand = shellEscape(fdbserverPath)
            let escapedCluster = shellEscape(clusterFile.path)
            let escapedData = shellEscape(serverDataDirectory.path)
            let escapedLogs = shellEscape(logsDirectory.path)
            let escapedOutput = shellEscape(logFile.path)
            let launchCommand = """
            nohup \(escapedCommand) -C \(escapedCluster) --datadir \(escapedData) --logdir \(escapedLogs) --listen-address public --public-address \(host):\(port) --class storage --memory 2GiB --cache-memory 256MiB >> \(escapedOutput) 2>&1 &
            """
            try runInteractiveShell(launchCommand)

            try waitForFoundationDBConnection(clusterFilePath: clusterFile.path)
            _ = runQuietWithTimeout(
                ["fdbcli", "--cluster-file", clusterFile.path, "--exec", "configure new single memory"],
                timeout: 15
            )
            try waitForFoundationDB(clusterFilePath: clusterFile.path)
        }

        return (clusterFilePath: clusterFile.path, connectionString: connectionString)
    }

    private func adoptExistingFoundationDBCluster(into destinationClusterFile: URL) -> (clusterFilePath: String, connectionString: String)? {
        for candidate in foundationDBClusterFileCandidates() {
            guard fileManager.fileExists(atPath: candidate.path),
                  foundationDBStatusHealthy(clusterFilePath: candidate.path),
                  let connectionString = try? String(contentsOf: candidate, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !connectionString.isEmpty
            else {
                continue
            }

            if candidate.path != destinationClusterFile.path {
                try? connectionString.write(to: destinationClusterFile, atomically: true, encoding: .utf8)
            }
            return (clusterFilePath: destinationClusterFile.path, connectionString: connectionString)
        }

        return nil
    }

    private func foundationDBClusterFileCandidates() -> [URL] {
        var candidates: [URL] = []
        let environment = ProcessInfo.processInfo.environment
        let explicit = [
            environment["MESHCALE_FDB_CLUSTER_FILE"],
            environment["MESH_SCALE_FDB_CLUSTER_FILE"],
            environment["FOUNDATIONDB_CLUSTER_FILE"],
            environment["FDB_CLUSTER_FILE"],
        ].compactMap { $0 }.filter { !$0.isEmpty }
        candidates.append(contentsOf: explicit.map { URL(fileURLWithPath: $0) })

        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        candidates.append(
            contentsOf: [
                currentDirectory.appendingPathComponent(".meshscale/foundationdb/shared/fdb.cluster"),
                currentDirectory.appendingPathComponent("../.meshscale/foundationdb/shared/fdb.cluster"),
                URL(fileURLWithPath: "/usr/local/etc/foundationdb/fdb.cluster"),
                URL(fileURLWithPath: "/opt/homebrew/etc/foundationdb/fdb.cluster"),
                URL(fileURLWithPath: "/etc/foundationdb/fdb.cluster"),
            ]
        )

        var seen: Set<String> = []
        return candidates.filter { seen.insert($0.path).inserted }
    }

    private func foundationDBStatusHealthy(clusterFilePath: String) -> Bool {
        let result = runQuiet(["fdbcli", "--cluster-file", clusterFilePath, "--exec", "status minimal"])
        guard result.status == 0 else {
            return false
        }
        return !(result.stdout?.lowercased().contains("unavailable") ?? false)
    }

    private func resolveFoundationDBServerExecutable() throws -> String {
        let candidates = [
            "/usr/local/libexec/fdbserver",
            "/opt/homebrew/libexec/fdbserver",
            "/usr/sbin/fdbserver",
            "/usr/lib/foundationdb/fdbserver",
        ]
        if let candidate = candidates.first(where: { fileManager.fileExists(atPath: $0) }) {
            return candidate
        }
        throw SetupError.commandFailed("Could not locate the FoundationDB server executable for bootstrap.")
    }

    private func waitForFoundationDB(clusterFilePath: String) throws {
        for _ in 0..<30 {
            if foundationDBStatusHealthy(clusterFilePath: clusterFilePath) {
                return
            }
            Thread.sleep(forTimeInterval: 1)
        }
        throw SetupError.commandFailed("FoundationDB bootstrap cluster did not become ready in time.")
    }

    private func waitForFoundationDBConnection(clusterFilePath: String) throws {
        for _ in 0..<20 {
            let result = runQuiet(["fdbcli", "--cluster-file", clusterFilePath, "--exec", "status minimal"])
            if result.status == 0 || result.stdout != nil {
                return
            }
            Thread.sleep(forTimeInterval: 1)
        }
        throw SetupError.commandFailed("FoundationDB bootstrap server did not start responding in time.")
    }

    private func availableFoundationDBPort() -> Int {
        let candidates = [4689, 4701, 4702, 4703, 4710, 4711, 4712]
        for port in candidates where isTCPPortAvailable(port) {
            return port
        }
        return 4789
    }

    private func preferredFoundationDBBootstrapHost() -> String {
        let environment = ProcessInfo.processInfo.environment
        if let configured = environment["MESHCALE_BOOTSTRAP_FOUNDATIONDB_HOST"], !configured.isEmpty {
            return configured
        }

        let candidates: [[String]] = [
            ["sh", "-lc", "ipconfig getifaddr en0 2>/dev/null || true"],
            ["sh", "-lc", "ipconfig getifaddr en1 2>/dev/null || true"],
            ["sh", "-lc", "hostname -I 2>/dev/null | awk '{print $1}'"],
            ["sh", "-lc", "ip -4 addr show scope global 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n 1"],
        ]

        for command in candidates {
            if let output = runQuiet(command).stdout?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty,
               output != "127.0.0.1" {
                return output
            }
        }

        return "127.0.0.1"
    }

    private func preferredBootstrapNetBirdPublicHost() -> String {
        let environment = ProcessInfo.processInfo.environment
        if let configured = environment["MESHCALE_BOOTSTRAP_NETBIRD_PUBLIC_HOST"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !configured.isEmpty {
            return configured
        }

        if let configured = environment["MESHCALE_BOOTSTRAP_PUBLIC_HOST"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !configured.isEmpty {
            return configured
        }

        let metadataCandidates = [
            ["sh", "-lc", "token=$(curl -fsS -m 2 -X PUT 'http://169.254.169.254/latest/api/token' -H 'X-aws-ec2-metadata-token-ttl-seconds: 30' 2>/dev/null || true); if [ -n \"$token\" ]; then curl -fsS -m 2 -H \"X-aws-ec2-metadata-token: $token\" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true; else curl -fsS -m 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true; fi"],
            ["sh", "-lc", "token=$(curl -fsS -m 2 -X PUT 'http://169.254.169.254/latest/api/token' -H 'X-aws-ec2-metadata-token-ttl-seconds: 30' 2>/dev/null || true); if [ -n \"$token\" ]; then curl -fsS -m 2 -H \"X-aws-ec2-metadata-token: $token\" http://169.254.169.254/latest/meta-data/public-hostname 2>/dev/null || true; else curl -fsS -m 2 http://169.254.169.254/latest/meta-data/public-hostname 2>/dev/null || true; fi"],
        ]

        for command in metadataCandidates {
            if let output = runQuiet(command).stdout?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty,
               output != "127.0.0.1" {
                return output
            }
        }

        return preferredFoundationDBBootstrapHost()
    }

    private func isTCPPortAvailable(_ port: Int) -> Bool {
        runQuiet(["sh", "-lc", "lsof -i tcp:\(port) >/dev/null 2>&1"]).status != 0
    }

    private func shellEscape(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }

    private func runQuietWithTimeout(_ arguments: [String], timeout: TimeInterval) -> (status: Int32, stdout: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.1)
            }
            if process.isRunning {
                process.terminate()
                return (-1, nil)
            }
            let stdout = String(
                data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (process.terminationStatus, stdout)
        } catch {
            return (-1, nil)
        }
    }

    private func waitForHTTP(url: URL, expectedStatusPrefix: Int) throws {
        final class HTTPStatusBox: @unchecked Sendable {
            var responseCode: Int?
        }

        for _ in 0..<60 {
            let semaphore = DispatchSemaphore(value: 0)
            let box = HTTPStatusBox()
            URLSession.shared.dataTask(with: url) { _, response, _ in
                box.responseCode = (response as? HTTPURLResponse)?.statusCode
                semaphore.signal()
            }.resume()
            _ = semaphore.wait(timeout: .now() + 2)

            if let responseCode = box.responseCode,
               responseCode / 100 == expectedStatusPrefix / 100 {
                return
            }
            Thread.sleep(forTimeInterval: 1)
        }
        throw SetupError.commandFailed("Timed out waiting for \(url.absoluteString) during bootstrap.")
    }

    private func bootstrapNetBirdDashboardEnvironment(
        host: String,
        dashboardPort: Int,
        managementPort: Int
    ) -> [String: String] {
        let base = "http://\(host):\(managementPort)"
        return [
            "NETBIRD_MGMT_API_ENDPOINT": base,
            "NETBIRD_MGMT_GRPC_API_ENDPOINT": base,
            "AUTH_AUDIENCE": "netbird-dashboard",
            "AUTH_CLIENT_ID": "netbird-dashboard",
            "AUTH_CLIENT_SECRET": "",
            "AUTH_AUTHORITY": "\(base)/oauth2",
            "USE_AUTH0": "false",
            "AUTH_SUPPORTED_SCOPES": "openid profile email groups",
            "AUTH_REDIRECT_URI": "/nb-auth",
            "AUTH_SILENT_REDIRECT_URI": "/nb-silent-auth",
            "LETSENCRYPT_DOMAIN": "none",
            "NGINX_SSL_PORT": "443",
        ]
    }

    private func bootstrapNetBirdServerConfig(
        host: String,
        dashboardPort: Int,
        managementPort: Int
    ) -> String {
        let relaySecret = "meshscale-bootstrap-netbird-relay-secret"
        let encryptionSeed = netBirdEncryptionKey(seed: "\(host):\(managementPort)")
        return """
        server:
          listenAddress: ":80"
          exposedAddress: "http://\(host):\(managementPort)"
          stunPorts:
            - 3478
          metricsPort: 9090
          healthcheckAddress: ":9000"
          logLevel: "info"
          logFile: "console"
          authSecret: "\(relaySecret)"
          dataDir: "/var/lib/netbird"
          auth:
            issuer: "http://\(host):\(managementPort)/oauth2"
            signKeyRefreshEnabled: true
            dashboardRedirectURIs:
              - "http://localhost:\(dashboardPort)/nb-auth"
              - "http://localhost:\(dashboardPort)/nb-silent-auth"
              - "http://127.0.0.1:\(dashboardPort)/nb-auth"
              - "http://127.0.0.1:\(dashboardPort)/nb-silent-auth"
            cliRedirectURIs:
              - "http://localhost:53000/"
          store:
            engine: "sqlite"
            dsn: ""
            encryptionKey: "\(encryptionSeed)"
        """
    }

    private func netBirdEncryptionKey(seed: String) -> String {
        var bytes = Array(seed.utf8)
        if bytes.isEmpty {
            bytes = [0]
        }
        while bytes.count < 32 {
            bytes.append(contentsOf: bytes)
        }
        return Data(bytes.prefix(32)).base64EncodedString()
    }

    private func foundationDBHeaderPaths() -> [String] {
        [
            "/usr/local/include/foundationdb/fdb_c.h",
            "/opt/homebrew/include/foundationdb/fdb_c.h",
            "/usr/include/foundationdb/fdb_c.h",
        ]
    }

    private func foundationDBLibraryPaths() -> [String] {
        [
            "/usr/local/lib/libfdb_c.dylib",
            "/opt/homebrew/lib/libfdb_c.dylib",
            "/usr/lib/libfdb_c.so",
            "/usr/lib/x86_64-linux-gnu/libfdb_c.so",
            "/usr/lib64/libfdb_c.so",
        ]
    }

    private func runInteractiveShell(_ command: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-lc", command]
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw SetupError.installFailed(command)
        }
    }

    private func commandSucceeds(_ arguments: [String]) -> Bool {
        runQuiet(arguments).status == 0
    }

    private func bootstrapURL(_ rawValue: String) throws -> URL {
        guard let url = URL(string: rawValue) else {
            throw SetupError.commandFailed("Could not parse URL '\(rawValue)' during NetBird bootstrap.")
        }
        return url
    }

    private func decodeJSON<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        failureContext: String
    ) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw SetupError.commandFailed("\(failureContext) \(error.localizedDescription)")
        }
    }

    private func performJSONRequest<T: Encodable>(
        to url: URL,
        method: String,
        headers: [String: String],
        jsonBody: T,
        followRedirects: Bool = true
    ) throws -> BootstrapHTTPResponse {
        let body = try JSONEncoder().encode(jsonBody)
        return try performJSONRequest(
            to: url,
            method: method,
            headers: headers,
            body: body,
            followRedirects: followRedirects
        )
    }

    private func performJSONRequest(
        to url: URL,
        method: String,
        headers: [String: String],
        body: Data? = nil,
        followRedirects: Bool = true
    ) throws -> BootstrapHTTPResponse {
        let delegate = BootstrapHTTPRedirectDelegate(followRedirects: followRedirects)
        let session = URLSession(
            configuration: .ephemeral,
            delegate: delegate,
            delegateQueue: nil
        )
        defer {
            session.invalidateAndCancel()
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = BootstrapHTTPResultBox()
        let task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error {
                resultBox.result = .failure(error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                resultBox.result = .failure(
                    SetupError.commandFailed("Bootstrap request to \(url.absoluteString) did not return an HTTP response.")
                )
                return
            }

            let responseBody = data ?? Data()
            let bootstrapResponse = BootstrapHTTPResponse(
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields.reduce(into: [:]) { partialResult, item in
                    guard let key = item.key as? String, let value = item.value as? String else {
                        return
                    }
                    partialResult[key] = value
                },
                body: responseBody,
                finalURL: httpResponse.url,
                redirectLocation: delegate.redirectLocation
            )

            if (200..<400).contains(httpResponse.statusCode) {
                resultBox.result = .success(bootstrapResponse)
                return
            }

            let bodyText = String(data: responseBody, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty ?? "HTTP \(httpResponse.statusCode)"
            resultBox.result = .failure(
                SetupError.commandFailed(
                    "Bootstrap request to \(url.absoluteString) failed with HTTP \(httpResponse.statusCode): \(bodyText)"
                )
            )
        }
        task.resume()

        _ = semaphore.wait(timeout: .now() + 20)

        guard let result = resultBox.result else {
            task.cancel()
            throw SetupError.commandFailed("Timed out while talking to the local NetBird bootstrap API.")
        }

        return try result.get()
    }

    private func formURLEncodedBody(_ values: [String: String]) -> Data {
        let query = values.map { key, value in
            "\(urlEncodeFormComponent(key))=\(urlEncodeFormComponent(value))"
        }.joined(separator: "&")
        return Data(query.utf8)
    }

    private func urlEncodeFormComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._* "))
        return value
            .addingPercentEncoding(withAllowedCharacters: allowed)?
            .replacingOccurrences(of: " ", with: "+")
            ?? value
    }

    private func bootstrapNetBirdOwnerCredentials(
        hostname: String,
        allowGeneratedValues: Bool
    ) throws -> BootstrapNetBirdOwnerCredentials {
        let environment = ProcessInfo.processInfo.environment
        let sanitizedHost = hostname
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let hostLabel = sanitizedHost.isEmpty ? "meshscale" : sanitizedHost
        let configuredEmail = (environment["MESHCALE_BOOTSTRAP_NETBIRD_ADMIN_EMAIL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty)
        let configuredPassword = (environment["MESHCALE_BOOTSTRAP_NETBIRD_ADMIN_PASSWORD"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty)
        let configuredName = (environment["MESHCALE_BOOTSTRAP_NETBIRD_ADMIN_NAME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty)

        let promptInteractively = ProcessInfo.processInfo.environment["CI"] != "true"
        let defaultEmail = "admin@\(hostLabel).meshscale.local"

        let email: String
        if let configuredEmail {
            email = configuredEmail
        } else if promptInteractively {
            email = prompt(
                label: "NetBird bootstrap admin email",
                example: defaultEmail,
                defaultValue: defaultEmail,
                allowEmpty: false
            ) ?? defaultEmail
        } else if allowGeneratedValues {
            email = defaultEmail
        } else {
            throw SetupError.commandFailed(
                "The local NetBird instance is already initialized, but MeshScale could not determine the NetBird bootstrap admin email. " +
                "Set MESHCALE_BOOTSTRAP_NETBIRD_ADMIN_EMAIL or rerun setup interactively."
            )
        }

        let password: String
        if let configuredPassword {
            password = configuredPassword
        } else if promptInteractively {
            password = promptSecret(
                label: "NetBird bootstrap admin password",
                example: "choose a password for the local NetBird owner",
                allowEmpty: false
            ) ?? ""
        } else if allowGeneratedValues {
            password = randomBootstrapSecret(length: 24)
        } else {
            throw SetupError.commandFailed(
                "The local NetBird instance is already initialized, but MeshScale could not determine the NetBird bootstrap admin password. " +
                "Set MESHCALE_BOOTSTRAP_NETBIRD_ADMIN_PASSWORD or rerun setup interactively."
            )
        }

        let name = configuredName ?? "MeshScale Bootstrap Admin"

        return BootstrapNetBirdOwnerCredentials(
            email: email,
            password: password,
            name: name,
            shouldEchoCredentials: allowGeneratedValues || (configuredEmail != nil && configuredPassword != nil)
        )
    }

    private func bootstrapNetBirdSetupKeyTTL() -> Int {
        if let rawValue = ProcessInfo.processInfo.environment["MESHCALE_BOOTSTRAP_NETBIRD_SETUP_KEY_TTL_SECONDS"],
           let ttl = Int(rawValue),
           ttl > 0 {
            return ttl
        }
        return 60 * 60 * 24 * 365
    }

    private func ensureNetBirdServiceRunningForSetup() throws {
        if commandSucceeds(["netbird", "status", "--json"]) || commandSucceeds(["netbird", "status"]) {
            return
        }

        #if os(macOS) || os(Linux)
        try runInteractiveShell("netbird service install || true")
        try runInteractiveShell("netbird service start")
        #endif
    }

    private func randomBootstrapSecret(length: Int) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        guard !alphabet.isEmpty else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }

        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in
            alphabet[Int.random(in: 0..<alphabet.count, using: &generator)]
        })
    }

    private func commandOutput(_ arguments: [String]) -> String? {
        let result = runQuiet(arguments)
        guard result.status == 0 else {
            return nil
        }
        return result.stdout
    }

    private func runQuiet(_ arguments: [String]) -> (status: Int32, stdout: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
            let stdout = String(
                data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (process.terminationStatus, stdout)
        } catch {
            return (-1, nil)
        }
    }

    private func currentArchitecture() -> String {
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
}

extension MeshScaleCLI {
    struct Setup: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "setup",
            abstract: "Install mandatory host prerequisites for MeshScale roles"
        )

        @Option(name: .long, parsing: .upToNextOption, help: "Role(s) to prepare: control-plane, worker. Defaults to both.")
        var role: [String] = []

        @Flag(name: .long, help: "Only check and print prerequisite status without installing anything.")
        var check: Bool = false

        @Flag(name: .long, help: "Initialize the first MeshScale cluster without prompting for remote NetBird or FoundationDB endpoints.")
        var bootstrapCluster: Bool = false

        func run() throws {
            try assertRunningUnderSudoIfNeeded()
            let roles = try resolvedRoles()

            if check {
                try printStatus(for: roles)
                return
            }

            print("Running mandatory MeshScale setup...")
            for role in roles {
                let dependencies = role.requiredDependencies.map(\.displayName).joined(separator: ", ")
                print("- \(role.displayName): \(dependencies)")
            }

            try SetupManager.shared.runSetup(for: roles, bootstrapCluster: bootstrapCluster)
            try printStatus(for: roles)
        }

        private func assertRunningUnderSudoIfNeeded() throws {
            guard !check else {
                return
            }

            guard currentEffectiveUserID() != 0 else {
                return
            }

            throw SetupError.commandFailed(
                """
                MeshScale setup must be started through real sudo.
                Run:
                  sudo \(CommandLine.arguments.joined(separator: " "))
                """
            )
        }

        private func currentEffectiveUserID() -> UInt32 {
            #if os(macOS)
            return geteuid()
            #elseif os(Linux)
            return geteuid()
            #else
            return 0
            #endif
        }

        private func resolvedRoles() throws -> [MeshScaleSetupRole] {
            if role.isEmpty {
                return MeshScaleSetupRole.allCases
            }
            return try role.map(MeshScaleSetupRole.parse(_:))
        }

        private func printStatus(for roles: [MeshScaleSetupRole]) throws {
            for role in roles {
                let statuses = SetupManager.shared.dependencyStatuses(for: role)
                let allInstalled = statuses.allSatisfy(\.installed)
                print("\(allInstalled ? "✅" : "❌") \(role.displayName)")
                for status in statuses {
                    print("  - \(status.dependency.displayName): \(status.installed ? "installed" : "missing") \(status.detail)")
                }
                if let record = SetupManager.shared.loadState()?.roles[role.rawValue] {
                    if let managementURL = record.details.netBirdManagementURL, !managementURL.isEmpty {
                        print("  - NetBird URL: \(managementURL)")
                    }
                    if role == .controlPlane,
                       let clusterFilePath = record.details.foundationDBClusterFilePath,
                       !clusterFilePath.isEmpty {
                        print("  - FoundationDB cluster file: \(clusterFilePath)")
                    }
                    print("  - Setup completed at: \(record.completedAt.ISO8601Format())")
                } else {
                    print("  - Setup record: missing (run 'meshscale setup --role \(role.rawValue)')")
                }
            }
        }
    }
}

private struct BootstrapNetBirdInstanceStatus: Decodable {
    let setupRequired: Bool

    private enum CodingKeys: String, CodingKey {
        case setupRequired = "setup_required"
    }
}

private struct BootstrapNetBirdOwnerCredentials {
    let email: String
    let password: String
    let name: String
    let shouldEchoCredentials: Bool
}

private struct BootstrapNetBirdOwnerSetupRequest: Encodable {
    let email: String
    let password: String
    let name: String
}

private struct BootstrapNetBirdTokenResponse: Decodable {
    let accessToken: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

private struct BootstrapNetBirdSetupKeyRequest: Encodable {
    let name: String
    let type: String
    let expiresIn: Int
    let autoGroups: [String]
    let usageLimit: Int
    let ephemeral: Bool
    let allowExtraDNSLabels: Bool

    private enum CodingKeys: String, CodingKey {
        case name
        case type
        case expiresIn = "expires_in"
        case autoGroups = "auto_groups"
        case usageLimit = "usage_limit"
        case ephemeral
        case allowExtraDNSLabels = "allow_extra_dns_labels"
    }
}

private struct BootstrapNetBirdSetupKeyResponse: Decodable {
    let key: String
}

private struct BootstrapHTTPResponse: Sendable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
    let finalURL: URL?
    let redirectLocation: String?
}

private final class BootstrapHTTPResultBox: @unchecked Sendable {
    var result: Result<BootstrapHTTPResponse, Error>?
}

private final class BootstrapHTTPRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let followRedirects: Bool
    private(set) var redirectLocation: String?

    init(followRedirects: Bool) {
        self.followRedirects = followRedirects
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        redirectLocation = request.url?.absoluteString
        completionHandler(followRedirects ? request : nil)
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
