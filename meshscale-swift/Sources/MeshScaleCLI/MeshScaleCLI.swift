import ArgumentParser

@main
struct MeshScaleCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "meshscale",
        abstract: "MeshScale - Distributed task execution platform",
        subcommands: [
            Auth.self,
            ControlPlane.self,
            Worker.self,
            Deploy.self,
            Demo.self
        ]
    )
}
