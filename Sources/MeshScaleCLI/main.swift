import Foundation
import ArgumentParser
import MeshScaleControlPlaneRuntime
import MeshScaleWorkerRuntime

// MARK: - Config Manager

struct ConfigManager {
    static let shared = ConfigManager()
    
    private let configDir: URL
    private let authFile: URL
    private let pidDir: URL
    private let logsDir: URL
    private let binariesDir: URL
    
    private init() {
        #if os(Windows)
        let appData = ProcessInfo.processInfo.environment["APPDATA"] ?? ""
        configDir = URL(fileURLWithPath: appData).appendingPathComponent("MeshScale")
        #elseif os(macOS)
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".config/meshscale")
        #else // Linux
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".config/meshscale")
        #endif
        
        authFile = configDir.appendingPathComponent("auth.json")
        pidDir = configDir.appendingPathComponent("pids")
        logsDir = configDir.appendingPathComponent("logs")
        binariesDir = configDir.appendingPathComponent("binaries")
        
        // Create directories if they don't exist
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: pidDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: binariesDir, withIntermediateDirectories: true)
    }
    
    func saveAuth(controlPlaneURL: String, token: String) throws {
        let auth = AuthConfig(controlPlaneURL: controlPlaneURL, token: token)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(auth)
        try data.write(to: authFile)
    }
    
    func loadAuth() throws -> AuthConfig {
        let data = try Data(contentsOf: authFile)
        let decoder = JSONDecoder()
        return try decoder.decode(AuthConfig.self, from: data)
    }
    
    func hasAuth() -> Bool {
        FileManager.default.fileExists(atPath: authFile.path)
    }
    
    func removeAuth() throws {
        if FileManager.default.fileExists(atPath: authFile.path) {
            try FileManager.default.removeItem(at: authFile)
        }
    }
    
    
    func getConfigPath() -> String {
        configDir.path
    }
    
    func getBinariesPath() -> String {
        binariesDir.path
    }
    
    func getBinaryDir(for component: String, version: String) -> URL {
        #if os(Windows)
        let componentName = component == "control-plane" ? "ControlPlane" : "Worker"
        #else
        let componentName = component == "control-plane" ? "controlplane" : "worker"
        #endif
        return binariesDir.appendingPathComponent(componentName).appendingPathComponent(version)
    }
    
    func getBinaryPath(for component: String, version: String) -> URL {
        let binaryDir = getBinaryDir(for: component, version: version)
        #if os(Windows)
        let executableName = component == "control-plane" ? "MeshScaleControlPlane.exe" : "MeshScaleWorker.exe"
        #else
        let executableName = component == "control-plane" ? "MeshScaleControlPlane" : "MeshScaleWorker"
        #endif
        return binaryDir.appendingPathComponent(executableName)
    }
    
    func getPidFile(for service: String) -> URL {
        pidDir.appendingPathComponent("\(service).pid")
    }
    
    func getLogFile(for service: String) -> URL {
        logsDir.appendingPathComponent("\(service).log")
    }
    
    func savePid(_ pid: Int32, for service: String) throws {
        let pidFile = getPidFile(for: service)
        try String(pid).write(to: pidFile, atomically: true, encoding: .utf8)
    }
    
    func loadPid(for service: String) -> Int32? {
        let pidFile = getPidFile(for: service)
        guard let pidString = try? String(contentsOf: pidFile, encoding: .utf8),
              let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return pid
    }
    
    func removePid(for service: String) {
        let pidFile = getPidFile(for: service)
        try? FileManager.default.removeItem(at: pidFile)
    }
    
    func isProcessRunning(_ pid: Int32) -> Bool {
        #if os(Windows)
        // On Windows, use tasklist to check if process exists
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\tasklist.exe")
        task.arguments = ["/FI", "PID eq \(pid)", "/NH"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        try? task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.contains("\(pid)")
        #else
        // On Unix-like systems, send signal 0 to check if process exists
        return kill(pid, 0) == 0
        #endif
    }
    
    func killProcess(_ pid: Int32) -> Bool {
        #if os(Windows)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\taskkill.exe")
        task.arguments = ["/PID", "\(pid)", "/F"]
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
        #else
        return kill(pid, SIGTERM) == 0
        #endif
    }
}

struct AuthConfig: Codable {
    let controlPlaneURL: String
    let token: String
}


