import Foundation

public enum NetBirdRole: String, Sendable {
    case controlPlane = "CONTROL_PLANE"
    case worker = "WORKER"
}

public struct NetBirdConfiguration: Codable, Equatable, Sendable {
    public let enabled: Bool
    public let required: Bool
    public let setupKey: String?
    public let managementURL: String?
    public let adminURL: String?
    public let hostname: String?
    public let configPath: String?
    public let daemonAddress: String?

    public init(
        enabled: Bool = false,
        required: Bool = false,
        setupKey: String? = nil,
        managementURL: String? = nil,
        adminURL: String? = nil,
        hostname: String? = nil,
        configPath: String? = nil,
        daemonAddress: String? = nil
    ) {
        self.enabled = enabled
        self.required = required
        self.setupKey = setupKey
        self.managementURL = managementURL
        self.adminURL = adminURL
        self.hostname = hostname
        self.configPath = configPath
        self.daemonAddress = daemonAddress
    }

    public static func fromEnvironment(
        role: NetBirdRole,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> NetBirdConfiguration {
        func value(_ key: String) -> String? {
            environment["MESHCALE_\(role.rawValue)_NETBIRD_\(key)"]
                ?? environment["MESHCALE_NETBIRD_\(key)"]
        }

        let setupKey = value("SETUP_KEY")
        let managementURL = value("MANAGEMENT_URL")
        let adminURL = value("ADMIN_URL")
        let hostname = value("HOSTNAME")
        let configPath = value("CONFIG_PATH")
        let daemonAddress = value("DAEMON_ADDR")
        let enabled = parseBool(value("ENABLED"))
            ?? (setupKey != nil || managementURL != nil || adminURL != nil)
        let required = parseBool(value("REQUIRED")) ?? enabled

        return NetBirdConfiguration(
            enabled: enabled,
            required: required,
            setupKey: setupKey,
            managementURL: managementURL,
            adminURL: adminURL,
            hostname: hostname,
            configPath: configPath,
            daemonAddress: daemonAddress
        )
    }
}

public struct NetBirdStatus: Codable, Sendable {
    public let enabled: Bool
    public let required: Bool
    public let connected: Bool
    public let ipv4: String?
    public let managementURL: String?
    public let adminURL: String?
    public let hostname: String?
    public let serviceStatus: String?
    public let detail: String?
    public let lastError: String?

    public init(
        enabled: Bool,
        required: Bool,
        connected: Bool,
        ipv4: String?,
        managementURL: String?,
        adminURL: String?,
        hostname: String?,
        serviceStatus: String?,
        detail: String?,
        lastError: String?
    ) {
        self.enabled = enabled
        self.required = required
        self.connected = connected
        self.ipv4 = ipv4
        self.managementURL = managementURL
        self.adminURL = adminURL
        self.hostname = hostname
        self.serviceStatus = serviceStatus
        self.detail = detail
        self.lastError = lastError
    }
}

private struct NetBirdStatusJSON: Decodable {
    struct Management: Decodable {
        let url: String?
        let connected: Bool?
        let error: String?
    }

    let management: Management?
}

public struct NetBirdError: LocalizedError, Sendable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}

public final class NetBirdClient: @unchecked Sendable {
    public let configuration: NetBirdConfiguration
    private let logger: (@Sendable (String) -> Void)?
    private let executable: String

    public init(
        configuration: NetBirdConfiguration,
        executable: String = "netbird",
        logger: (@Sendable (String) -> Void)? = nil
    ) {
        self.configuration = configuration
        self.executable = executable
        self.logger = logger
    }

    public func ensureConnected() throws -> NetBirdStatus {
        let initial = currentStatus()
        guard configuration.enabled else {
            return initial
        }
        if initial.connected {
            return initial
        }

        if requiresReconnect(for: initial) {
            let downResult = run(["down"])
            if downResult.status != 0, let message = downResult.message, !message.isEmpty {
                logger?("NetBird down returned: \(message)")
            }
        }

        let serviceStart = run(["service", "start"])
        if serviceStart.status != 0, let message = serviceStart.message, !message.isEmpty {
            logger?("NetBird service start returned: \(message)")
        }

        let afterServiceStart = currentStatus()
        if afterServiceStart.connected {
            return afterServiceStart
        }

        if let setupKey = configuration.setupKey, !setupKey.isEmpty {
            let upResult = run(upArguments(setupKey: setupKey))
            if upResult.status != 0, let message = upResult.message, !message.isEmpty {
                logger?("NetBird up failed: \(message)")
            }
        }

        let final = currentStatus()
        if configuration.required && !final.connected {
            throw NetBirdError(
                final.lastError
                    ?? "NetBird is required but MeshScale could not establish a NetBird connection."
            )
        }

        return final
    }

