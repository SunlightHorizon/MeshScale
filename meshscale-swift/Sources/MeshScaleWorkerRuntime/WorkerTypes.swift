import Foundation
import MeshScaleStore

public struct WorkerConfig {
    public let id: String
    public let type: WorkerType
    public let region: String
    public let controlPlaneID: String?
    public let controlPlaneAPIURL: String?
    
    public init(
        id: String,
        type: WorkerType = .general,
        region: String = "us-east-1",
        controlPlaneID: String? = nil,
        controlPlaneAPIURL: String? = nil
    ) {
        self.id = id
        self.type = type
        self.region = region
        self.controlPlaneID = controlPlaneID
        self.controlPlaneAPIURL = controlPlaneAPIURL
    }
}