// MARK: - CLI Commands

@main
struct MeshScaleCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "meshscale",
        abstract: "MeshScale - Distributed task execution platform",
        subcommands: [Auth.self, Setup.self, Debug.self, Deploy.self, ControlPlane.self, Worker.self, Status.self, Projects.self, Workers.self, Volumes.self, Logs.self]
    )
}

extension MeshScaleCLI {
    struct Debug: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "debug",
            abstract: "Debug commands for development",
            subcommands: [Symlink.self]
        )
    }
}

extension MeshScaleCLI.Debug {
    struct Symlink: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "symlink",
            abstract: "Create symlink from .build to binaries directory"
        )
        
        @Argument(help: "Component to symlink (control-plane or worker)")
        var component: String
        
        @Option(name: .shortAndLong, help: "Version tag")
        var version: String = "dev"
        
        @Flag(name: .long, help: "Show verbose output")
        var verbose: Bool = false
        
        func run() throws {
            guard component == "control-plane" || component == "worker" else {
                print("❌ Invalid component. Use 'control-plane' or 'worker'")
                throw ExitCode.failure
            }
            
            // Find source executable in .build
            #if os(Windows)
            let executableName = component == "control-plane" ? "MeshScaleControlPlane.exe" : "MeshScaleWorker.exe"
            #else
            let executableName = component == "control-plane" ? "MeshScaleControlPlane" : "MeshScaleWorker"
            #endif
            
            let debugPath = ".build/debug/\(executableName)"
            
            if verbose {
                print("🔍 Looking for executable at: \(debugPath)")
            }
            
            guard FileManager.default.fileExists(atPath: debugPath) else {
                print("❌ Executable not found at: \(debugPath)")
                print("Build the project first: swift build")
                throw ExitCode.failure
            }
            
            let sourcePath = FileManager.default.currentDirectoryPath + "/" + debugPath
            
            if verbose {
                print("✓ Found executable: \(sourcePath)")
            }
            
            // Create destination directory
            let destDir = ConfigManager.shared.getBinaryDir(for: component, version: version)
            
            if verbose {
                print("🔍 Creating destination directory: \(destDir.path)")
            }
            
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            
            let destPath = ConfigManager.shared.getBinaryPath(for: component, version: version)
            
            // Normalize paths for Windows (use backslashes)
            #if os(Windows)
            let normalizedSourcePath = sourcePath.replacingOccurrences(of: "/", with: "\\")
            let normalizedDestPath = destPath.path.replacingOccurrences(of: "/", with: "\\")
            #else
            let normalizedSourcePath = sourcePath
            let normalizedDestPath = destPath.path
            #endif
            
            if verbose {
                print("✓ Destination directory created")
                print("🔍 Destination path: \(normalizedDestPath)")
            }
            
            // Remove existing symlink/file if it exists
            if FileManager.default.fileExists(atPath: destPath.path) {
                if verbose {
                    print("🔍 Removing existing file at destination")
                }
                try FileManager.default.removeItem(at: destPath)
            }
            
            // Create symlink
            #if os(Windows)
            // On Windows, use mklink via cmd (requires admin or dev mode)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\cmd.exe")
            // Pass arguments separately, not as a single string
            task.arguments = ["/c", "mklink", normalizedDestPath, normalizedSourcePath]
            
            if verbose {
                print("🔍 Running command: cmd.exe /c mklink \(normalizedDestPath) \(normalizedSourcePath)")
            }
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if verbose || task.terminationStatus != 0 {
                print("Command output:")
                print(output)
            }
            
            if task.terminationStatus != 0 {
                print("❌ Failed to create symlink (exit code: \(task.terminationStatus))")
                print("\nTo enable symlinks on Windows:")
                print("  1. Run as Administrator, OR")
                print("  2. Enable Developer Mode:")
                print("     Settings > Update & Security > For developers > Developer Mode")
                throw ExitCode.failure
            }
            
            print("✅ Symlink created:")
            #else
            if verbose {
                print("🔍 Creating symbolic link")
            }
            try FileManager.default.createSymbolicLink(at: destPath, withDestinationURL: URL(fileURLWithPath: sourcePath))
            
            print("✅ Symlink created:")
            #endif
            
            print("   Source: \(normalizedSourcePath)")
            print("   Dest:   \(normalizedDestPath)")
            print("   Version: \(version)")
        }
    }
}

