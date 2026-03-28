// MeshScale Infrastructure - Example (per MeshScale AI Agent Guide)
// Deploy with: meshscale deploy
//
// This file demonstrates a runnable local demo stack.

import Foundation
// In a real deployment, import MeshScaleControlPlaneRuntime
// import MeshScaleControlPlaneRuntime

// MARK: - Resources

struct Database: PostgresDatabase {
    var name = "app_db"
    var cpu = 4
    var memory = 8.gb
    var storage = StorageType.ssd(50.gb)
    
    var sharding = ShardingConfig(
        shards: 4,
        replicationFactor: 2,
        strategy: .consistentHash(key: "user_id"),
        autoRebalance: true
    )
    
    var latencySensitivity: LatencySensitivity = .high
}

struct Cache: RedisCache {
    var name = "app_cache"
    var memory = 4.gb
    var cpu = 2
    var latencySensitivity: LatencySensitivity = .high
}

struct Frontend: WebService {
    var name = "frontend"
    var replicas = 1
    var image = "nginxdemos/hello"
    var port = 80
    var cpu = 1
    var memory = 1.gb
    
    var latencySensitivity: LatencySensitivity = .medium
}

// MARK: - Runtime Hooks

func initialize(project: MeshScaleProject) {
    project.sendAlert("Swift project runtime initialized")
}

// Executed every 500ms by the control plane runtime host.
func tick(project: MeshScaleProject) {
    project.setDomain("localhost")
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    project.setOutput("current_time", to: formatter.string(from: Date()))
    
    project.addResource(Database.self)
    project.addResource(Cache.self)
    project.addResource(Frontend.self)
    
    let networkPolicy = NetworkingPolicy(
        inbound: PortFiltering(80, 443),
        outbound: PortFiltering(.all),
        url: ResourcePath("{ProjectDomain}")
    )
    project.addNetworkingPolicy(networkPolicy)
}
