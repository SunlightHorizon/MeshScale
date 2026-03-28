import Foundation

public final class Logger: @unchecked Sendable {
    private let logFile: URL
    private let fileHandle: FileHandle?
    
    public init(logFile: URL) {
        self.logFile = logFile
        
        // Create log file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFile.path) {
            _ = FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }
        
        self.fileHandle = try? FileHandle(forWritingTo: logFile)
        self.fileHandle?.seekToEndOfFile()
    }
    
    deinit {
        try? fileHandle?.close()
    }
    
    public func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        // Write to file
        if let data = logMessage.data(using: .utf8) {
            fileHandle?.write(data)
        }
        
        // Also print to console for debugging.
        FileHandle.standardOutput.write(Data(logMessage.utf8))
    }
}
