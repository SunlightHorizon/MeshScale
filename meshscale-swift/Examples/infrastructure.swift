// MeshScale Infrastructure - Example (per MeshScale AI Agent Guide)
// Deploy with: meshscale deploy
//
// This file demonstrates the Three-Tier Application pattern.

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

struct API: HTTPService {
    var name = "api"
    var replicas = 10
    var image = "myorg/api:latest"
    var port = 8080
    var cpu = 2
    var memory = 4.gb
    
    var env: [String: String] = [
        "DATABASE_URL": "postgres://...",
        "REDIS_URL": "redis://...",
    ]
    
    var latencySensitivity: LatencySensitivity = .high
}

struct Frontend: WebService {
    var name = "frontend"
    var replicas = 5
    var image = "myorg/frontend:latest"
    var port = 3000
    var cpu = 1
    var memory = 2.gb
    
    var latencySensitivity: LatencySensitivity = .medium
}

// MARK: - main() - Executed every 500ms by Control Plane

func main(project: MeshScaleProject) {
    project.setDomain("myapp.com")
    
    project.addResource(Database.self)
    project.addResource(Cache.self)
    project.addResource(API.self)
    project.addResource(Frontend.self)
    
    let networkPolicy = NetworkingPolicy(
        inbound: PortFiltering(80, 443),
        outbound: PortFiltering(.all),
        url: ResourcePath("myapp.{ProjectDomain}")
    )
    project.addNetworkingPolicy(networkPolicy)
}
