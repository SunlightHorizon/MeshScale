import Foundation
import MeshScaleWorkerRuntime

@main
struct MeshScaleWorker {
    static func main() {
        print("MeshScale Worker starting...")
        
        let worker = Worker()
        worker.start()
        
        RunLoop.main.run()
    }
}
