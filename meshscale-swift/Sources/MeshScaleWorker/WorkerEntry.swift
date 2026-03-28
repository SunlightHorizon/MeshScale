import Foundation
import MeshScaleStore
import MeshScaleWorkerRuntime

@main
struct MeshScaleWorker {
    static func main() {
        print("MeshScale Worker starting...")

        let environment = ProcessInfo.processInfo.environment
        let workerID = environment["MESHCALE_WORKER_ID"] ?? UUID().uuidString
        let workerType = MeshScaleStore.WorkerType(rawValue: environment["MESHCALE_WORKER_TYPE"] ?? "") ?? .general
        let workerRegion = environment["MESHCALE_WORKER_REGION"] ?? "us-east-1"
        let controlPlaneID = environment["MESHCALE_ATTACHED_CONTROL_PLANE_ID"]
        let worker = Worker(
            id: workerID,
            type: workerType,
            region: workerRegion,
            controlPlaneID: controlPlaneID,
            store: MeshScaleStoreFactory.makeStore(environment: environment)
        )
        worker.start()

        RunLoop.main.run()
    }
}