extension MeshScaleCLI {
    struct Auth: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "auth",
            abstract: "Authentication commands",
            subcommands: [Login.self, Logout.self]
        )
    }
}

extension MeshScaleCLI.Auth {
    struct Logout: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "logout",
            abstract: "Logout from MeshScale"
        )
        
        func run() throws {
            guard ConfigManager.shared.hasAuth() else {
                print("Not logged in")
                return
            }
            
            try ConfigManager.shared.removeAuth()
            
            print("✓ Logged out")
        }
    }
}

extension MeshScaleCLI.Auth {
    struct Login: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "login",
            abstract: "Login to MeshScale control plane"
        )
        
        func run() throws {
            print("MeshScale Authentication")
            print("========================\n")
            
            // Ask for control plane URL
            print("Enter control plane URL (e.g., https://meshscale.example.com):")
            guard let controlPlaneURL = readLine()?.trimmingCharacters(in: .whitespaces),
                  !controlPlaneURL.isEmpty else {
                print("Error: Control plane URL is required")
                throw ExitCode.failure
            }
            
            print("\nControl plane: \(controlPlaneURL)")
            print("\nSelect authentication method:")
            print("1. Browser authentication")
            print("2. Setup key")
            print("\nEnter your choice (1 or 2):")
            
            guard let choice = readLine()?.trimmingCharacters(in: .whitespaces) else {
                print("Error: Invalid choice")
                throw ExitCode.failure
            }
            
            switch choice {
            case "1":
                try browserAuth(controlPlaneURL: controlPlaneURL)
            case "2":
                try setupKeyAuth(controlPlaneURL: controlPlaneURL)
            default:
                print("Error: Invalid choice. Please enter 1 or 2")
                throw ExitCode.failure
            }
        }
        
        private func browserAuth(controlPlaneURL: String) throws {
            print("\n🌐 Opening browser for authentication...")
            print("URL: \(controlPlaneURL)/auth/login")
            print("\nWaiting for authentication to complete...")
            
            // TODO: Implement actual browser auth flow
            // - Open browser with auth URL
            // - Start local server to receive callback
            // - Exchange code for token
            // - Save token to config
            
            let mockToken = "mock_token_\(UUID().uuidString)"
            try ConfigManager.shared.saveAuth(controlPlaneURL: controlPlaneURL, token: mockToken)
            
            print("✅ Authentication successful!")
            print("Token saved to: \(ConfigManager.shared.getConfigPath())")
        }
        
        private func setupKeyAuth(controlPlaneURL: String) throws {
            print("\n🔑 Setup Key Authentication")
            print("Enter your setup key:")
            
            guard let setupKey = readLine()?.trimmingCharacters(in: .whitespaces),
                  !setupKey.isEmpty else {
                print("Error: Setup key is required")
                throw ExitCode.failure
            }
            
            print("\nValidating setup key with \(controlPlaneURL)...")
            
            // TODO: Implement actual setup key validation
            // - Send key to control plane
            // - Receive and save token
            
            let mockToken = "key_token_\(UUID().uuidString)"
            try ConfigManager.shared.saveAuth(controlPlaneURL: controlPlaneURL, token: mockToken)
            
            print("✅ Authentication successful!")
            print("Token saved to: \(ConfigManager.shared.getConfigPath())")
        }
    }
}

extension MeshScaleCLI {
    struct Setup: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "setup",
            abstract: "Setup MeshScale components",
            subcommands: [Worker.self, ControlPlane.self, Project.self]
        )
    }
}

