import Foundation
import ArgumentParser
import MeshScaleControlPlaneRuntime
import MeshScaleStore

extension MeshScaleCLI {
    struct ControlPlane: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "control-plane",
            abstract: "Manage the MeshScale control plane",
            subcommands: [Start.self, Stop.self, Logs.self, Status.self]
        )
    }
}

extension MeshScaleCLI.ControlPlane {
    struct Start: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "start",
            abstract: "Start the control plane"
        )
        
        @Flag(name: .long, help: "Run in foreground and stream logs to this terminal")
        var dev: Bool = false

        @Flag(name: .long, help: "Use locally built binaries instead of an installed toolchain. Intended for repository development only.")
        var allowLocalBuild: Bool = false
        
        func run() throws {
            let service = "control-plane"
            
            if !dev {
                if let pid = ConfigManager.shared.loadPid(for: service) {
                    if ConfigManager.shared.isProcessRunning(pid) {
                        print("⚠️ Control plane already running (PID: \(pid))")
                        return
                    } else {
                        print("⚠️ Stale PID found (\(pid)), previous instance may have crashed. Starting fresh...")
                        ConfigManager.shared.removePid(for: service)
                    }
                }
            } else if let pid = ConfigManager.shared.loadPid(for: service),
                      ConfigManager.shared.isProcessRunning(pid) {
                print("❌ Background control plane running (PID: \(pid)) on port 8080.")
                print("   Stop it first with 'meshscale control-plane stop', then run with '--dev' again.")
                return
            }
            let resolvedExecutable: ResolvedToolchainExecutable
            do {
                resolvedExecutable = try ToolchainManager.shared.resolveExecutable(
                    for: .controlPlane,
                    allowLocalBuild: allowLocalBuild
                )
            } catch {
                print("❌ \(error.localizedDescription)")
                if !allowLocalBuild {
                    print("   Run 'meshscale install' to download the control-plane toolchain.")
                    print("   Repository development can opt into local binaries with '--allow-local-build'.")
                }
                throw ExitCode.failure
            }
            do {
                try SetupManager.shared.assertReady(for: .controlPlane)
            } catch {
                print("❌ \(error.localizedDescription)")
                print("   Run 'meshscale setup --role control-plane' before starting the control plane.")
                throw ExitCode.failure
            }
            let process = Process()
            process.executableURL = resolvedExecutable.url
            process.environment = ProcessInfo.processInfo.environment
                .merging(SetupManager.shared.environment(for: .controlPlane)) { _, new in new }
                .merging(resolvedExecutable.environment) { _, new in new }
            
            if dev {
                print("Starting control plane in dev mode (foreground) from \(resolvedExecutable.source)...")
                process.standardOutput = FileHandle.standardOutput
                process.standardError = FileHandle.standardError
                try process.run()
                process.waitUntilExit()
            } else {
                let logFile = ConfigManager.shared.getLogFile(for: service)
                if !FileManager.default.fileExists(atPath: logFile.path) {
                    _ = FileManager.default.createFile(atPath: logFile.path, contents: nil)
                }
                let handle = try FileHandle(forWritingTo: logFile)
                process.standardOutput = handle
                process.standardError = handle
                
                try process.run()
                try ConfigManager.shared.savePid(process.processIdentifier, for: service)
                print("✅ Control plane started (PID: \(process.processIdentifier))")
                print("   Source: \(resolvedExecutable.source)")
                print("   Logs: \(logFile.path)")
            }
        }
    }
    
    struct Stop: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stop",
            abstract: "Stop the control plane"
        )
        
        func run() throws {
            let service = "control-plane"
            guard let pid = ConfigManager.shared.loadPid(for: service) else {
                print("Control plane is not running")
                return
            }
            if !ConfigManager.shared.isProcessRunning(pid) {
                print("Stale PID file, cleaning up")
                ConfigManager.shared.removePid(for: service)
                return
            }
            if ConfigManager.shared.killProcess(pid) {
                ConfigManager.shared.removePid(for: service)
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
        
        func run() throws {
            let logFile = ConfigManager.shared.getLogFile(for: "control-plane")
            guard FileManager.default.fileExists(atPath: logFile.path) else {
                print("No logs at \(logFile.path)")
                return
            }
            let content = try String(contentsOf: logFile, encoding: .utf8)
            print(content)
        }
    }
    
    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Check control plane status"
        )

        @Flag(name: .long, help: "Emit JSON instead of a human-readable summary")
        var json: Bool = false
        
        func run() throws {
            var status = MeshScaleCLI.Status()
            status.json = json
            try status.run()
        }
    }
}
