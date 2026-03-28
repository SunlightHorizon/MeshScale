import Foundation
import ArgumentParser

extension MeshScaleCLI {
    struct Install: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "install",
            abstract: "Download prebuilt MeshScale toolchains for this machine"
        )

        @Option(name: .long, help: "Release version to install. Defaults to the latest published version.")
        var version: String = "latest"

        @Option(name: .long, parsing: .upToNextOption, help: "Toolchain role(s) to install: control-plane, worker. Defaults to both.")
        var role: [String] = []

        @Option(name: .long, help: "Optional manifest URL override. Defaults to the published MeshScale release manifest.")
        var manifestURL: String?

        func run() throws {
            let roles = try resolvedRoles()
            let roleSummary = roles.map(\.displayName).joined(separator: ", ")
            print("Installing MeshScale toolchains for: \(roleSummary)")
            let installedVersion = try ToolchainManager.shared.install(
                version: version,
                roles: roles,
                manifestURL: manifestURL,
                progress: { message in
                    print("[install] \(message)")
                }
            )

            print("Installed MeshScale toolchain \(installedVersion):")
            for role in roles {
                let path = ToolchainManager.shared.toolchainRoot(version: installedVersion, role: role).path
                print("- \(role.displayName): \(path)")
            }
            print("MeshScale will use toolchain \(installedVersion) for future control plane and worker launches.")
            print("Run 'meshscale setup' next to install mandatory host dependencies before starting MeshScale.")
        }

        private func resolvedRoles() throws -> [MeshScaleToolchainRole] {
            if role.isEmpty {
                return MeshScaleToolchainRole.allCases
            }

            return try role.map(MeshScaleToolchainRole.parse(_:))
        }
    }
}