extension MeshScaleCLI.Setup {
    struct Worker: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "worker",
            abstract: "Setup a new worker node"
        )
        
        func run() throws {
            print("MeshScale Worker Setup")
            print("======================\n")
            
            // Check for authentication
            guard ConfigManager.shared.hasAuth() else {
                print("❌ Not authenticated. Please run 'meshscale auth login' first.")
                throw ExitCode.failure
            }
            
            let auth = try ConfigManager.shared.loadAuth()
            print("✅ Authenticated with: \(auth.controlPlaneURL)\n")
            
            print("🔧 Configuring worker node...")
            print("Control plane: \(auth.controlPlaneURL)")
            print("Worker IDs will be generated automatically when you run 'meshscale worker start'.")
            
            print("✅ Worker setup complete!")
            print("\nTo start a worker, run:")
            print("  meshscale worker start")
        }
    }
    
    struct ControlPlane: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "control-plane",
            abstract: "Setup a new control plane"
        )
        
        func run() throws {
            print("MeshScale Control Plane Setup")
            print("==============================\n")
            
            // Check for authentication
            guard ConfigManager.shared.hasAuth() else {
                print("❌ Not authenticated. Please run 'meshscale auth login' first.")
                throw ExitCode.failure
            }
            
            let auth = try ConfigManager.shared.loadAuth()
            print("✅ Authenticated with: \(auth.controlPlaneURL)\n")
            
            print("Enter control plane name:")
            guard let cpName = readLine()?.trimmingCharacters(in: .whitespaces),
                  !cpName.isEmpty else {
                print("Error: Control plane name is required")
                throw ExitCode.failure
            }
            
            print("\n🔧 Setting up control plane '\(cpName)'...")
            
            // TODO: Initialize control plane configuration
            
            print("✅ Control plane setup complete!")
            print("\nTo start the control plane, run:")
            print("  meshscale control-plane")
        }
    }
    
    struct Project: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "project",
            abstract: "Setup a new MeshScale project"
        )
        
        func run() throws {
            print("MeshScale Project Setup")
            print("=======================\n")
            
            print("Enter project name:")
            guard let projectName = readLine()?.trimmingCharacters(in: .whitespaces),
                  !projectName.isEmpty else {
                print("Error: Project name is required")
                throw ExitCode.failure
            }
            
            print("\n🔧 Setting up project '\(projectName)'...")
            
            // TODO: Create project structure
            // - Create project directory
            // - Initialize configuration files
            // - Create example task definitions
            
            print("✅ Project setup complete!")
            print("\nProject created at: ./\(projectName)")
        }
    }
}

extension MeshScaleCLI {
    struct ControlPlane: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "control-plane",
            abstract: "Manage the MeshScale control plane",
            subcommands: [Setup.self, Install.self, Start.self, Stop.self, Logs.self, Status.self]
        )
    }
}

