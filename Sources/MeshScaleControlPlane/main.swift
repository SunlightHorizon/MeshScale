import Foundation
import MeshScaleControlPlaneRuntime

@main
struct MeshScaleControlPlane {
    static func main() {
        // Get log file path from environment or use default
        let logPath: String
        #if os(Windows)
        let appData = ProcessInfo.processInfo.environment["APPDATA"] ?? ""
        logPath = appData + "\\MeshScale\\logs\\control-plane.log"
        #elseif os(macOS)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        logPath = home + "/.config/meshscale/logs/control-plane.log"
        #else // Linux
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        logPath = home + "/.config/meshscale/logs/control-plane.log"
        #endif
        
        let logURL = URL(fileURLWithPath: logPath)
        let logger = Logger(logFile: logURL)
        
        logger.log("MeshScale Control Plane starting...")
        
        let controlPlane = ControlPlane(logger: logger)
        controlPlane.start()
        
        logger.log("Control Plane running...")
        
        RunLoop.main.run()
    }
}
