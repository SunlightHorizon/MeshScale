import Foundation
import Hummingbird
import MeshScaleControlPlaneRuntime

@main
struct MeshScaleControlPlane {
    static func main() throws {
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
        logger.log("Starting HTTP API on 0.0.0.0:8080")
        
        let app = HBApplication(configuration: .init(address: .hostname("0.0.0.0", port: 8080)))
        
        app.router.post("api/v1/deploy") { request -> HBResponse in
            if let buffer = request.body.buffer,
               let data = buffer.getData(at: 0, length: buffer.readableBytes),
               let source = String(data: data, encoding: .utf8) {
                controlPlane.deployProject(source)
                return HBResponse(status: .accepted)
            } else {
                return HBResponse(status: .badRequest)
            }
        }
        
        try app.start()
        app.wait()
    }
}