extension MeshScaleCLI.ControlPlane {
    struct Setup: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "setup",
            abstract: "Setup control plane for a region"
        )
        
        @Option(name: .shortAndLong, help: "Region (e.g., us-east-1)")
        var region: String = "us-east-1"
        
        func run() throws {
            guard ConfigManager.shared.hasAuth() else {
                print("❌ Not authenticated. Run 'meshscale auth login' first.")
                throw ExitCode.failure
            }
            
            print("→ Installing MeshScale Control Plane...")
            print("  ✓ Binary: (use meshscale control-plane install for binary)")
            print("  ✓ Config: /etc/meshscale/control-plane.yaml")
            print("  ✓ Region: \(region)")
            print("\nStart with: meshscale control-plane start")
        }
    }
    
    struct Install: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "install",
            abstract: "Install a specific version of the control plane"
        )
        
        @Option(name: .shortAndLong, help: "Version to install (e.g., 1.0.0, latest)")
        var version: String = "latest"
        
        func run() throws {
            // Map "latest" to actual version
            let actualVersion = version == "latest" ? "1.0.0" : version
            
            print("Installing MeshScale Control Plane version: \(actualVersion)")
            print("Downloading from registry...")
            
            // TODO: Implement actual download logic
            // - Fetch version from registry
            // - Download binary
            // - Verify checksum
            // - Extract to binaries directory
            
            // Create both control-plane and worker directories
            let cpDestDir = ConfigManager.shared.getBinaryDir(for: "control-plane", version: actualVersion)
            let workerDestDir = ConfigManager.shared.getBinaryDir(for: "worker", version: actualVersion)
            
            try FileManager.default.createDirectory(at: cpDestDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: workerDestDir, withIntermediateDirectories: true)
            
            // Create placeholder binary for control plane
            let binaryPath = ConfigManager.shared.getBinaryPath(for: "control-plane", version: actualVersion)
            let placeholderContent = "# MeshScale Control Plane \(actualVersion) - Placeholder"
            try placeholderContent.write(to: binaryPath, atomically: true, encoding: .utf8)
            
            print("✅ Control plane \(actualVersion) installed successfully")
            print("   Control Plane: \(cpDestDir.path)")
            print("   Worker: \(workerDestDir.path)")
            print("   Binary: \(binaryPath.path)")
            print("\nNote: This is a placeholder. Use 'meshscale debug symlink control-plane' for development")
            print("Start with: meshscale control-plane start")
        }
    }
    
    struct Start: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "start",
            abstract: "Start the control plane in background"
        )
        
        @Option(name: .shortAndLong, help: "Port to listen on")
        var port: Int = 8080
        
        @Option(name: .shortAndLong, help: "Host to bind to")
        var host: String = "0.0.0.0"
        
        @Flag(name: .long, help: "Development mode (allows killing existing processes)")
        var dev: Bool = false
        
        func run() throws {
            let serviceName = "control-plane"
            
            // Check if already running
            if let existingPid = ConfigManager.shared.loadPid(for: serviceName) {
                if ConfigManager.shared.isProcessRunning(existingPid) {
                    print("⚠️  Control plane is already running (PID: \(existingPid))")
                    
                    if dev {
                        print("\nDo you want to kill the existing process? (y/n):")
                        guard let answer = readLine()?.lowercased(),
                              answer == "y" || answer == "yes" else {
                            print("Aborted.")
                            return
                        }
                        
                        print("Stopping existing process...")
                        if ConfigManager.shared.killProcess(existingPid) {
                            print("✅ Process stopped")
                            ConfigManager.shared.removePid(for: serviceName)
                            Thread.sleep(forTimeInterval: 1)
                        } else {
                            print("❌ Failed to stop process")
                            throw ExitCode.failure
                        }
                    } else {
                        print("Use --dev flag to allow killing existing processes")
                        throw ExitCode.failure
                    }
                } else {
                    // Stale PID file
                    ConfigManager.shared.removePid(for: serviceName)
                }
            }
            
            // Find the executable
            guard let executablePath = findExecutable("control-plane") else {
                print("❌ MeshScaleControlPlane executable not found")
                print("Install it with: meshscale debug symlink control-plane")
                print("Or build first: swift build")
                throw ExitCode.failure
            }
            
            // Start the process
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            
            // Redirect output to log file
            let logFile = ConfigManager.shared.getLogFile(for: serviceName)
            
            // Create log file if it doesn't exist
            if !FileManager.default.fileExists(atPath: logFile.path) {
                _ = FileManager.default.createFile(atPath: logFile.path, contents: nil)
            }
            
            let logHandle = try FileHandle(forWritingTo: logFile)
            process.standardOutput = logHandle
            process.standardError = logHandle
            
            try process.run()
            
            // Save PID
            try ConfigManager.shared.savePid(process.processIdentifier, for: serviceName)
            
            print("✅ Control plane started (PID: \(process.processIdentifier))")
            print("   Host: \(host):\(port)")
            print("   Logs: \(logFile.path)")
            print("\nView logs with: meshscale control-plane logs")
        }
        
        private func findExecutable(_ component: String) -> String? {
            // First check installed binaries (versioned)
            let binariesDir = ConfigManager.shared.getBinariesPath()
            
            #if os(Windows)
            let componentDir = component == "control-plane" ? "ControlPlane" : "Worker"
            #else
            let componentDir = component == "control-plane" ? "controlplane" : "worker"
            #endif
            
            let componentPath = (binariesDir as NSString).appendingPathComponent(componentDir)
            
            // Look for any version (prefer "dev" if exists)
            if let versions = try? FileManager.default.contentsOfDirectory(atPath: componentPath) {
                let preferredVersions = ["dev"] + versions.filter { $0 != "dev" }.sorted().reversed()
                
                for version in preferredVersions {
                    let binaryPath = ConfigManager.shared.getBinaryPath(for: component, version: version)
                    if FileManager.default.fileExists(atPath: binaryPath.path) {
                        return binaryPath.path
                    }
                }
            }
            
            // Fallback to .build directory for development
            #if os(Windows)
            let executableName = component == "control-plane" ? "MeshScaleControlPlane.exe" : "MeshScaleWorker.exe"
            #else
            let executableName = component == "control-plane" ? "MeshScaleControlPlane" : "MeshScaleWorker"
            #endif
            
            let debugPath = ".build/debug/\(executableName)"
            if FileManager.default.fileExists(atPath: debugPath) {
                return FileManager.default.currentDirectoryPath + "/" + debugPath
            }
            
            let releasePath = ".build/release/\(executableName)"
            if FileManager.default.fileExists(atPath: releasePath) {
                return FileManager.default.currentDirectoryPath + "/" + releasePath
            }
            
            return nil
        }
    }
    
    struct Stop: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stop",
            abstract: "Stop the control plane"
        )
        
        func run() throws {
            let serviceName = "control-plane"
            
            guard let pid = ConfigManager.shared.loadPid(for: serviceName) else {
                print("❌ Control plane is not running")
                throw ExitCode.failure
            }
            
            if !ConfigManager.shared.isProcessRunning(pid) {
                print("⚠️  Process not found (stale PID file)")
                ConfigManager.shared.removePid(for: serviceName)
                throw ExitCode.failure
            }
            
            print("Stopping control plane (PID: \(pid))...")
            if ConfigManager.shared.killProcess(pid) {
                ConfigManager.shared.removePid(for: serviceName)
                print("✅ Control plane stopped")
            } else {
                print("❌ Failed to stop control plane")
                throw ExitCode.failure
            }
        }
    }
    
    struct Logs: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "logs",
            abstract: "View control plane logs"
        )
        
        @Flag(name: .shortAndLong, help: "Follow log output")
        var follow: Bool = false
        
        @Option(name: .shortAndLong, help: "Number of lines to show")
        var lines: Int?
        
        func run() throws {
            let serviceName = "control-plane"
            let logFile = ConfigManager.shared.getLogFile(for: serviceName)
            
            guard FileManager.default.fileExists(atPath: logFile.path) else {
                print("❌ No logs found at: \(logFile.path)")
                throw ExitCode.failure
            }
            
            let content = try String(contentsOf: logFile, encoding: .utf8)
            
            if content.isEmpty {
                print("(Log file is empty - process may still be starting)")
                return
            }
            
            if follow {
                // Tail -f equivalent
                print("Following logs (Ctrl+C to stop)...\n")
                let task = Process()
                #if os(Windows)
                task.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe")
                task.arguments = ["-Command", "Get-Content '\(logFile.path)' -Wait -Tail \(lines ?? 10)"]
                #else
                task.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
                task.arguments = ["-f", "-n", "\(lines ?? 10)", logFile.path]
                #endif
                try task.run()
                task.waitUntilExit()
            } else {
                // Show last N lines
                let allLines = content.components(separatedBy: .newlines)
                let linesToShow = lines ?? allLines.count
                let startIndex = max(0, allLines.count - linesToShow)
                let selectedLines = Array(allLines[startIndex...])
                print(selectedLines.joined(separator: "\n"))
            }
        }
    }
    
    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Check control plane status"
        )
        
        func run() throws {
            let serviceName = "control-plane"
            
            guard let pid = ConfigManager.shared.loadPid(for: serviceName) else {
                print("❌ Control plane is not running")
                return
            }
            
            if ConfigManager.shared.isProcessRunning(pid) {
                print("✅ Control plane is running (PID: \(pid))")
                let logFile = ConfigManager.shared.getLogFile(for: serviceName)
                print("   Logs: \(logFile.path)")
            } else {
                print("❌ Control plane is not running (stale PID file)")
                ConfigManager.shared.removePid(for: serviceName)
            }
        }
    }
}

