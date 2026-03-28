import ArgumentParser

@main
struct MeshScaleCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "meshscale",
        abstract: "MeshScale - Distributed task execution platform",
        subcommands: [
            Install.self,
            Setup.self,
            Auth.self,
            Status.self,
            ControlPlane.self,
            Worker.self,
            Cluster.self,
            Deploy.self,
            Demo.self
        ]
    )
}
