import Foundation
import ArgumentParser

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
            abstract: "Start the control plane in background"
        )
        
        func run() throws {
            let service = "control-plane"
            if let pid = ConfigManager.shared.loadPid(for: service),
               ConfigManager.shared.isProcessRunning(pid) {
                print("⚠️ Control plane already running (PID: \(pid))")
                return
            }
            #if os(Windows)
            let executableName = "MeshScaleControlPlane.exe"
            #else
            let executableName = "MeshScaleControlPlane"
            #endif
            let path = ".build/debug/\(executableName)"
            guard FileManager.default.fileExists(atPath: path) else {
                print("❌ \(executableName) not found. Run `swift build` first.")
                throw ExitCode.failure
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            
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
            print("   Logs: \(logFile.path)")
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
        
        func run() throws {
            let service = "control-plane"
            guard let pid = ConfigManager.shared.loadPid(for: service) else {
                print("Control plane is not running")
                return
            }
            if ConfigManager.shared.isProcessRunning(pid) {
                print("✅ Control plane running (PID: \(pid))")
            } else {
                print("❌ Control plane not running (stale PID)")
            }
        }
    }
}