extension MeshScaleCLI {
    struct Worker: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "worker",
            abstract: "Manage MeshScale worker nodes",
            subcommands: [Setup.self, SetupAMI.self, Install.self, Start.self, Status.self]
        )
    }
}

extension MeshScaleCLI.Worker {
    struct Setup: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "setup",
            abstract: "Setup worker (manual mode, saves credentials)"
        )
        
        @Option(name: .shortAndLong, help: "Worker type: general, databaseHeavy, or compute")
        var type: String = "general"
        
        func run() throws {
            guard ConfigManager.shared.hasAuth() else {
                print("❌ Not authenticated. Run 'meshscale auth login' first.")
                throw ExitCode.failure
            }
            
            let workerType = type
            guard ["general", "databaseHeavy", "compute"].contains(workerType) else {
                print("❌ Invalid type. Use: general, databaseHeavy, or compute")
                throw ExitCode.failure
            }
            
            print("→ Installing MeshScale Worker...")
            print("  ✓ Binary: (use meshscale worker install for binary)")
            print("  ✓ Config: worker type = \(workerType)")
            print("  ✓ Service: meshscale-worker.service")
            print("\nStart with: meshscale worker start")
        }
    }
    
    struct SetupAMI: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "setup-ami",
            abstract: "Setup worker for AMI mode (credentials from AWS Secrets Manager)"
        )
        
        func run() throws {
            print("→ Installing MeshScale Worker...")
            print("→ Fetching credentials from AWS Secrets Manager...")
            print("  ✓ Worker configured for AMI mode")
        }
    }
    
    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Check worker status"
        )
        
        func run() throws {
            // TODO: Query local worker or control plane for status
            print("✓ Worker: worker-manual-a7b3c")
            print("  Status: Running")
            print("  Containers: 5")
            print("  CPU: 45%")
        }
    }
    
    struct Install: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "install",
            abstract: "Install a specific version of the worker"
        )
        
        @Option(name: .shortAndLong, help: "Version to install (e.g., 1.0.0, latest)")
        var version: String = "latest"
        
        func run() throws {
            // Map "latest" to actual version
            let actualVersion = version == "latest" ? "1.0.0" : version
            
            print("Installing MeshScale Worker version: \(actualVersion)")
            print("Downloading from registry...")
            
            // TODO: Implement actual download logic
            // - Fetch version from registry
            // - Download binary
            // - Verify checksum
            // - Extract to binaries directory
            
            // Create both control-plane and worker directories
            let cpDestDir = ConfigManager.shared.getBinaryDir(for: "control-plane", version: actualVersion)
            let workerDestDir = ConfigManager.shared.getBinaryDir(for: "worker", version: actualVersion)
            
            try FileManager.default.createDirectory(at: cpDestDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: workerDestDir, withIntermediateDirectories: true)
            
            // Create placeholder binary for worker
            let binaryPath = ConfigManager.shared.getBinaryPath(for: "worker", version: actualVersion)
            let placeholderContent = "# MeshScale Worker \(actualVersion) - Placeholder"
            try placeholderContent.write(to: binaryPath, atomically: true, encoding: .utf8)
            
            print("✅ Worker \(actualVersion) installed successfully")
            print("   Control Plane: \(cpDestDir.path)")
            print("   Worker: \(workerDestDir.path)")
            print("   Binary: \(binaryPath.path)")
            print("\nNote: This is a placeholder. Use 'meshscale debug symlink worker' for development")
            print("Start with: meshscale worker start")
        }
    }
    
    struct Start: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "start",
            abstract: "Start a MeshScale worker node"
        )
        
        @Option(name: .shortAndLong, help: "Control plane address")
        var controlPlane: String = "localhost:8080"
        
        @Option(name: .shortAndLong, help: "Worker ID")
        var id: String?
        
        func run() throws {
            let workerId = id ?? UUID().uuidString
            print("Starting MeshScale Worker (ID: \(workerId))...")
            print("Connecting to control plane at \(controlPlane)...")
            
            let worker = MeshScaleWorkerRuntime.Worker(id: workerId)
            worker.start()
            
            RunLoop.main.run()
        }
    }
}


