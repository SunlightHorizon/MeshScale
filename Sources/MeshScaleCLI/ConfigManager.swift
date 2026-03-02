import Foundation

struct ConfigManager {
    static let shared = ConfigManager()
    
    private let configDir: URL
    private let authFile: URL
    private let pidDir: URL
    private let logsDir: URL
    
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
        
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: pidDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
    }
    
    // Auth
    
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
    
    // PIDs & logs
    
    func getLogFile(for service: String) -> URL {
        logsDir.appendingPathComponent("\(service).log")
    }
    
    func getPidFile(for service: String) -> URL {
        pidDir.appendingPathComponent("\(service).pid")
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