    public func currentStatus() -> NetBirdStatus {
        guard configuration.enabled else {
            return NetBirdStatus(
                enabled: false,
                required: configuration.required,
                connected: false,
                ipv4: nil,
                managementURL: configuration.managementURL,
                adminURL: configuration.adminURL,
                hostname: configuration.hostname,
                serviceStatus: nil,
                detail: "NetBird is disabled for this MeshScale process.",
                lastError: nil
            )
        }

        let service = run(["service", "status"])
        let ipv4Result = run(["status", "--ipv4"])
        let detailResult = run(["status", "--json"])
        let ipv4 = ipv4Result.stdout?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
        let detail = detailResult.stdout?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        let parsedStatus = parseStatusJSON(from: detail)
        let activeManagementURL = normalizedURLString(parsedStatus?.management?.url)
        let requestedManagementURL = normalizedURLString(configuration.managementURL)
        let managementMatches = requestedManagementURL == nil || activeManagementURL == requestedManagementURL
        let managementConnected = parsedStatus?.management?.connected ?? false
        let connected = ipv4Result.status == 0 && ipv4 != nil && managementMatches && managementConnected

        var errorMessages = [ipv4Result.stderr, detailResult.stderr, service.stderr]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty }
        if !managementMatches,
           let requestedManagementURL,
           let activeManagementURL {
            errorMessages.append("NetBird is connected to \(activeManagementURL) instead of \(requestedManagementURL).")
        }
        if let managementError = parsedStatus?.management?.error?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            errorMessages.append(managementError)
        }
        let error = errorMessages
            .joined(separator: "\n")
            .nonEmpty

        return NetBirdStatus(
            enabled: true,
            required: configuration.required,
            connected: connected,
            ipv4: ipv4,
            managementURL: activeManagementURL ?? configuration.managementURL,
            adminURL: configuration.adminURL,
            hostname: configuration.hostname ?? ProcessInfo.processInfo.hostName,
            serviceStatus: service.message,
            detail: detail,
            lastError: error
        )
    }

    public func preferredBindAddress(defaultHost: String = "0.0.0.0") throws -> String {
        let status = try ensureConnected()
        if let ipv4 = status.ipv4, status.connected {
            return ipv4
        }
        return defaultHost
    }

    private func upArguments(setupKey: String) -> [String] {
        var args = ["up", "--setup-key", setupKey, "--no-browser"]

        if let managementURL = configuration.managementURL, !managementURL.isEmpty {
            args += ["--management-url", managementURL]
        }
        if let adminURL = configuration.adminURL, !adminURL.isEmpty {
            args += ["--admin-url", adminURL]
        }
        if let hostname = configuration.hostname, !hostname.isEmpty {
            args += ["--hostname", hostname]
        }

        return args
    }

    private func run(_ arguments: [String]) -> (status: Int32, stdout: String?, stderr: String?, message: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + globalArguments() + arguments

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
            let stderr = String(
                data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = [stdout, stderr]
                .compactMap { $0?.nonEmpty }
                .joined(separator: "\n")
                .nonEmpty
            return (process.terminationStatus, stdout, stderr, message)
        } catch {
            return (-1, nil, error.localizedDescription, error.localizedDescription)
        }
    }

    private func globalArguments() -> [String] {
        var args: [String] = []
        if let configPath = configuration.configPath, !configPath.isEmpty {
            args += ["--config", configPath]
        }
        if let daemonAddress = configuration.daemonAddress, !daemonAddress.isEmpty {
            args += ["--daemon-addr", daemonAddress]
        }
        return args
    }

    private func parseStatusJSON(from rawValue: String?) -> NetBirdStatusJSON? {
        guard let rawValue, let data = rawValue.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(NetBirdStatusJSON.self, from: data)
    }

    private func requiresReconnect(for status: NetBirdStatus) -> Bool {
        guard let requestedManagementURL = normalizedURLString(configuration.managementURL),
              let activeManagementURL = normalizedURLString(status.managementURL) else {
            return false
        }
        return requestedManagementURL != activeManagementURL
    }

    private func normalizedURLString(_ rawValue: String?) -> String? {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty else {
            return nil
        }
        guard let components = URLComponents(string: rawValue) else {
            return rawValue
        }

        var normalized = components.scheme?.lowercased() ?? ""
        if !normalized.isEmpty {
            normalized += "://"
        }
        normalized += components.host?.lowercased() ?? rawValue
        if let port = components.port {
            normalized += ":\(port)"
        }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !path.isEmpty {
            normalized += "/\(path)"
        }
        return normalized
    }
}

private func parseBool(_ value: String?) -> Bool? {
    guard let value else {
        return nil
    }

    switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "1", "true", "yes", "on":
        return true
    case "0", "false", "no", "off":
        return false
    default:
        return nil
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