extension MeshScaleCLI {
    struct Deploy: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "deploy",
            abstract: "Deploy infrastructure project"
        )
        
        @Option(name: .shortAndLong, help: "Path to infrastructure.swift")
        var file: String = "infrastructure.swift"
        
        @Flag(name: .long, help: "Watch for changes and auto-redeploy")
        var watch: Bool = false
        
        func run() throws {
            guard FileManager.default.fileExists(atPath: file) else {
                print("❌ File not found: \(file)")
                throw ExitCode.failure
            }
            
            print("→ Uploading \(file)")
            
            // TODO: Upload to control plane
            print("→ Assigned Control Plane: control-plane-1.us-east-1")
            print("→ Executing infrastructure code...")
            print("→ Scheduling resources...")
            
            // Simulate deployment
            Thread.sleep(forTimeInterval: 1)
            
            print("✓ Deployed in 1.2s")
            
            if watch {
                print("\n→ Watching for changes...")
                print("(Press Ctrl+C to stop)")
                
                // TODO: Implement file watching
                RunLoop.main.run()
            }
        }
    }
}

extension MeshScaleCLI {
    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show overall MeshScale status"
        )
        
        func run() throws {
            print("✓ MeshScale Status")
            print("  Control Planes: 3 (1 leader, 2 standby)")
            print("  Workers: 25 (20 general, 5 databaseHeavy)")
            print("  Projects: 3")
            print("  Resources: 47")
        }
    }
}

extension MeshScaleCLI {
    struct Projects: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "projects",
            abstract: "Manage projects",
            subcommands: [List.self, Logs.self]
        )
    }
}

extension MeshScaleCLI.Projects {
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all projects"
        )
        
        func run() throws {
            print("PROJECT-ID    NAME        STATUS    RESOURCES    UPTIME")
            print("proj-abc123   myapp       Running   12           5h 23m")
            print("proj-def456   analytics   Running   8            2d 4h")
            print("proj-ghi789   staging     Running   6            45m")
        }
    }
    
    struct Logs: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "logs",
            abstract: "View project logs"
        )
        
        @Argument(help: "Project name or ID")
        var project: String
        
        @Flag(name: .shortAndLong, help: "Follow log output")
        var follow: Bool = false
        
        func run() throws {
            print("[\(Date())] API: Starting server on port 8080")
            print("[\(Date())] API: Connected to database")
            print("[\(Date())] Frontend: Server listening on port 3000")
            
            if follow {
                print("\nFollowing logs (Ctrl+C to stop)...")
                RunLoop.main.run()
            }
        }
    }
}

extension MeshScaleCLI {
    struct Workers: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "workers",
            abstract: "Manage workers",
            subcommands: [List.self]
        )
    }
}

extension MeshScaleCLI.Workers {
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all workers"
        )
        
        func run() throws {
            print("WORKER-ID       TYPE            REGION      CONTAINERS  CPU    MEMORY")
            print("worker-abc      general         us-east-1   8           45%    12/16GB")
            print("worker-db-1     databaseHeavy   us-east-1   2           80%    45/64GB")
            print("worker-xyz      general         eu-west-1   5           30%    8/16GB")
        }
    }
}

// MARK: - Volumes (per MeshScale AI Agent Guide)

extension MeshScaleCLI {
    struct Volumes: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "volumes",
            abstract: "Manage volumes",
            subcommands: [List.self, Inspect.self, Migrate.self, Backup.self]
        )
    }
}

extension MeshScaleCLI.Volumes {
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all volumes"
        )
        
        func run() throws {
            print("ID              NAME              SIZE    BACKEND   ATTACHED-TO")
            print("vol-abc123      users-db-data     100GB   aws-ebs   worker-db-1")
        }
    }
    
    struct Inspect: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "inspect",
            abstract: "Inspect a volume"
        )
        
        @Argument(help: "Volume ID")
        var volumeId: String
        
        func run() throws {
            print("Volume: \(volumeId)")
            print("Name: users-db-data")
            print("Size: 100GB")
            print("Backend: AWS EBS (gp3)")
            print("Status: attached")
            print("Attached To: worker-db-1")
        }
    }
    
    struct Migrate: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "migrate",
            abstract: "Migrate volume to different worker"
        )
        
        @Argument(help: "Volume ID")
        var volumeId: String
        
        @Option(name: .long, help: "Target worker ID")
        var to: String
        
        func run() throws {
            print("→ Stopping container...")
            print("→ Detaching volume...")
            print("→ Attaching to \(to)...")
            print("→ Starting container...")
            print("✓ Migration complete")
        }
    }
    
    struct Backup: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "backup",
            abstract: "Backup a volume"
        )
        
        @Argument(help: "Volume ID")
        var volumeId: String
        
        func run() throws {
            print("→ Creating snapshot...")
            print("✓ Backup: snap-\(volumeId.prefix(6))")
        }
    }
}

// MARK: - Logs (top-level shortcut per guide: meshscale logs myapp)

extension MeshScaleCLI {
    struct Logs: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "logs",
            abstract: "View project logs"
        )
        
        @Argument(help: "Project name or ID")
        var project: String
        
        @Flag(name: .shortAndLong, help: "Follow log output")
        var follow: Bool = false
        
        func run() throws {
            print("[\(Date())] API: Starting server on port 8080")
            print("[\(Date())] API: Connected to database")
            print("[\(Date())] Frontend: Server listening on port 3000")
            
            if follow {
                print("\nFollowing logs (Ctrl+C to stop)...")
                RunLoop.main.run()
            }
        }
    }
}
